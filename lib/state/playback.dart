import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/media.dart';
import 'providers.dart';

/// Everything the player needs. Series pass the whole season as a queue so
/// "next episode" works without another request; live channels may pass the
/// category they were opened from so ↑/↓ zap through it.
class PlayerArgs {
  PlayerArgs({
    required this.item,
    required this.url,
    required this.title,
    this.subtitle,
    this.startAt,
    this.queue = const [],
    this.queueIndex = 0,
    this.channels = const [],
    this.category,
  });

  final MediaItem item;
  final String url;
  final String title;
  final String? subtitle;
  final int? startAt;
  final List<Episode> queue;
  final int queueIndex;

  /// Zap list for live TV (the channels of the category the user came from).
  final List<MediaItem> channels;

  /// Name of that category, for the guide header and the channel panel.
  final String? category;

  Episode? get episode => queue.isEmpty ? null : queue[queueIndex];
  Episode? get nextEpisode => queueIndex < queue.length - 1 ? queue[queueIndex + 1] : null;
  bool get isLive => item.kind == MediaKind.channel;
  bool get isSeries => item.kind == MediaKind.series && episode != null;

  factory PlayerArgs.movie(MediaItem m, {int? startAt}) => PlayerArgs(
        item: m,
        url: m.url ?? '',
        title: m.name,
        subtitle: [if (m.year != null) '${m.year}', ...m.genres.take(3)].join(' · '),
        startAt: startAt,
      );

  factory PlayerArgs.channel(MediaItem c, {List<MediaItem> channels = const [], String? category}) => PlayerArgs(
        item: c,
        url: c.url ?? '',
        title: c.name,
        subtitle: c.group,
        channels: channels,
        category: category,
      );

  factory PlayerArgs.episode(MediaItem series, List<Episode> queue, int index, {int? startAt}) {
    final e = queue[index];
    return PlayerArgs(
      item: series,
      url: e.url,
      title: series.name,
      subtitle: 'S${e.season} · E${e.episode} — ${e.title}',
      startAt: startAt,
      queue: queue,
      queueIndex: index,
    );
  }

  PlayerArgs _withChannels(List<MediaItem> list, String? cat) => PlayerArgs(
        item: item,
        url: url,
        title: title,
        subtitle: subtitle,
        startAt: startAt,
        queue: queue,
        queueIndex: queueIndex,
        channels: list,
        category: cat,
      );
}

/// What is playing right now. The media_kit player lives here rather than in
/// the player route so playback survives picture-in-picture.
class PlaybackSession {
  const PlaybackSession({
    required this.player,
    required this.video,
    required this.args,
    this.pip = false,
    this.error,
    this.upNextSecs,
  });

  final Player player;
  final VideoController video;
  final PlayerArgs args;

  /// Shown in the floating mini player instead of the full-screen route.
  final bool pip;
  final String? error;

  /// Seconds left on the "Up next" countdown, when it is showing.
  final int? upNextSecs;

  PlaybackSession copyWith({PlayerArgs? args, bool? pip, String? Function()? error, int? Function()? upNextSecs}) =>
      PlaybackSession(
        player: player,
        video: video,
        args: args ?? this.args,
        pip: pip ?? this.pip,
        error: error == null ? this.error : error(),
        upNextSecs: upNextSecs == null ? this.upNextSecs : upNextSecs(),
      );
}

const upNextCountdown = 10;
const _upNextWindow = Duration(seconds: 20);

final playbackProvider = NotifierProvider<PlaybackController, PlaybackSession?>(PlaybackController.new);

class PlaybackController extends Notifier<PlaybackSession?> {
  Player? _player;
  VideoController? _video;
  final _subs = <StreamSubscription<dynamic>>[];
  Timer? _reporter;
  Timer? _countdown;
  bool _upNextDismissed = false;
  double _lastVolume = 100;
  int _token = 0;

  @override
  PlaybackSession? build() {
    ref.onDispose(_teardown);
    return null;
  }

  Player _ensurePlayer() {
    if (_player != null) return _player!;
    final p = Player();
    _player = p;
    _video = VideoController(p);
    _subs.addAll([
      p.stream.completed.listen((done) {
        if (done && state?.args.nextEpisode != null) playNext();
      }),
      p.stream.error.listen((e) {
        if (state != null) state = state!.copyWith(error: () => e);
      }),
      p.stream.position.listen(_onPosition),
    ]);
    _reporter = Timer.periodic(const Duration(seconds: 15), (_) => _report());
    return p;
  }

  /// Shows [args] in the full player. When it is already what's playing
  /// (expanding the mini player) the stream is left alone.
  void attach(PlayerArgs args) {
    final s = state;
    if (s != null && (identical(s.args, args) || (s.args.url == args.url && s.args.item.id == args.item.id))) {
      if (s.pip) state = s.copyWith(pip: false);
      return;
    }
    play(args);
  }

  Future<void> play(PlayerArgs args) async {
    if (state != null) _report();
    final player = _ensurePlayer();
    final token = ++_token;
    _countdown?.cancel();
    _upNextDismissed = false;
    state = PlaybackSession(player: player, video: _video!, args: args);
    ref.read(playingContentIdProvider.notifier).set(args.item.id);
    final repo = ref.read(repositoryProvider);
    var startAt = args.startAt;
    if (args.isLive) {
      unawaited(repo.reportProgress(kind: MediaKind.channel, contentId: args.item.id).catchError((_) {}));
      if (args.channels.isEmpty) unawaited(_loadZapList(args, token));
    } else if (startAt == null) {
      // Resume where the user left off unless they'd basically finished.
      final p = await repo.progressFor(args.item.id, episodeId: args.episode?.id).catchError((_) => null);
      if (token != _token) return;
      if (p != null && !p.completed && p.positionSecs > 30) startAt = p.positionSecs;
    }
    try {
      await player.open(Media(args.url, start: startAt == null ? null : Duration(seconds: startAt)));
      if (token != _token) return;
      if (args.isLive && player.state.rate != 1) await player.setRate(1);
    } catch (e) {
      // Stopped (player disposed) while opening, or the stream refused.
      if (token == _token && state != null) state = state!.copyWith(error: () => '$e');
    }
  }

  /// Opened from somewhere without a category list: zap through the
  /// channel's own group.
  Future<void> _loadZapList(PlayerArgs args, int token) async {
    try {
      final group = args.item.group.isEmpty ? null : args.item.group;
      final page = await ref.read(repositoryProvider).list(
            MediaKind.channel,
            playlistId: ref.read(activePlaylistProvider),
            group: group,
            limit: 500,
          );
      final s = state;
      if (token != _token || s == null || !identical(s.args, args)) return;
      final list = page.items.any((c) => c.id == args.item.id) ? page.items : [args.item, ...page.items];
      state = s.copyWith(args: args._withChannels(list, args.category ?? group));
    } catch (_) {}
  }

  void retry() {
    final s = state;
    if (s != null) play(s.args);
  }

  void _report() {
    final s = state;
    if (s == null || s.args.isLive) return;
    final pos = s.player.state.position.inSeconds;
    final dur = s.player.state.duration.inSeconds;
    if (pos < 5) return;
    ref
        .read(repositoryProvider)
        .reportProgress(
          kind: s.args.item.kind,
          contentId: s.args.item.id,
          episode: s.args.episode,
          positionSecs: pos,
          durationSecs: dur > 0 ? dur : null,
        )
        .catchError((_) {});
  }

  /// Starts the "Up next" countdown in the last seconds of an episode.
  void _onPosition(Duration pos) {
    final s = state;
    if (s == null || s.args.nextEpisode == null || _upNextDismissed || s.upNextSecs != null) return;
    final dur = s.player.state.duration;
    if (dur <= Duration.zero || dur - pos > _upNextWindow) return;
    state = s.copyWith(upNextSecs: () => upNextCountdown);
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      final s = state;
      if (s == null || s.upNextSecs == null) return t.cancel();
      final left = s.upNextSecs! - 1;
      if (left <= 0) {
        t.cancel();
        playNext();
      } else {
        state = s.copyWith(upNextSecs: () => left);
      }
    });
  }

  void playNext() {
    final a = state?.args;
    if (a == null || a.nextEpisode == null) return;
    play(PlayerArgs.episode(a.item, a.queue, a.queueIndex + 1, startAt: 0));
  }

  void dismissUpNext() {
    _countdown?.cancel();
    _upNextDismissed = true;
    if (state != null) state = state!.copyWith(upNextSecs: () => null);
  }

  /// Next (+1) / previous (-1) channel in the zap list. Returns the channel.
  MediaItem? zap(int dir) {
    final a = state?.args;
    if (a == null || !a.isLive || a.channels.length < 2) return null;
    final list = a.channels;
    final i = list.indexWhere((c) => c.id == a.item.id);
    final next = list[((i < 0 ? 0 : i) + dir) % list.length];
    play(PlayerArgs.channel(next, channels: list, category: a.category));
    return next;
  }

  void togglePlay() => state?.player.playOrPause();

  void seekTo(Duration to) {
    final s = state;
    if (s == null) return;
    final dur = s.player.state.duration;
    final t = to < Duration.zero ? Duration.zero : (dur > Duration.zero && to > dur ? dur : to);
    s.player.seek(t);
    if (s.upNextSecs != null && dur - t > _upNextWindow) {
      _countdown?.cancel();
      state = s.copyWith(upNextSecs: () => null);
    }
    _upNextDismissed = false;
  }

  void seekBy(int secs) {
    final s = state;
    if (s != null) seekTo(s.player.state.position + Duration(seconds: secs));
  }

  void setVolume(double v) => state?.player.setVolume(v.clamp(0, 100));

  void toggleMute() {
    final p = state?.player;
    if (p == null) return;
    final v = p.state.volume;
    if (v > 0) {
      _lastVolume = v;
      p.setVolume(0);
    } else {
      p.setVolume(_lastVolume > 0 ? _lastVolume : 100);
    }
  }

  void enterPip() {
    if (state != null) state = state!.copyWith(pip: true);
  }

  /// Stops playback, reports progress and releases the player.
  void stop() {
    if (_player == null && state == null) return;
    _report();
    _token++;
    _teardown();
    state = null;
    ref.read(playingContentIdProvider.notifier).set(null);
    // Progress changed; refresh anything that shows it.
    ref.invalidate(homeProvider);
    ref.invalidate(historyProvider);
  }

  void _teardown() {
    _reporter?.cancel();
    _countdown?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _player?.dispose();
    _player = null;
    _video = null;
  }
}
