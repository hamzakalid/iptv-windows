import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../models/media.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Everything the player needs. Series pass their seasons so "next episode"
/// and the episodes panel work without another request.
class PlayerArgs {
  PlayerArgs({
    required this.item,
    required this.url,
    required this.title,
    this.subtitle,
    this.startAt,
    this.queue = const [],
    this.queueIndex = 0,
    this.seasons = const {},
  });

  final MediaItem item;
  final String url;
  final String title;
  final String? subtitle;
  final int? startAt;
  final List<Episode> queue;
  final int queueIndex;
  final Map<int, List<Episode>> seasons;

  Episode? get episode => queue.isEmpty ? null : queue[queueIndex];
  bool get isLive => item.kind == MediaKind.channel;
  bool get isSeries => item.kind == MediaKind.series && queue.isNotEmpty;

  /// The episode after this one, crossing into the next season if needed.
  ({List<Episode> queue, int index})? get next {
    if (queue.isEmpty) return null;
    if (queueIndex < queue.length - 1) return (queue: queue, index: queueIndex + 1);
    final later = seasons.keys.where((s) => s > episode!.season).toList()..sort();
    if (later.isEmpty || seasons[later.first]!.isEmpty) return null;
    return (queue: seasons[later.first]!, index: 0);
  }

  Episode? get nextEpisode {
    final n = next;
    return n == null ? null : n.queue[n.index];
  }

  factory PlayerArgs.movie(MediaItem m, {int? startAt}) => PlayerArgs(
        item: m,
        url: m.url ?? '',
        title: m.name,
        subtitle: [if (m.year != null) '${m.year}', ...m.genres.take(3)].join(' · '),
        startAt: startAt,
      );

  factory PlayerArgs.channel(MediaItem c) => PlayerArgs(item: c, url: c.url ?? '', title: c.name, subtitle: c.group);

  factory PlayerArgs.episode(
    MediaItem series,
    List<Episode> queue,
    int index, {
    int? startAt,
    Map<int, List<Episode>> seasons = const {},
  }) {
    final e = queue[index];
    return PlayerArgs(
      item: series,
      url: e.url,
      title: series.name,
      subtitle: 'S${e.season} · E${e.episode} — ${e.title}',
      startAt: startAt,
      queue: queue,
      queueIndex: index,
      seasons: seasons.isEmpty ? {e.season: queue} : seasons,
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

enum _Panel { channels, guide, episodes, settings, help }

const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
const _upNextWindow = Duration(seconds: 20);
const _upNextCountdown = 10;
const _idleAfter = Duration(seconds: 3);

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final _player = Player();
  late final _video = VideoController(_player);
  late PlayerArgs _args = widget.args;
  final _focus = FocusNode(debugLabel: 'player');
  final _subs = <StreamSubscription<dynamic>>[];
  Timer? _reporter;
  Timer? _countdown;
  Timer? _idle;
  Timer? _osdTimer;

  String? _error;
  ChannelEpg? _epg;
  double _rate = 1;
  Tracks _tracks = const Tracks();
  Track _track = const Track();
  int? _upNextSecs;
  bool _upNextDismissed = false;
  bool _playing = true;
  bool _buffering = false;
  double _volume = 100;
  bool _muted = false;
  bool _chrome = true;
  bool _osd = false;
  bool _fullscreen = false;
  _Panel? _panel;

  /// Channel category for zapping and the channel list; null = all.
  late String? _cat = widget.args.isLive && widget.args.item.group.isNotEmpty ? widget.args.item.group : null;
  List<MediaItem> _zapList = const [];

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
    _subs.addAll([
      _player.stream.completed.listen((done) {
        if (done && _args.next != null) _playNext();
      }),
      _player.stream.error.listen((e) {
        if (mounted) setState(() => _error = e);
      }),
      _player.stream.tracks.listen((t) {
        if (mounted) setState(() => _tracks = t);
      }),
      _player.stream.track.listen((t) {
        if (mounted) setState(() => _track = t);
      }),
      _player.stream.playing.listen((p) {
        if (!mounted) return;
        setState(() => _playing = p);
        _wake();
      }),
      _player.stream.buffering.listen((b) {
        if (mounted) setState(() => _buffering = b);
      }),
      _player.stream.position.listen(_onPosition),
    ]);
    _start();
    if (_args.isLive) _flashOsd();
    _reporter = Timer.periodic(const Duration(seconds: 15), (_) => _report());
    _wake();
  }

  Future<void> _start() async {
    var startAt = _args.startAt;
    if (_args.isLive) {
      _epg = _args.item.epg;
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
    final id = _args.item.id;
    try {
      final c = await _repo.detail(MediaKind.channel, id);
      if (mounted && _args.item.id == id) setState(() => _epg = ChannelEpg.fromDetails(c.details));
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
    if (_args.next == null || _upNextDismissed || _upNextSecs != null) return;
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

  void _playEpisode(List<Episode> queue, int index) {
    _countdown?.cancel();
    _report();
    setState(() => _args = PlayerArgs.episode(_args.item, queue, index, startAt: 0, seasons: _args.seasons));
    _start();
  }

  void _playNext() {
    final n = _args.next;
    if (n != null) _playEpisode(n.queue, n.index);
  }

  void _dismissUpNext() {
    _countdown?.cancel();
    setState(() {
      _upNextSecs = null;
      _upNextDismissed = true;
    });
  }

  void _playChannel(MediaItem c) {
    if (c.id == _args.item.id) return;
    setState(() => _args = PlayerArgs.channel(c));
    _start();
    _flashOsd();
  }

  void _zap(int dir) {
    final list = _zapList;
    if (list.isEmpty) return;
    final i = list.indexWhere((c) => c.id == _args.item.id);
    _playChannel(list[((i < 0 ? 0 : i) + dir) % list.length]);
  }

  void _flashOsd() {
    _osdTimer?.cancel();
    setState(() => _osd = true);
    _osdTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _osd = false);
    });
  }

  void _togglePlay() => _player.playOrPause();

  void _seekBy(int secs) {
    final d = _player.state.duration;
    var to = _player.state.position + Duration(seconds: secs);
    if (to < Duration.zero) to = Duration.zero;
    if (d > Duration.zero && to > d) to = d;
    _player.seek(to);
  }

  void _setVolume(double v) {
    setState(() {
      _volume = v.clamp(0, 100);
      _muted = false;
    });
    _player.setVolume(_volume);
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _player.setVolume(_muted ? 0 : _volume);
  }

  void _setRate(double r) {
    _player.setRate(r);
    setState(() => _rate = r);
  }

  bool get _canFullscreen =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  Future<void> _toggleFullscreen() async {
    if (!_canFullscreen) return;
    final on = !_fullscreen;
    setState(() => _fullscreen = on);
    await (on ? defaultEnterNativeFullscreen() : defaultExitNativeFullscreen());
  }

  void _setPanel(_Panel? p) {
    setState(() => _panel = p);
    _wake();
  }

  void _togglePanel(_Panel p) => _setPanel(_panel == p ? null : p);

  /// Show the chrome and restart the idle timer that hides it again.
  void _wake() {
    if (!mounted) return;
    if (!_chrome) setState(() => _chrome = true);
    _idle?.cancel();
    _idle = Timer(_idleAfter, () {
      if (mounted && _playing && _panel == null) setState(() => _chrome = false);
    });
  }

  void _exit() {
    if (_fullscreen) _toggleFullscreen();
    context.pop();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final live = _args.isLive;
    final series = _args.isSeries;
    void Function()? action;
    if (k == LogicalKeyboardKey.space) {
      action = _togglePlay;
    } else if (k == LogicalKeyboardKey.escape) {
      action = _panel != null ? () => _setPanel(null) : (_fullscreen ? _toggleFullscreen : _exit);
    } else if (e.character == '?') {
      action = () => _togglePanel(_Panel.help);
    } else if (k == LogicalKeyboardKey.keyM) {
      action = _toggleMute;
    } else if (k == LogicalKeyboardKey.keyS) {
      action = () => _togglePanel(_Panel.settings);
    } else if (k == LogicalKeyboardKey.keyF) {
      action = _toggleFullscreen;
    } else if (live && k == LogicalKeyboardKey.arrowUp) {
      action = () => _zap(1);
    } else if (live && k == LogicalKeyboardKey.arrowDown) {
      action = () => _zap(-1);
    } else if (live && k == LogicalKeyboardKey.keyC) {
      action = () => _togglePanel(_Panel.channels);
    } else if (live && k == LogicalKeyboardKey.keyG) {
      action = () => _togglePanel(_Panel.guide);
    } else if (!live && k == LogicalKeyboardKey.arrowLeft) {
      action = () => _seekBy(-10);
    } else if (!live && k == LogicalKeyboardKey.arrowRight) {
      action = () => _seekBy(10);
    } else if (series && k == LogicalKeyboardKey.keyN) {
      action = _playNext;
    } else if (series && k == LogicalKeyboardKey.keyE) {
      action = () => _togglePanel(_Panel.episodes);
    }
    if (action == null) return KeyEventResult.ignored;
    if (e is KeyRepeatEvent && k != LogicalKeyboardKey.arrowLeft && k != LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.handled;
    }
    action();
    _wake();
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _report();
    _reporter?.cancel();
    _countdown?.cancel();
    _idle?.cancel();
    _osdTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    _focus.dispose();
    if (_fullscreen) defaultExitNativeFullscreen();
    // Progress changed; refresh anything that shows it. Deferred because the
    // tree is locked while this route unmounts.
    final container = _container;
    Future.microtask(() {
      container.invalidate(homeProvider);
      container.invalidate(historyProvider);
    });
    if (_isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([]);
    }
    super.dispose();
  }

  // ---- UI --------------------------------------------------------------

  String get _subLine {
    if (!_args.isLive) return _args.subtitle ?? '';
    final now = _epg?.now;
    final next = _epg?.next;
    if (now == null) return _args.item.group;
    return [
      'Now: ${now.title} · ${formatClock(now.start)} – ${formatClock(now.end)}',
      if (next != null) 'Next ${formatClock(next.start)} ${next.title}',
    ].join('   ·   ');
  }

  Widget _topBar() => Row(children: [
        IconButton(
          tooltip: 'Back (Esc)',
          onPressed: _exit,
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              if (_args.isLive && _args.item.number != null) ...[
                Text(_args.item.number!, style: AppText.tabular.copyWith(fontSize: 13, color: AppColors.accent)),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(_args.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
              ),
            ]),
            if (_subLine.isNotEmpty)
              Text(_subLine,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.neutral300)),
          ]),
        ),
        if (!_isMobile)
          IconButton(
            tooltip: 'Keyboard shortcuts (?)',
            onPressed: () => _togglePanel(_Panel.help),
            icon: const Icon(PhosphorIconsRegular.keyboard),
          ),
      ]);

  Widget _timeline() {
    const style = TextStyle(fontSize: 12, color: AppColors.neutral300, fontFeatures: [FontFeature.tabularFigures()]);
    if (_args.isLive) {
      final now = _epg?.now;
      return Row(children: [
        if (now != null) ...[
          Text(formatClock(now.start), style: style),
          const SizedBox(width: 12),
          Expanded(child: ThinProgress(now.progress, height: 3)),
          const SizedBox(width: 12),
          Text(formatClock(now.end), style: style),
          const SizedBox(width: 12),
        ] else
          const Spacer(),
        Tag(
          'LIVE',
          tone: TagTone.outline,
          leading: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
          ),
        ),
      ]);
    }
    return _SeekBar(player: _player, style: style, onSeek: (d) => _player.seek(d), onInteract: _wake);
  }

  Widget _controls() {
    final live = _args.isLive;
    final series = _args.isSeries;
    Widget ctl(IconData icon, String tip, VoidCallback onTap, {double size = 20}) =>
        IconButton(tooltip: tip, onPressed: onTap, icon: Icon(icon, size: size));
    Widget tool(String label, IconData icon, _Panel p, String tip) {
      final on = _panel == p;
      final style = OutlinedButton.styleFrom(
        foregroundColor: on ? AppColors.accent : AppColors.text,
        side: BorderSide(color: on ? AppColors.accent : Colors.transparent),
        padding: EdgeInsets.symmetric(horizontal: label.isEmpty ? 8 : 10),
        minimumSize: const Size(36, 36),
      );
      return Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Tooltip(
          message: tip,
          child: label.isEmpty
              ? OutlinedButton(style: style, onPressed: () => _togglePanel(p), child: Icon(icon, size: 18))
              : OutlinedButton.icon(
                  style: style,
                  onPressed: () => _togglePanel(p),
                  icon: Icon(icon, size: 18),
                  label: Text(label, style: const TextStyle(fontSize: 13)),
                ),
        ),
      );
    }

    final muted = _muted || _volume == 0;
    return Row(children: [
      ctl(_playing ? PhosphorIconsFill.pause : PhosphorIconsFill.play, 'Play / pause (Space)', _togglePlay, size: 22),
      if (live) ...[
        ctl(PhosphorIconsRegular.caretDown, 'Previous channel (↓)', () => _zap(-1)),
        ctl(PhosphorIconsRegular.caretUp, 'Next channel (↑)', () => _zap(1)),
      ] else ...[
        ctl(PhosphorIconsRegular.arrowCounterClockwise, 'Back 10 s (←)', () => _seekBy(-10)),
        ctl(PhosphorIconsRegular.arrowClockwise, 'Forward 10 s (→)', () => _seekBy(10)),
      ],
      if (_args.next != null) ctl(PhosphorIconsRegular.skipForward, 'Next episode (N)', _playNext),
      if (!_isMobile) ...[
        ctl(
          muted
              ? PhosphorIconsRegular.speakerX
              : (_volume < 40 ? PhosphorIconsRegular.speakerLow : PhosphorIconsRegular.speakerHigh),
          'Mute (M)',
          _toggleMute,
        ),
        _VolumeBar(value: _muted ? 0 : _volume / 100, onChanged: (v) => _setVolume(v * 100)),
      ],
      const Spacer(),
      if (live) ...[
        tool(context.isCompact ? '' : 'Guide', PhosphorIconsRegular.calendarDots, _Panel.guide, 'Guide (G)'),
        tool(context.isCompact ? '' : 'Channels', PhosphorIconsRegular.list, _Panel.channels, 'Channels (C)'),
      ],
      if (series) tool(context.isCompact ? '' : 'Episodes', PhosphorIconsRegular.stack, _Panel.episodes, 'Episodes (E)'),
      tool('', PhosphorIconsRegular.slidersHorizontal, _Panel.settings,
          live ? 'Audio & subtitles (S)' : 'Audio, subtitles & speed (S)'),
      if (_canFullscreen)
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: ctl(_fullscreen ? PhosphorIconsRegular.cornersIn : PhosphorIconsRegular.cornersOut, 'Full screen (F)',
              _toggleFullscreen),
        ),
    ]);
  }

  Widget _chromeLayer() => Stack(children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 140,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.ink.withValues(alpha: 0.85), AppColors.ink.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 200,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.ink.withValues(alpha: 0), AppColors.ink.withValues(alpha: 0.92)],
                ),
              ),
            ),
          ),
        ),
        Positioned(left: 16, right: 16, top: 14, child: SafeArea(bottom: false, child: _topBar())),
        Positioned(
          left: 24,
          right: 24,
          bottom: 16,
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _timeline(),
              const SizedBox(height: 8),
              _controls(),
            ]),
          ),
        ),
      ]);

  Widget _osdCard() {
    final now = _epg?.now;
    return Positioned(
      left: 32,
      top: 96,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(Radii.lg),
            boxShadow: Shadows.md,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (_args.item.number != null) ...[
              Text(_args.item.number!,
                  style: AppText.tabular.copyWith(fontSize: 34, fontWeight: FontWeight.w500, color: AppColors.accent)),
              const SizedBox(width: 14),
            ],
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(_args.item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              Text(
                now == null ? _args.item.group : '${now.title} · ${formatClock(now.start)} – ${formatClock(now.end)}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.neutral300),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _upNextCard() {
    final next = _args.nextEpisode!;
    return Positioned(
      right: 24,
      bottom: 96,
      child: Popover(
        width: 340,
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text('Up next in $_upNextSecs s', style: const TextStyle(fontSize: 12, color: AppColors.neutral400)),
          const SizedBox(height: 10),
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.sm),
              child: SizedBox(
                width: 96,
                height: 54,
                child: NetImage(next.thumb ?? _args.item.backdrop, labelSize: 0, memCacheWidth: 200),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('E${next.episode} · ${next.title}',
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ]),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(end: (_upNextCountdown - (_upNextSecs ?? 0)) / _upNextCountdown),
            duration: const Duration(seconds: 1),
            builder: (_, v, _) => ThinProgress(v),
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(onPressed: _dismissUpNext, child: const Text('Cancel')),
            const SizedBox(width: 6),
            FilledButton.icon(
              onPressed: _playNext,
              icon: const Icon(PhosphorIconsFill.play),
              label: const Text('Play now'),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _errorOverlay() => Positioned.fill(
        child: ColoredBox(
          color: AppColors.ink.withValues(alpha: 0.92),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(PhosphorIconsRegular.warningCircle, size: 40, color: AppColors.danger),
              const SizedBox(height: 12),
              const Text('Playback failed', style: AppText.h5),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
              ),
              const SizedBox(height: 18),
              Row(mainAxisSize: MainAxisSize.min, children: [
                OutlinedButton(onPressed: _exit, child: const Text('Close')),
                const SizedBox(width: 8),
                FilledButton(onPressed: _start, child: const Text('Retry')),
              ]),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final live = _args.isLive;
    if (live) _zapList = ref.watch(channelListProvider(_cat)).value ?? _zapList;
    final showChrome = _chrome || _panel != null || !_playing;

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: MouseRegion(
          cursor: showChrome ? MouseCursor.defer : SystemMouseCursors.none,
          onHover: (_) => _wake(),
          child: Stack(fit: StackFit.expand, children: [
            Video(controller: _video, controls: NoVideoControls, fill: AppColors.ink),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _focus.requestFocus();
                if (_panel != null) return _setPanel(null);
                if (_isMobile) {
                  _chrome ? setState(() => _chrome = false) : _wake();
                } else {
                  _togglePlay();
                }
              },
              onDoubleTap: _canFullscreen ? _toggleFullscreen : null,
            ),
            if (_buffering && _playing && _error == null)
              const Center(
                child: SizedBox.square(dimension: 32, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            if (!_playing && !_buffering && _error == null) const IgnorePointer(child: Center(child: _PausedMark())),
            if (_osd && live) _osdCard(),
            IgnorePointer(
              ignoring: !showChrome,
              child: AnimatedOpacity(
                opacity: showChrome ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: _chromeLayer(),
              ),
            ),
            if (_panel == _Panel.channels && live)
              _ChannelsPanel(
                current: _args.item,
                category: _cat,
                channels: _zapList,
                onCategory: (c) => setState(() => _cat = c),
                onPlay: _playChannel,
                onClose: () => _setPanel(null),
              ),
            if (_panel == _Panel.guide && live)
              _GuidePanel(
                current: _args.item,
                category: _cat,
                channels: _zapList,
                onPlay: _playChannel,
                onClose: () => _setPanel(null),
              ),
            if (_panel == _Panel.episodes && _args.isSeries)
              _EpisodesPanel(
                args: _args,
                progress: _player.state.duration > Duration.zero
                    ? _player.state.position.inMilliseconds / _player.state.duration.inMilliseconds
                    : 0,
                onPlay: _playEpisode,
                onClose: () => _setPanel(null),
              ),
            if (_panel == _Panel.settings)
              _SettingsPanel(
                tracks: _tracks,
                track: _track,
                rate: live ? null : _rate,
                onAudio: _player.setAudioTrack,
                onSubtitle: _player.setSubtitleTrack,
                onRate: _setRate,
                onClose: () => _setPanel(null),
              ),
            if (_upNextSecs != null && _args.next != null) _upNextCard(),
            if (_panel == _Panel.help) _HelpDialog(live: live, series: _args.isSeries, onClose: () => _setPanel(null)),
            if (_error != null) _errorOverlay(),
          ]),
        ),
      ),
    );
  }
}

class _PausedMark extends StatelessWidget {
  const _PausedMark();

  @override
  Widget build(BuildContext context) => Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.accent),
          color: AppColors.bg.withValues(alpha: 0.6),
        ),
        child: const Icon(PhosphorIconsFill.play, size: 28, color: AppColors.accent),
      );
}

/// VOD timeline: position, a scrubbable hairline with a thumb, remaining.
class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.player, required this.style, required this.onSeek, required this.onInteract});
  final Player player;
  final TextStyle style;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onInteract;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) => StreamBuilder<Duration>(
        stream: widget.player.stream.position,
        initialData: widget.player.state.position,
        builder: (context, snap) {
          final dur = widget.player.state.duration;
          final pos = snap.data ?? Duration.zero;
          final known = dur > Duration.zero;
          final frac = _drag ?? (known ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0) : 0.0);
          final shown = known ? dur * frac : pos;
          return Row(children: [
            Text(formatTimecode(shown), style: widget.style),
            const SizedBox(width: 12),
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                double at(Offset p) => (p.dx / c.maxWidth).clamp(0.0, 1.0);
                return MouseRegion(
                  cursor: known ? SystemMouseCursors.click : MouseCursor.defer,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: known ? (d) => widget.onSeek(dur * at(d.localPosition)) : null,
                    onHorizontalDragStart: known ? (d) => setState(() => _drag = at(d.localPosition)) : null,
                    onHorizontalDragUpdate: known
                        ? (d) {
                            widget.onInteract();
                            setState(() => _drag = at(d.localPosition));
                          }
                        : null,
                    onHorizontalDragEnd: known
                        ? (_) {
                            widget.onSeek(dur * _drag!);
                            setState(() => _drag = null);
                          }
                        : null,
                    child: SizedBox(
                      height: 14,
                      child: Stack(clipBehavior: Clip.none, alignment: Alignment.centerLeft, children: [
                        ThinProgress(frac, height: 3),
                        if (known)
                          Positioned(
                            left: c.maxWidth * frac - 5.5,
                            child: Container(
                              width: 11,
                              height: 11,
                              decoration: const BoxDecoration(color: AppColors.accent300, shape: BoxShape.circle),
                            ),
                          ),
                      ]),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(width: 12),
            Text(known ? '-${formatTimecode(dur - shown)}' : '', style: widget.style),
          ]);
        },
      );
}

class _VolumeBar extends StatelessWidget {
  const _VolumeBar({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    const width = 84.0;
    double at(Offset p) => (p.dx / width).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => onChanged(at(d.localPosition)),
          onHorizontalDragUpdate: (d) => onChanged(at(d.localPosition)),
          child: SizedBox(
            width: width,
            height: 20,
            child: Center(child: ThinProgress(value, height: 3, color: AppColors.neutral300)),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Panels
// ---------------------------------------------------------------------------

/// Translucent blurred surface for side and bottom sheets.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.child, this.bottom = false});
  final Widget child;
  final bool bottom;

  @override
  Widget build(BuildContext context) => ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.94),
              border: bottom
                  ? const Border(top: BorderSide(color: AppColors.neutral800))
                  : const Border(left: BorderSide(color: AppColors.neutral800)),
            ),
            child: child,
          ),
        ),
      );
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, required this.shortcut, required this.onClose, this.note});
  final String title;
  final String shortcut;
  final String? note;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
        child: Row(children: [
          Text(title, style: AppText.h5),
          const SizedBox(width: 8),
          Expanded(
            child: Text(note ?? '',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.neutral500)),
          ),
          Kbd(shortcut),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Close (Esc)',
            onPressed: onClose,
            icon: const Icon(PhosphorIconsRegular.x, size: 18),
          ),
        ]),
      );
}

class _ChannelsPanel extends ConsumerWidget {
  const _ChannelsPanel({
    required this.current,
    required this.category,
    required this.channels,
    required this.onCategory,
    required this.onPlay,
    required this.onClose,
  });
  final MediaItem current;
  final String? category;
  final List<MediaItem> channels;
  final ValueChanged<String?> onCategory;
  final ValueChanged<MediaItem> onPlay;
  final VoidCallback onClose;

  static const _rowExtent = 60.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider(MediaKind.channel)).value?.names ?? const <String>[];
    final entries = <String?>[null, ...cats];
    final index = channels.indexWhere((c) => c.id == current.id);
    final numbered = channels.any((c) => c.number != null);
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: math.min(380, MediaQuery.sizeOf(context).width * 0.9),
      child: _Sheet(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _PanelHeader(title: 'Channels', shortcut: 'C', onClose: onClose),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) => FilterPill(
                entries[i] ?? 'All',
                dense: true,
                selected: entries[i] == category,
                onTap: () => onCategory(entries[i]),
              ),
            ),
          ),
          Expanded(
            child: channels.isEmpty
                ? const Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                : ListView.builder(
                    key: ValueKey(category),
                    controller: ScrollController(initialScrollOffset: math.max(0, index - 3) * _rowExtent),
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    itemExtent: _rowExtent,
                    itemCount: channels.length,
                    itemBuilder: (_, i) {
                      final c = channels[i];
                      final on = c.id == current.id;
                      final now = c.epg.now;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: SideListItem(
                          selected: on,
                          onTap: () => onPlay(c),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          barInset: 10,
                          child: Row(children: [
                            if (numbered)
                              SizedBox(
                                width: 34,
                                child: Text(c.number ?? '',
                                    style: AppText.tabular.copyWith(
                                        fontSize: 12, color: on ? AppColors.accent : AppColors.neutral500)),
                              ),
                            LogoTile(url: c.logo, label: c.name, width: 44, height: 30),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(c.name,
                                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
                                  Text(now?.title ?? c.group,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                  if (now != null) ...[
                                    const SizedBox(height: 3),
                                    ThinProgress(now.progress, color: AppColors.accent600),
                                  ],
                                ],
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

/// Four-hour programme grid for the channels around the current one.
class _GuidePanel extends StatelessWidget {
  const _GuidePanel({
    required this.current,
    required this.category,
    required this.channels,
    required this.onPlay,
    required this.onClose,
  });
  final MediaItem current;
  final String? category;
  final List<MediaItem> channels;
  final ValueChanged<MediaItem> onPlay;
  final VoidCallback onClose;

  static const _span = Duration(hours: 4);
  static const _nameWidth = 180.0;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, now.hour, now.minute < 30 ? 0 : 30)
        .subtract(const Duration(minutes: 30));
    final list = channels.isEmpty ? [current] : channels;
    final ci = math.max(0, list.indexWhere((c) => c.id == current.id));
    final rows = <MediaItem>[];
    for (var d = -2; d <= 3; d++) {
      final c = list[(ci + d) % list.length];
      if (!rows.contains(c)) rows.add(c);
    }
    final nowFrac = now.difference(start).inSeconds / _span.inSeconds;
    final height = math.min(330.0, MediaQuery.sizeOf(context).height * 0.6);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: height,
      child: _Sheet(
        bottom: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _PanelHeader(
            title: 'Guide',
            note: 'Today · ${category ?? 'All channels'}',
            shortcut: 'G',
            onClose: onClose,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: LayoutBuilder(builder: (context, c) {
                final lane = c.maxWidth - _nameWidth;
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(
                    height: 20,
                    child: Stack(children: [
                      for (var m = 0; m < _span.inMinutes; m += 30)
                        Positioned(
                          left: _nameWidth + lane * m / _span.inMinutes,
                          child: Text(formatClock(start.add(Duration(minutes: m))),
                              style: AppText.tabular.copyWith(fontSize: 11.5, color: AppColors.neutral500)),
                        ),
                    ]),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Stack(children: [
                        Column(children: [
                          for (final ch in rows)
                            _GuideRow(
                              channel: ch,
                              selected: ch.id == current.id,
                              start: start,
                              span: _span,
                              lane: lane,
                              onPlay: () => onPlay(ch),
                            ),
                        ]),
                        Positioned(
                          top: 0,
                          bottom: 0,
                          left: _nameWidth + lane * nowFrac.clamp(0.0, 1.0),
                          child: IgnorePointer(child: Container(width: 1, color: AppColors.accent)),
                        ),
                      ]),
                    ),
                  ),
                ]);
              }),
            ),
          ),
        ]),
      ),
    );
  }
}

class _GuideRow extends ConsumerWidget {
  const _GuideRow({
    required this.channel,
    required this.selected,
    required this.start,
    required this.span,
    required this.lane,
    required this.onPlay,
  });
  final MediaItem channel;
  final bool selected;
  final DateTime start;
  final Duration span;
  final double lane;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epg = ref.watch(channelEpgProvider(channel.id)).value ?? channel.epg;
    final seen = <DateTime>{};
    final progs = [?epg.now, ?epg.next, ...epg.upcoming]
        .where((p) => p.start != null && p.end != null && seen.add(p.start!))
        .toList();
    final end = start.add(span);
    final now = DateTime.now();
    double x(DateTime t) => lane * (t.difference(start).inSeconds / span.inSeconds).clamp(0.0, 1.0);

    return SizedBox(
      height: 50,
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 4),
          child: SizedBox(
            width: _GuidePanel._nameWidth - 8,
            child: Hoverable(
              onTap: onPlay,
              color: selected ? AppColors.tint(0.10) : null,
              hoverColor: AppColors.wash(0.06),
              ring: Shadows.ringFlat,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(children: [
                  if (channel.number != null) ...[
                    Text(channel.number!,
                        style: AppText.tabular.copyWith(
                            fontSize: 12, color: selected ? AppColors.accent : AppColors.neutral500)),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(channel.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                  ),
                ]),
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: progs.isEmpty
                ? Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(color: AppColors.neutral900, borderRadius: BorderRadius.circular(Radii.sm)),
                    child: const Text('No guide information', style: TextStyle(fontSize: 12, color: AppColors.neutral600)),
                  )
                : Stack(children: [
                    for (final p in progs)
                      if (p.end!.isAfter(start) && p.start!.isBefore(end))
                        Positioned(
                          left: x(p.start!),
                          width: math.max(0, x(p.end!) - x(p.start!)),
                          top: 0,
                          bottom: 0,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 3),
                            child: _Programme(
                              entry: p,
                              live: !p.start!.isAfter(now) && p.end!.isAfter(now),
                              past: !p.end!.isAfter(now),
                              onTap: onPlay,
                            ),
                          ),
                        ),
                  ]),
          ),
        ),
      ]),
    );
  }
}

class _Programme extends StatefulWidget {
  const _Programme({required this.entry, required this.live, required this.past, required this.onTap});
  final EpgEntry entry;
  final bool live;
  final bool past;
  final VoidCallback onTap;

  @override
  State<_Programme> createState() => _ProgrammeState();
}

class _ProgrammeState extends State<_Programme> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.entry;
    final time = '${formatClock(p.start)} – ${formatClock(p.end)}';
    return Tooltip(
      message: '${p.title} · $time',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Opacity(
            opacity: widget.past ? 0.5 : 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: _hover ? AppColors.neutral800 : (widget.live ? AppColors.accent900 : AppColors.neutral900),
                borderRadius: BorderRadius.circular(Radii.sm),
                border: widget.live ? Border.all(color: AppColors.accent700) : null,
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(p.title, maxLines: 1, overflow: TextOverflow.clip, softWrap: false, style: const TextStyle(fontSize: 12.5)),
                Text(time,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: AppText.tabular.copyWith(fontSize: 11, color: AppColors.neutral500)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodesPanel extends StatefulWidget {
  const _EpisodesPanel({required this.args, required this.progress, required this.onPlay, required this.onClose});
  final PlayerArgs args;
  final double progress;
  final void Function(List<Episode> queue, int index) onPlay;
  final VoidCallback onClose;

  @override
  State<_EpisodesPanel> createState() => _EpisodesPanelState();
}

class _EpisodesPanelState extends State<_EpisodesPanel> {
  late int _season = widget.args.episode!.season;

  @override
  Widget build(BuildContext context) {
    final seasons = widget.args.seasons;
    final current = widget.args.episode!;
    final eps = seasons[_season] ?? widget.args.queue;
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: math.min(420, MediaQuery.sizeOf(context).width * 0.9),
      child: _Sheet(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _PanelHeader(title: 'Episodes', shortcut: 'E', onClose: widget.onClose),
          if (seasons.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedControl<int>(
                    dense: true,
                    segments: [for (final s in seasons.keys) Segment(s, 'Season $s')],
                    selected: _season,
                    onChanged: (s) => setState(() => _season = s),
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              itemCount: eps.length,
              itemBuilder: (_, i) {
                final e = eps[i];
                final on = e.id == current.id && e.season == current.season && e.episode == current.episode;
                final done = e.season < current.season || (e.season == current.season && e.episode < current.episode);
                final pct = on ? widget.progress : (done ? 1.0 : 0.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Hoverable(
                    onTap: () => widget.onPlay(eps, i),
                    color: on ? AppColors.tint(0.10) : null,
                    hoverColor: on ? AppColors.tint(0.14) : AppColors.wash(0.06),
                    ring: Shadows.ringFlat,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(Radii.sm),
                          child: SizedBox(
                            width: 128,
                            height: 72,
                            child: Stack(fit: StackFit.expand, children: [
                              NetImage(e.thumb, labelSize: 0, memCacheWidth: 260),
                              if (e.thumb == null)
                                Center(
                                  child: Text('E${e.episode}', style: const TextStyle(fontSize: 11, color: AppColors.neutral600)),
                                ),
                              if (pct > 0) ArtProgress(pct),
                            ]),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(
                                child: Text('${e.episode}. ${e.title}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13.5, color: on ? AppColors.accent300 : AppColors.text)),
                              ),
                              if (on) const Tag('Playing', tone: TagTone.accent),
                              if (done) const Icon(PhosphorIconsRegular.check, size: 14, color: AppColors.accent400),
                            ]),
                            if (e.durationSecs != null) ...[
                              const SizedBox(height: 3),
                              Text(formatDuration(e.durationSecs),
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.neutral500)),
                            ],
                            if (e.plot != null) ...[
                              const SizedBox(height: 3),
                              Text(e.plot!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.wash(0.6))),
                            ],
                          ]),
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

/// Audio, subtitles and (for VOD) playback speed.
class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.tracks,
    required this.track,
    required this.rate,
    required this.onAudio,
    required this.onSubtitle,
    required this.onRate,
    required this.onClose,
  });
  final Tracks tracks;
  final Track track;

  /// Null for live streams, which can't change speed.
  final double? rate;
  final ValueChanged<AudioTrack> onAudio;
  final ValueChanged<SubtitleTrack> onSubtitle;
  final ValueChanged<double> onRate;
  final VoidCallback onClose;

  static String _name(String id, String? title, String? lang) {
    final n = [?title, if (lang != null) lang.toUpperCase()].join(' · ');
    return n.isEmpty ? 'Track $id' : n;
  }

  @override
  Widget build(BuildContext context) {
    // mpv's own "auto" choice leads each list; "no" is only offered for subtitles.
    final audio = tracks.audio.where((a) => a.id != 'no').toList();
    final subs = tracks.subtitle;
    String label(String id, String? title, String? lang) => switch (id) {
          'auto' => 'Auto',
          'no' => 'Off',
          _ => _name(id, title, lang),
        };

    Widget option(String label, bool on, VoidCallback onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Icon(on ? PhosphorIconsRegular.check : PhosphorIconsRegular.dotOutline,
                  size: 15, color: on ? AppColors.accent : AppColors.neutral600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: on ? AppColors.accent : AppColors.neutral300)),
              ),
            ]),
          ),
        );

    Widget column(String title, List<Widget> options) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.toUpperCase(), style: AppText.eyebrow.copyWith(color: AppColors.neutral500)),
            const SizedBox(height: 4),
            if (options.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 5),
                child: Text('Default', style: TextStyle(fontSize: 13, color: AppColors.neutral500)),
              ),
            ...options,
          ]),
        );

    return Positioned(
      right: 24,
      bottom: 84,
      child: Popover(
        width: 340,
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Expanded(child: Text('Playback', style: AppText.h5)),
            IconButton(tooltip: 'Close (Esc)', onPressed: onClose, icon: const Icon(PhosphorIconsRegular.x, size: 18)),
          ]),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              column('Audio', [
                for (final a in audio) option(label(a.id, a.title, a.language), a.id == track.audio.id, () => onAudio(a)),
              ]),
              const SizedBox(width: 14),
              column('Subtitles', [
                for (final s in subs)
                  option(label(s.id, s.title, s.language), s.id == track.subtitle.id, () => onSubtitle(s)),
              ]),
            ]),
          ),
          if (rate != null) ...[
            const SizedBox(height: 12),
            Text('SPEED', style: AppText.eyebrow.copyWith(color: AppColors.neutral500)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SegmentedControl<double>(
                expand: true,
                dense: true,
                segments: [for (final s in _speeds) Segment(s, '${s == s.truncate() ? s.toInt() : s}×')],
                selected: rate!,
                onChanged: onRate,
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _HelpDialog extends StatelessWidget {
  const _HelpDialog({required this.live, required this.series, required this.onClose});
  final bool live;
  final bool series;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final keys = [
      ('Space', 'Play / pause'),
      if (live) ...[('↑ ↓', 'Change channel'), ('C', 'Channel list'), ('G', 'Guide')] else ('← →', 'Seek 10 s'),
      if (series) ...[('N', 'Next episode'), ('E', 'Episodes')],
      ('S', live ? 'Audio & subtitles' : 'Audio, subs & speed'),
      ('M', 'Mute'),
      ('F', 'Full screen'),
      ('Esc', 'Close / back'),
      ('?', 'This list'),
    ];
    return Positioned.fill(
      child: GestureDetector(
        onTap: onClose,
        child: ColoredBox(
          color: AppColors.neutral900.withValues(alpha: 0.6),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Popover(
                width: math.min(520, MediaQuery.sizeOf(context).width * 0.92),
                padding: const EdgeInsets.fromLTRB(16, 10, 10, 18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    const Expanded(child: Text('Keyboard shortcuts', style: AppText.h4)),
                    IconButton(onPressed: onClose, icon: const Icon(PhosphorIconsRegular.x, size: 18)),
                  ]),
                  const SizedBox(height: 10),
                  LayoutBuilder(builder: (context, c) {
                    final w = (c.maxWidth - 30) / 2;
                    return Wrap(spacing: 24, runSpacing: 8, children: [
                      for (final (key, label) in keys)
                        SizedBox(
                          width: w,
                          child: Row(children: [
                            Kbd(key, minWidth: 44),
                            const SizedBox(width: 10),
                            Flexible(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.neutral300))),
                          ]),
                        ),
                    ]);
                  }),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
