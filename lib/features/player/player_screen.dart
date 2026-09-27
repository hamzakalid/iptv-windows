import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/media.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Everything the player needs. Series pass the whole season as a queue so
/// "next episode" works without another request.
class PlayerArgs {
  PlayerArgs({
    required this.item,
    required this.url,
    required this.title,
    this.subtitle,
    this.startAt,
    this.queue = const [],
    this.queueIndex = 0,
  });

  final MediaItem item;
  final String url;
  final String title;
  final String? subtitle;
  final int? startAt;
  final List<Episode> queue;
  final int queueIndex;

  Episode? get episode => queue.isEmpty ? null : queue[queueIndex];
  Episode? get nextEpisode => queueIndex < queue.length - 1 ? queue[queueIndex + 1] : null;
  bool get isLive => item.kind == MediaKind.channel;

  factory PlayerArgs.movie(MediaItem m, {int? startAt}) =>
      PlayerArgs(item: m, url: m.url ?? '', title: m.name, subtitle: m.year?.toString(), startAt: startAt);

  factory PlayerArgs.channel(MediaItem c) => PlayerArgs(item: c, url: c.url ?? '', title: c.name, subtitle: c.group);

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
}

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.args});
  final PlayerArgs args;

  static void open(BuildContext context, PlayerArgs args) {
    if (args.url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No stream URL for this item.')));
      return;
    }
    context.push('/player', extra: args);
  }

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
const _upNextWindow = Duration(seconds: 20);
const _upNextCountdown = 10;

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final _player = Player();
  late final _video = VideoController(_player);
  late PlayerArgs _args = widget.args;
  Timer? _reporter;
  Timer? _countdown;
  final _subs = <StreamSubscription<dynamic>>[];
  String? _error;
  EpgEntry? _now;
  double _rate = 1;
  Tracks _tracks = const Tracks();
  int? _upNextSecs;
  bool _upNextDismissed = false;

  // Captured up front: `ref` can't be used inside dispose().
  late final ProviderContainer _container = ProviderScope.containerOf(context, listen: false);
  late final _repo = _container.read(repositoryProvider);

  bool get _isMobile =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (_isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
    _subs.add(_player.stream.completed.listen((done) {
      if (done && _hasNext) _playNext();
    }));
    _subs.add(_player.stream.error.listen((e) {
      if (mounted) setState(() => _error = e);
    }));
    _subs.add(_player.stream.tracks.listen((t) {
      if (mounted) setState(() => _tracks = t);
    }));
    _subs.add(_player.stream.position.listen(_onPosition));
    _start();
    _reporter = Timer.periodic(const Duration(seconds: 15), (_) => _report());
  }

  Future<void> _start() async {
    var startAt = _args.startAt;
    if (_args.isLive) {
      _loadEpg();
      unawaited(_repo.reportProgress(kind: MediaKind.channel, contentId: _args.item.id).catchError((_) {}));
    } else if (startAt == null) {
      // Resume where the user left off unless they'd basically finished.
      final p = await _repo.progressFor(_args.item.id, episodeId: _args.episode?.id).catchError((_) => null);
      if (p != null && !p.completed && p.positionSecs > 30) startAt = p.positionSecs;
    }
    if (!mounted) return;
    setState(() {
      _error = null;
      _upNextSecs = null;
      _upNextDismissed = false;
    });
    _countdown?.cancel();
    await _player.open(Media(_args.url, start: startAt == null ? null : Duration(seconds: startAt)));
    if (_rate != 1) await _player.setRate(_rate);
  }

  Future<void> _loadEpg() async {
    try {
      final c = await _repo.detail(MediaKind.channel, _args.item.id);
      if (mounted) setState(() => _now = ChannelEpg.fromDetails(c.details).now);
    } catch (_) {}
  }

  void _report() {
    if (_args.isLive) return;
    final pos = _player.state.position.inSeconds;
    final dur = _player.state.duration.inSeconds;
    if (pos < 5) return;
    _repo
        .reportProgress(
          kind: _args.item.kind,
          contentId: _args.item.id,
          episode: _args.episode,
          positionSecs: pos,
          durationSecs: dur > 0 ? dur : null,
        )
        .catchError((_) {});
  }

  /// Show the "Up next" card in the last seconds of an episode.
  void _onPosition(Duration pos) {
    if (!_hasNext || _upNextDismissed || _upNextSecs != null) return;
    final dur = _player.state.duration;
    if (dur <= Duration.zero || dur - pos > _upNextWindow) return;
    setState(() => _upNextSecs = _upNextCountdown);
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      final left = (_upNextSecs ?? 0) - 1;
      if (left <= 0) {
        t.cancel();
        _playNext();
      } else {
        setState(() => _upNextSecs = left);
      }
    });
  }

  bool get _hasNext => _args.nextEpisode != null;

  void _playNext() {
    _countdown?.cancel();
    _report();
    setState(() => _args = PlayerArgs.episode(_args.item, _args.queue, _args.queueIndex + 1, startAt: 0));
    _start();
  }

  void _dismissUpNext() {
    _countdown?.cancel();
    setState(() {
      _upNextSecs = null;
      _upNextDismissed = true;
    });
  }

  @override
  void dispose() {
    _report();
    _reporter?.cancel();
    _countdown?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    // Progress changed; refresh anything that shows it.
    _container.invalidate(homeProvider);
    _container.invalidate(historyProvider);
    if (_isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([]);
    }
    super.dispose();
  }

  // ---- UI --------------------------------------------------------------

  Widget _topBar() {
    final t = Theme.of(context).textTheme;
    final subtitle = _args.isLive && _now != null
        ? 'Now: ${_now!.title}  ${formatClock(_now!.start)}–${formatClock(_now!.end)}'
        : _args.subtitle;
    return Expanded(
      child: Row(children: [
        IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                if (_args.isLive) ...[const LiveBadge(), const SizedBox(width: 8)],
                Flexible(
                  child: Text(_args.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: t.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ]),
              if (subtitle != null)
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(color: Colors.white70)),
            ],
          ),
        ),
        if (_hasNext)
          TextButton.icon(
            onPressed: _playNext,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.skip_next_rounded),
            label: const Text('Next episode'),
          ),
      ]),
    );
  }

  Widget _speedButton() => PopupMenuButton<double>(
        tooltip: 'Playback speed',
        initialValue: _rate,
        onSelected: (r) {
          _player.setRate(r);
          setState(() => _rate = r);
        },
        itemBuilder: (_) => [
          for (final s in _speeds) PopupMenuItem(value: s, child: Text(s == 1 ? 'Normal' : '${s}x')),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(_rate == 1 ? '1x' : '${_rate}x',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      );

  Widget _tracksButton() {
    final audio = _tracks.audio.where((a) => a.id != 'auto' && a.id != 'no').toList();
    final subs = _tracks.subtitle.where((s) => s.id != 'auto').toList();
    if (audio.length < 2 && subs.length < 2) return const SizedBox.shrink();
    String name(String id, String? title, String? lang) =>
        [?title, if (lang != null) lang.toUpperCase()].join(' · ').ifEmpty('Track $id');
    return PopupMenuButton<VoidCallback>(
      tooltip: 'Audio & subtitles',
      icon: const Icon(Icons.subtitles_outlined, color: Colors.white),
      onSelected: (fn) => fn(),
      itemBuilder: (_) => [
        if (audio.length > 1) ...[
          const PopupMenuItem(enabled: false, height: 32, child: Text('AUDIO', style: TextStyle(fontSize: 11, letterSpacing: 1))),
          for (final a in audio)
            PopupMenuItem(
              value: () => _player.setAudioTrack(a),
              child: Row(children: [
                Icon(a.id == _player.state.track.audio.id ? Icons.check_rounded : null, size: 18),
                const SizedBox(width: 8),
                Text(name(a.id, a.title, a.language)),
              ]),
            ),
        ],
        if (subs.length > 1) ...[
          const PopupMenuItem(enabled: false, height: 32, child: Text('SUBTITLES', style: TextStyle(fontSize: 11, letterSpacing: 1))),
          for (final s in subs)
            PopupMenuItem(
              value: () => _player.setSubtitleTrack(s),
              child: Row(children: [
                Icon(s.id == _player.state.track.subtitle.id ? Icons.check_rounded : null, size: 18),
                const SizedBox(width: 8),
                Text(s.id == 'no' ? 'Off' : name(s.id, s.title, s.language)),
              ]),
            ),
        ],
      ],
    );
  }

  Widget _upNextCard() {
    final next = _args.nextEpisode!;
    return Positioned(
      right: 24,
      bottom: 90,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: AppColors.outline),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Up next in $_upNextSecs s', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 96,
                height: 54,
                child: NetImage(next.thumb ?? _args.item.backdrop, label: 'E${next.episode}', memCacheWidth: 200),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('E${next.episode} · ${next.title}', maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            TextButton(onPressed: _dismissUpNext, child: const Text('Cancel')),
            const Spacer(),
            FilledButton.icon(
              onPressed: _playNext,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Play now'),
            ),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = [_topBar()];
    final extras = [_tracksButton(), _speedButton()];
    final live = _args.isLive;
    final video = Video(controller: _video, controls: AdaptiveVideoControls);

    final mobileTheme = MaterialVideoControlsThemeData(
      topButtonBar: top,
      bottomButtonBar: [const MaterialPositionIndicator(), const Spacer(), ...extras, const MaterialFullscreenButton()],
      seekBarPositionColor: AppColors.accent,
      seekBarThumbColor: AppColors.accent,
      displaySeekBar: !live,
      seekOnDoubleTap: !live,
    );
    final desktopTheme = MaterialDesktopVideoControlsThemeData(
      topButtonBar: top,
      bottomButtonBar: [
        const MaterialDesktopSkipPreviousButton(),
        const MaterialDesktopPlayOrPauseButton(),
        const MaterialDesktopSkipNextButton(),
        const MaterialDesktopVolumeButton(),
        const MaterialDesktopPositionIndicator(),
        const Spacer(),
        ...extras,
        const MaterialDesktopFullscreenButton(),
      ],
      seekBarPositionColor: AppColors.accent,
      seekBarThumbColor: AppColors.accent,
      displaySeekBar: !live,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: MaterialVideoControlsTheme(
            normal: mobileTheme,
            fullscreen: mobileTheme,
            child: MaterialDesktopVideoControlsTheme(
              normal: desktopTheme,
              fullscreen: desktopTheme,
              child: video,
            ),
          ),
        ),
        if (_upNextSecs != null && _hasNext) _upNextCard(),
        if (_error != null)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black87,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
                  const SizedBox(height: 12),
                  const Text('Playback failed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
                  ),
                  const SizedBox(height: 18),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    OutlinedButton(onPressed: () => context.pop(), child: const Text('Close')),
                    const SizedBox(width: 12),
                    FilledButton(onPressed: _start, child: const Text('Retry')),
                  ]),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
