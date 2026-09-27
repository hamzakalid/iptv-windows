import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/media.dart';
import '../../state/playback.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/media_cards.dart';
import '../../widgets/nocturne.dart';

export '../../state/playback.dart' show PlayerArgs;

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.args});
  final PlayerArgs args;

  static void open(BuildContext context, PlayerArgs args) {
    if (args.url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No stream URL for this item.')));
      return;
    }
    ProviderScope.containerOf(context, listen: false).read(playbackProvider.notifier).play(args);
    context.push('/player', extra: args);
  }

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

enum _Panel { none, channels, guide, episodes, settings, help }

const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
const _osdFor = Duration(milliseconds: 2600);
const _idleAfter = Duration(seconds: 3);

bool get _isMobile =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

String _mmss(Duration d) {
  final s = math.max(0, d.inSeconds);
  final h = s ~/ 3600, m = s % 3600 ~/ 60, x = s % 60;
  final mm = h > 0 ? m.toString().padLeft(2, '0') : '$m';
  return '${h > 0 ? '$h:' : ''}$mm:${x.toString().padLeft(2, '0')}';
}

TextStyle _tab(double size, Color color, {FontWeight? weight}) =>
    TextStyle(fontSize: size, color: color, fontWeight: weight, fontFeatures: NocText.tabular, height: 1.3);

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final ProviderContainer _container;
  late final PlaybackController _ctrl;
  _Panel _panel = _Panel.none;
  DateTime _lastMove = DateTime.now();
  bool _idle = false;
  DateTime? _osdUntil;
  bool _fullscreen = false;
  String? _toast;
  Timer? _toastTimer;
  Timer? _ticker;
  int _ticks = 0;
  double? _dragFrac;

  Player? _bound;
  final _subs = <StreamSubscription<dynamic>>[];
  bool _playing = true;
  bool _buffering = false;
  double _volume = 100;
  double _rate = 1;
  Duration _duration = Duration.zero;
  Tracks _tracks = const Tracks();
  Track _track = const Track();

  @override
  void initState() {
    super.initState();
    // Captured up front: `ref` can't be used inside dispose().
    _container = ProviderScope.containerOf(context, listen: false);
    _ctrl = _container.read(playbackProvider.notifier);
    if (_isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
    HardwareKeyboard.instance.addHandler(_onKey);
    if (widget.args.isLive) _osdUntil = DateTime.now().add(_osdFor);
    Future.microtask(() {
      if (mounted) _ctrl.attach(widget.args);
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _ticker?.cancel();
    _toastTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    if (_fullscreen) unawaited(defaultExitNativeFullscreen());
    // Leaving normally stops playback; picture-in-picture keeps it going.
    final s = _container.read(playbackProvider);
    if (s != null && !s.pip) Future.microtask(_ctrl.stop);
    if (_isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([]);
    }
    super.dispose();
  }

  void _bind(Player p) {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _bound = p;
    final st = p.state;
    _playing = st.playing;
    _buffering = st.buffering;
    _volume = st.volume;
    _rate = st.rate;
    _duration = st.duration;
    _tracks = st.tracks;
    _track = st.track;
    void on<T>(Stream<T> s, void Function(T) f) => _subs.add(s.listen((v) {
          if (mounted) setState(() => f(v));
        }));
    on(p.stream.playing, (v) => _playing = v);
    on(p.stream.buffering, (v) => _buffering = v);
    on(p.stream.volume, (v) => _volume = v);
    on(p.stream.rate, (v) => _rate = v);
    on(p.stream.duration, (v) => _duration = v);
    on(p.stream.tracks, (v) => _tracks = v);
    on(p.stream.track, (v) => _track = v);
  }

  void _tick() {
    if (!mounted) return;
    _ticks++;
    final now = DateTime.now();
    final idle = _playing && _panel == _Panel.none && now.difference(_lastMove) > _idleAfter;
    final osdDone = _osdUntil != null && now.isAfter(_osdUntil!);
    if (idle != _idle || osdDone || _ticks % 30 == 0) {
      setState(() {
        _idle = idle;
        if (osdDone) _osdUntil = null;
      });
    }
  }

  void _wake() {
    _lastMove = DateTime.now();
    if (_idle) setState(() => _idle = false);
  }

  void _flash(String msg) {
    _toastTimer?.cancel();
    setState(() => _toast = msg);
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _toggle(_Panel p) => setState(() => _panel = _panel == p ? _Panel.none : p);

  void _exit() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _pip() {
    _ctrl.enterPip();
    _exit();
  }

  void _toggleFullscreen() {
    if (_isMobile) return _flash('The player is already full screen');
    setState(() => _fullscreen = !_fullscreen);
    unawaited(_fullscreen ? defaultEnterNativeFullscreen() : defaultExitNativeFullscreen());
  }

  void _zap(int dir) {
    if (_ctrl.zap(dir) == null) _flash('No other channels in this list');
  }

  void _playChannel(MediaItem c, List<MediaItem> list, String? cat) {
    if (c.url == null || c.url!.isEmpty) return _flash('No stream URL for this channel');
    _ctrl.play(PlayerArgs.channel(c, channels: list, category: cat));
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyUpEvent || !mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    final s = _container.read(playbackProvider);
    if (s == null) return false;
    final k = e.logicalKey;
    final repeat = e is KeyRepeatEvent;
    final live = s.args.isLive, series = s.args.isSeries;
    VoidCallback? fn;
    if (e.character == '?') {
      fn = () => _toggle(_Panel.help);
    } else if (k == LogicalKeyboardKey.escape) {
      fn = _panel != _Panel.none ? () => setState(() => _panel = _Panel.none) : _exit;
    } else if (live && k == LogicalKeyboardKey.arrowUp) {
      fn = () => _zap(1);
    } else if (live && k == LogicalKeyboardKey.arrowDown) {
      fn = () => _zap(-1);
    } else if (!live && k == LogicalKeyboardKey.arrowLeft) {
      fn = () => _ctrl.seekBy(-10);
    } else if (!live && k == LogicalKeyboardKey.arrowRight) {
      fn = () => _ctrl.seekBy(10);
    } else if (!repeat) {
      fn = switch (k) {
        LogicalKeyboardKey.space => _ctrl.togglePlay,
        LogicalKeyboardKey.keyM => _ctrl.toggleMute,
        LogicalKeyboardKey.keyP => _pip,
        LogicalKeyboardKey.keyS => () => _toggle(_Panel.settings),
        LogicalKeyboardKey.keyF => _toggleFullscreen,
        LogicalKeyboardKey.keyC when live => () => _toggle(_Panel.channels),
        LogicalKeyboardKey.keyG when live => () => _toggle(_Panel.guide),
        LogicalKeyboardKey.keyN when series => _ctrl.playNext,
        LogicalKeyboardKey.keyE when series => () => _toggle(_Panel.episodes),
        _ => null,
      };
    }
    if (fn == null) return false;
    fn();
    _wake();
    return true;
  }

  void _onVideoTap(PointerDeviceKind kind) {
    // On touch screens the first tap brings the controls back.
    if (_idle && kind == PointerDeviceKind.touch) return _wake();
    _ctrl.togglePlay();
    _wake();
  }

  // ---- Build -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    ref.listen(playbackProvider, (prev, next) {
      if (next == null || !next.args.isLive || prev?.args.item.id == next.args.item.id) return;
      setState(() => _osdUntil = DateTime.now().add(_osdFor));
    });
    final s = ref.watch(playbackProvider);
    if (s == null) {
      return const Scaffold(
        backgroundColor: AppColors.video,
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (!identical(s.player, _bound)) _bind(s.player);
    final a = s.args;
    final live = a.isLive;
    final epg = live ? useChannelEpg(ref, a.item) : null;
    final width = MediaQuery.sizeOf(context).width;
    final hideChrome = _idle && s.error == null;

    return Scaffold(
      backgroundColor: AppColors.video,
      body: MouseRegion(
        cursor: hideChrome ? SystemMouseCursors.none : MouseCursor.defer,
        onHover: (_) => _wake(),
        child: Stack(children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _onVideoTap(d.kind),
              child: Video(controller: s.video, controls: NoVideoControls, fill: AppColors.video),
            ),
          ),
          if (_buffering && s.error == null)
            const IgnorePointer(
              child: Center(
                child: SizedBox.square(dimension: 36, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
          if (!_playing && !_buffering && s.error == null) const _PausedBadge(),
          if (live && _osdUntil != null) Positioned(left: 32, top: 96, child: _Osd(channel: a.item)),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: hideChrome,
              child: AnimatedOpacity(
                opacity: hideChrome ? 0 : 1,
                duration: const Duration(milliseconds: 250),
                child: Stack(children: [
                  const _Scrims(),
                  Positioned(left: 16, right: 16, top: 14, child: _topBar(a, epg)),
                  Positioned(left: 24, right: 24, bottom: 16, child: _bottomBar(s, epg)),
                ]),
              ),
            ),
          ),
          if (_panel == _Panel.channels && live)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: math.min(380, width * 0.9),
              child: _ChannelsPanel(
                args: a,
                onPlay: _playChannel,
                onClose: () => _toggle(_Panel.channels),
              ),
            ),
          if (_panel == _Panel.guide && live)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 330,
              child: _GuidePanel(
                args: a,
                onPlay: (c) => _playChannel(c, a.channels, a.category),
                onClose: () => _toggle(_Panel.guide),
              ),
            ),
          if (_panel == _Panel.episodes && a.isSeries)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: math.min(420, width * 0.9),
              child: _EpisodesPanel(
                session: s,
                onPlay: (season, i) => _ctrl.play(PlayerArgs.episode(a.item, season, i)),
                onClose: () => _toggle(_Panel.episodes),
              ),
            ),
          if (_panel == _Panel.settings)
            Positioned(
              right: 24,
              bottom: 84,
              width: math.min(340, width - 48),
              child: _SettingsPopover(
                tracks: _tracks,
                track: _track,
                rate: _rate,
                showSpeed: !live,
                onAudio: s.player.setAudioTrack,
                onSubtitle: s.player.setSubtitleTrack,
                onRate: s.player.setRate,
                onClose: () => _toggle(_Panel.settings),
              ),
            ),
          if (s.upNextSecs != null && a.nextEpisode != null)
            Positioned(
              right: 24,
              bottom: 96,
              width: math.min(340, width - 48),
              child: _UpNextCard(
                series: a.item,
                next: a.nextEpisode!,
                secs: s.upNextSecs!,
                onCancel: _ctrl.dismissUpNext,
                onPlay: _ctrl.playNext,
              ),
            ),
          if (_toast != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(Radii.md),
                    boxShadow: Shadows.md,
                  ),
                  child: Text(_toast!, style: const TextStyle(fontSize: 13)),
                ),
              ),
            ),
          if (_panel == _Panel.help)
            Positioned.fill(child: _HelpDialog(live: live, onClose: () => _toggle(_Panel.help))),
          if (s.error != null) Positioned.fill(child: _ErrorOverlay(message: s.error!, onClose: _exit, onRetry: _ctrl.retry)),
        ]),
      ),
    );
  }

  Widget _topBar(PlayerArgs a, ChannelEpg? epg) {
    final now = epg?.now, next = epg?.next;
    final sub = a.isLive
        ? now != null
            ? [
                'Now: ${now.title} · ${epgTime(now)}',
                if (next != null) 'Next ${formatClock(next.start)} ${next.title}',
              ].join(' · ')
            : (a.category ?? a.item.group)
        : (a.subtitle ?? '');
    return Row(children: [
      NocIconButton(icon: Ph.arrowLeft, tooltip: 'Back (Esc)', onPressed: _exit),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            if (a.isLive && a.item.number != null) ...[
              Text('${a.item.number}', style: _tab(13, AppColors.accent)),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(a.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, height: 1.3)),
            ),
          ]),
          if (sub.isNotEmpty)
            Text(sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: AppColors.n300, height: 1.35)),
        ]),
      ),
      const SizedBox(width: 10),
      NocIconButton(icon: Ph.keyboard, tooltip: 'Keyboard shortcuts (?)', onPressed: () => _toggle(_Panel.help)),
    ]);
  }

  Widget _bottomBar(PlaybackSession s, ChannelEpg? epg) {
    final a = s.args;
    final live = a.isLive;
    final series = a.isSeries;
    final tools = <(String, IconData, _Panel, String)>[
      if (live) ...[
        ('Guide', Ph.calendarDots, _Panel.guide, 'Guide (G)'),
        ('Channels', Ph.list, _Panel.channels, 'Channels (C)'),
        ('', Ph.slidersHorizontal, _Panel.settings, 'Audio & subtitles (S)'),
      ] else ...[
        if (series) ('Episodes', Ph.stack, _Panel.episodes, 'Episodes (E)'),
        ('', Ph.slidersHorizontal, _Panel.settings, 'Audio, subtitles & speed (S)'),
      ],
    ];
    final vol = _volume;
    final volIcon = vol <= 0 ? Ph.speakerX : (vol < 40 ? Ph.speakerLow : Ph.speakerHigh);
    const gap = SizedBox(width: 2);

    return Column(mainAxisSize: MainAxisSize.min, children: [
      live ? _liveBar(epg?.now) : _seekBar(s),
      const SizedBox(height: 8),
      Row(children: [
        NocIconButton(
          icon: _playing ? PhF.pause : PhF.play,
          iconSize: 22,
          tooltip: 'Play / pause (Space)',
          onPressed: _ctrl.togglePlay,
        ),
        gap,
        if (live) ...[
          NocIconButton(icon: Ph.caretDown, tooltip: 'Previous channel (↓)', onPressed: () => _zap(-1)),
          gap,
          NocIconButton(icon: Ph.caretUp, tooltip: 'Next channel (↑)', onPressed: () => _zap(1)),
          gap,
        ] else ...[
          NocIconButton(icon: Ph.arrowCounterClockwise, tooltip: 'Back 10 s (←)', onPressed: () => _ctrl.seekBy(-10)),
          gap,
          NocIconButton(icon: Ph.arrowClockwise, tooltip: 'Forward 10 s (→)', onPressed: () => _ctrl.seekBy(10)),
          gap,
        ],
        if (a.nextEpisode != null) ...[
          NocIconButton(icon: Ph.skipForward, tooltip: 'Next episode (N)', onPressed: _ctrl.playNext),
          gap,
        ],
        NocIconButton(icon: volIcon, tooltip: 'Mute (M)', onPressed: _ctrl.toggleMute),
        gap,
        _Bar(
          width: 84,
          height: 20,
          value: vol / 100,
          color: AppColors.n300,
          onChanged: (f) => _ctrl.setVolume(f * 100),
        ),
        const SizedBox(width: 10),
        const Spacer(),
        for (final t in tools) ...[
          _ToolButton(
            label: t.$1,
            icon: t.$2,
            tooltip: t.$4,
            active: _panel == t.$3,
            onTap: () => _toggle(t.$3),
          ),
          gap,
        ],
        NocIconButton(icon: Ph.pictureInpicture, tooltip: 'Picture-in-picture (P)', onPressed: _pip),
        if (!_isMobile) ...[
          gap,
          NocIconButton(
            icon: _fullscreen ? Ph.cornersIn : Ph.cornersOut,
            tooltip: _fullscreen ? 'Exit full screen (F)' : 'Full screen (F)',
            onPressed: _toggleFullscreen,
          ),
        ],
      ]),
    ]);
  }

  Widget _liveBar(EpgEntry? now) {
    final style = _tab(12, AppColors.n300);
    return Row(children: [
      if (now != null) ...[Text(formatClock(now.start), style: style), const SizedBox(width: 12)],
      Expanded(child: ProgressLine(now?.progress ?? 0, height: 3)),
      if (now != null) ...[const SizedBox(width: 12), Text(formatClock(now.end), style: style)],
      const SizedBox(width: 12),
      const NocTag(
        'LIVE',
        kind: TagKind.outline,
        leading: SizedBox.square(
          dimension: 6,
          child: DecoratedBox(decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
        ),
      ),
    ]);
  }

  Widget _seekBar(PlaybackSession s) {
    final style = _tab(12, AppColors.n300);
    return StreamBuilder<Duration>(
      stream: s.player.stream.position,
      initialData: s.player.state.position,
      builder: (context, snap) {
        final dur = _duration;
        final pos = snap.data ?? Duration.zero;
        final played = dur > Duration.zero ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0) : 0.0;
        final frac = _dragFrac ?? played;
        final shown = _dragFrac == null ? pos : dur * frac;
        void seek(double f) => _ctrl.seekTo(dur * f);
        return Row(children: [
          Text(_mmss(shown), style: style),
          const SizedBox(width: 12),
          Expanded(
            child: _Bar(
              height: 14,
              value: frac,
              thumb: true,
              onChanged: seek,
              onDrag: (f) => setState(() => _dragFrac = f),
              onDragEnd: () {
                if (_dragFrac != null) seek(_dragFrac!);
                setState(() => _dragFrac = null);
              },
            ),
          ),
          const SizedBox(width: 12),
          Text('-${_mmss(dur - shown)}', style: style),
        ]);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Chrome pieces
// ---------------------------------------------------------------------------

class _Scrims extends StatelessWidget {
  const _Scrims();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Stack(children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 140,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.video.withValues(alpha: 0.85), AppColors.video.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 200,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.video.withValues(alpha: 0), AppColors.video.withValues(alpha: 0.92)],
                ),
              ),
            ),
          ),
        ]),
      );
}

class _PausedBadge extends StatelessWidget {
  const _PausedBadge();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent),
              color: AppColors.bg.withValues(alpha: 0.6),
            ),
            child: const Icon(PhF.play, size: 28, color: AppColors.accent),
          ),
        ),
      );
}

/// Channel-change on-screen display.
class _Osd extends ConsumerWidget {
  const _Osd({required this.channel});
  final MediaItem channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = useChannelEpg(ref, channel)?.now;
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: Shadows.md,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (channel.number != null) ...[
            Text('${channel.number}', style: _tab(34, AppColors.accent, weight: FontWeight.w500).copyWith(height: 1.1)),
            const SizedBox(width: 14),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              if (now != null)
                Text('${now.title} · ${epgTime(now)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.n300)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// 3px track with a fill, clickable and draggable (seek bar, volume).
class _Bar extends StatelessWidget {
  const _Bar({
    required this.height,
    required this.value,
    required this.onChanged,
    this.width,
    this.color = AppColors.accent,
    this.thumb = false,
    this.onDrag,
    this.onDragEnd,
  });
  final double? width;
  final double height;
  final double value;
  final Color color;
  final bool thumb;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onDrag;
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          double f(Offset p) => w <= 0 ? 0 : (p.dx / w).clamp(0.0, 1.0);
          final v = value.clamp(0.0, 1.0);
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => onChanged(f(d.localPosition)),
              onHorizontalDragUpdate: (d) => (onDrag ?? onChanged)(f(d.localPosition)),
              onHorizontalDragEnd: (_) => onDragEnd?.call(),
              child: Stack(clipBehavior: Clip.none, alignment: Alignment.centerLeft, children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: (height - 3) / 2,
                  child: ProgressLine(v, height: 3, color: color),
                ),
                if (thumb)
                  Positioned(
                    left: w * v - 5.5,
                    top: (height - 11) / 2,
                    child: const SizedBox.square(
                      dimension: 11,
                      child: DecoratedBox(decoration: BoxDecoration(color: AppColors.a300, shape: BoxShape.circle)),
                    ),
                  ),
              ]),
            ),
          );
        }),
      );
}

/// `.btn` with an icon and optional label; the open tool gets accent text
/// and an accent outline.
class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.label, required this.icon, required this.tooltip, required this.active, required this.onTap});
  final String label;
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.accent : AppColors.text;
    return Tooltip(
      message: tooltip,
      child: Tappable(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            border: Border.all(color: active ? AppColors.accent : Colors.transparent),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: fg),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: fg)),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Header of a drawer panel: h5 title, key hint and close.
class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, required this.keyHint, required this.onClose, this.note, this.padding});
  final String title;
  final String keyHint;
  final String? note;
  final VoidCallback onClose;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(18, 16, 12, 10),
        child: Row(children: [
          Text(title, style: NocText.h5),
          if (note != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(note!,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.n500)),
            ),
          ],
          const Spacer(),
          KeyCap(keyHint),
          const SizedBox(width: 8),
          NocIconButton(icon: Ph.x, iconSize: 18, tooltip: 'Close (Esc)', onPressed: onClose),
        ]),
      );
}

/// Translucent blurred drawer surface.
class _Drawer extends StatelessWidget {
  const _Drawer({required this.child, this.bottom = false});
  final Widget child;
  final bool bottom;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: drawerDecoration(bottom: bottom),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Channels panel (C)
// ---------------------------------------------------------------------------

final _groupChannelsProvider = FutureProvider.autoDispose.family<List<MediaItem>, String?>((ref, group) async {
  final page = await ref
      .watch(repositoryProvider)
      .list(MediaKind.channel, playlistId: ref.watch(activePlaylistProvider), group: group, limit: 500);
  return page.items;
});

String _categoryOf(PlayerArgs a) => a.category ?? (a.item.group.isEmpty ? 'All' : a.item.group);

class _ChannelsPanel extends ConsumerStatefulWidget {
  const _ChannelsPanel({required this.args, required this.onPlay, required this.onClose});
  final PlayerArgs args;
  final void Function(MediaItem channel, List<MediaItem> list, String? category) onPlay;
  final VoidCallback onClose;

  @override
  ConsumerState<_ChannelsPanel> createState() => _ChannelsPanelState();
}

const _rowExtent = 60.0;

class _ChannelsPanelState extends ConsumerState<_ChannelsPanel> {
  late String _cat = _categoryOf(widget.args);
  late final _scroll = ScrollController(
    initialScrollOffset:
        math.max(0, widget.args.channels.indexWhere((c) => c.id == widget.args.item.id) - 3) * _rowExtent,
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    final current = _categoryOf(a);
    final names = ref.watch(categoriesProvider(MediaKind.channel)).value?.names ?? const <String>[];
    final cats = ['All', if (current != 'All' && !names.contains(current)) current, ...names];
    final fromArgs = _cat == current && a.channels.isNotEmpty;
    final async = fromArgs ? null : ref.watch(_groupChannelsProvider(_cat == 'All' ? null : _cat));
    final list = fromArgs ? a.channels : (async?.value ?? const <MediaItem>[]);

    return _Drawer(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _PanelHeader(title: 'Channels', keyHint: 'C', onClose: widget.onClose),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: Row(children: [
            for (final c in cats) ...[
              Pill(c, compact: true, selected: c == _cat, onTap: () => setState(() => _cat = c)),
              const SizedBox(width: 6),
            ],
          ]),
        ),
        Expanded(
          child: async != null && async.isLoading && list.isEmpty
              ? const Center(child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2)))
              : list.isEmpty
                  ? Center(child: Text('No channels', style: NocText.muted))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                      itemExtent: _rowExtent,
                      itemCount: list.length,
                      itemBuilder: (_, i) => _ChannelRow(
                        channel: list[i],
                        current: list[i].id == a.item.id,
                        onTap: () => widget.onPlay(list[i], list, _cat),
                      ),
                    ),
        ),
      ]),
    );
  }
}

class _ChannelRow extends ConsumerWidget {
  const _ChannelRow({required this.channel, required this.current, required this.onTap});
  final MediaItem channel;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = useChannelEpg(ref, channel)?.now;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Tappable(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: current ? AppColors.accentTint : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Stack(clipBehavior: Clip.none, children: [
            Row(children: [
              SizedBox(
                width: 30,
                child: Text(channel.number?.toString() ?? '',
                    style: _tab(12, current ? AppColors.accent : AppColors.n500)),
              ),
              const SizedBox(width: 12),
              LogoTile(
                label: channel.name,
                width: 44,
                height: 30,
                fontSize: 10.5,
                image: channel.logo == null
                    ? null
                    : NetImage(channel.logo, fit: BoxFit.contain, label: channel.name, fontSize: 10.5, memCacheWidth: 120),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(channel.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, height: 1.25)),
                    const SizedBox(height: 3),
                    Text(now?.title ?? channel.group,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.25)),
                    const SizedBox(height: 3),
                    ProgressLine(now?.progress ?? 0, color: AppColors.a600),
                  ],
                ),
              ),
            ]),
            if (current)
              Positioned(
                left: -10,
                top: 10,
                bottom: 10,
                child: Container(
                  width: 2,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Guide panel (G)
// ---------------------------------------------------------------------------

const _guideWindow = Duration(hours: 4);
const _guideLead = 180.0;

class _GuidePanel extends StatelessWidget {
  const _GuidePanel({required this.args, required this.onPlay, required this.onClose});
  final PlayerArgs args;
  final ValueChanged<MediaItem> onPlay;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final list = args.channels.isEmpty ? [args.item] : args.channels;
    final ci = math.max(0, list.indexWhere((c) => c.id == args.item.id));
    final seen = <String>{};
    final rows = [
      for (final d in [-2, -1, 0, 1, 2, 3]) list[(ci + d) % list.length],
    ].where((c) => seen.add(c.id)).toList();

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, now.hour).subtract(const Duration(hours: 1));
    double frac(DateTime t) => t.difference(start).inSeconds / _guideWindow.inSeconds;
    final cat = _categoryOf(args);

    return _Drawer(
      bottom: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _PanelHeader(
          title: 'Guide',
          note: 'Today · ${cat == 'All' ? 'All channels' : cat}',
          keyHint: 'G',
          onClose: onClose,
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                height: 20,
                child: Padding(
                  padding: const EdgeInsets.only(left: _guideLead),
                  child: LayoutBuilder(
                    builder: (_, c) => Stack(clipBehavior: Clip.none, children: [
                      for (var m = 0; m < 240; m += 30)
                        Positioned(
                          left: c.maxWidth * m / 240,
                          top: 0,
                          child: Text(formatClock(start.add(Duration(minutes: m))), style: _tab(11.5, AppColors.n500)),
                        ),
                    ]),
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (_, c) => Stack(children: [
                    Positioned.fill(
                      child: SingleChildScrollView(
                        child: Column(children: [
                          for (final ch in rows)
                            _GuideRow(
                              channel: ch,
                              current: ch.id == args.item.id,
                              start: start,
                              onTap: () => onPlay(ch),
                            ),
                        ]),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: _guideLead + (c.maxWidth - _guideLead) * frac(now).clamp(0.0, 1.0),
                      width: 1,
                      child: const IgnorePointer(child: ColoredBox(color: AppColors.accent)),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _GuideRow extends ConsumerWidget {
  const _GuideRow({required this.channel, required this.current, required this.start, required this.onTap});
  final MediaItem channel;
  final bool current;
  final DateTime start;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epg = useChannelEpg(ref, channel);
    final end = start.add(_guideWindow);
    final now = DateTime.now();
    final seen = <DateTime>{};
    final progs = [?epg?.now, ?epg?.next, ...?epg?.upcoming]
        .where((e) => e.start != null && e.end != null && e.end!.isAfter(start) && e.start!.isBefore(end))
        .where((e) => seen.add(e.start!))
        .toList();
    double frac(DateTime t) => (t.difference(start).inSeconds / _guideWindow.inSeconds).clamp(0.0, 1.0);

    return Container(
      height: 46,
      margin: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 172,
          child: Tappable(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: current ? AppColors.accentTint : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Row(children: [
                if (channel.number != null) ...[
                  Text('${channel.number}', style: _tab(12, current ? AppColors.accent : AppColors.n500)),
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
        const SizedBox(width: 8),
        Expanded(
          child: LayoutBuilder(builder: (_, c) {
            final w = c.maxWidth;
            if (progs.isEmpty) {
              return _GuideBlock(title: 'No guide information', time: '', dim: true, onTap: onTap);
            }
            return Stack(children: [
              for (final p in progs)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: w * frac(p.start!),
                  width: math.max(0, w * (frac(p.end!) - frac(p.start!))),
                  child: _GuideBlock(
                    title: p.title,
                    time: epgTime(p),
                    now: !p.start!.isAfter(now) && p.end!.isAfter(now),
                    dim: !p.end!.isAfter(now),
                    onTap: onTap,
                  ),
                ),
            ]);
          }),
        ),
      ]),
    );
  }
}

class _GuideBlock extends StatelessWidget {
  const _GuideBlock({required this.title, required this.time, required this.onTap, this.now = false, this.dim = false});
  final String title;
  final String time;
  final bool now;
  final bool dim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 3),
        child: Tooltip(
          message: time.isEmpty ? title : '$title · $time',
          child: Opacity(
            opacity: dim ? 0.5 : 1,
            child: Tappable(
              onTap: onTap,
              radius: Radii.sm,
              hover: AppColors.n800.withValues(alpha: 0.6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: now ? AppColors.a900 : AppColors.n900,
                  borderRadius: BorderRadius.circular(Radii.sm),
                  border: now ? Border.all(color: AppColors.a700) : null,
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: const TextStyle(fontSize: 12.5, height: 1.3)),
                  if (time.isNotEmpty)
                    Text(time, maxLines: 1, softWrap: false, overflow: TextOverflow.clip, style: _tab(11, AppColors.n500)),
                ]),
              ),
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Episodes panel (E)
// ---------------------------------------------------------------------------

class _EpisodesPanel extends ConsumerStatefulWidget {
  const _EpisodesPanel({required this.session, required this.onPlay, required this.onClose});
  final PlaybackSession session;
  final void Function(List<Episode> season, int index) onPlay;
  final VoidCallback onClose;

  @override
  ConsumerState<_EpisodesPanel> createState() => _EpisodesPanelState();
}

class _EpisodesPanelState extends ConsumerState<_EpisodesPanel> {
  Map<int, List<Episode>>? _seasons;
  late int _season = widget.session.args.episode!.season;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// The queue only holds the current season; fetch the rest.
  Future<void> _load() async {
    final a = widget.session.args;
    try {
      final full = await ref.read(repositoryProvider).detail(MediaKind.series, a.item.id);
      final all = Episode.bySeason(full.raw['episodes']);
      if (mounted && all.isNotEmpty) setState(() => _seasons = all);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final a = s.args;
    final cur = a.episode!;
    final seasons = _seasons ?? {cur.season: a.queue};
    final eps = seasons[_season] ?? a.queue;
    final curIndex = eps.indexWhere((e) => e.id == cur.id);

    return _Drawer(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _PanelHeader(title: 'Episodes', keyHint: 'E', onClose: widget.onClose),
        if (seasons.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Seg<int>(
                  options: [for (final n in seasons.keys) SegOption(n, 'Season $n')],
                  value: _season,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  onChanged: (n) => setState(() => _season = n),
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
              final on = e.id == cur.id;
              final done = _season < cur.season || (_season == cur.season && curIndex >= 0 && i < curIndex);
              return _EpisodeRow(
                episode: e,
                current: on,
                done: done,
                player: on ? s.player : null,
                onTap: () => widget.onPlay(eps, i),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({required this.episode, required this.current, required this.done, required this.onTap, this.player});
  final Episode episode;
  final bool current;
  final bool done;
  final Player? player;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = episode;
    final mins = e.durationSecs == null ? null : (e.durationSecs! / 60).round();
    final track = AppColors.text.withValues(alpha: 0.12);
    final thumb = SizedBox(
      width: 128,
      height: 72,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.sm),
        child: Stack(fit: StackFit.expand, children: [
          e.thumb != null && e.thumb!.startsWith('http')
              ? NetImage(e.thumb, memCacheWidth: 260)
              : ArtPlaceholder(
                  child: Text('E${e.episode}', style: const TextStyle(fontSize: 11, color: AppColors.n600)),
                ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: player == null
                ? ProgressLine(done ? 1 : 0, height: 3, track: track)
                : StreamBuilder<Duration>(
                    stream: player!.stream.position,
                    initialData: player!.state.position,
                    builder: (_, snap) {
                      final d = player!.state.duration.inMilliseconds;
                      return ProgressLine(d <= 0 ? 0 : (snap.data?.inMilliseconds ?? 0) / d, height: 3, track: track);
                    },
                  ),
          ),
        ]),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Tappable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: current ? AppColors.accentTint : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            thumb,
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text('${e.episode}. ${e.title}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.5, color: current ? AppColors.a300 : AppColors.text)),
                  ),
                  if (current) ...[const SizedBox(width: 6), const NocTag('Playing', kind: TagKind.accent)],
                  if (done && !current) ...[
                    const SizedBox(width: 6),
                    const Icon(Ph.check, size: 16, color: AppColors.a400),
                  ],
                ]),
                if (mins != null) ...[
                  const SizedBox(height: 3),
                  Text('$mins min', style: const TextStyle(fontSize: 11.5, color: AppColors.n500)),
                ],
                if (e.plot != null && e.plot!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(e.plot!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.text.withValues(alpha: 0.6))),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings popover (S)
// ---------------------------------------------------------------------------

class _SettingsPopover extends StatelessWidget {
  const _SettingsPopover({
    required this.tracks,
    required this.track,
    required this.rate,
    required this.showSpeed,
    required this.onAudio,
    required this.onSubtitle,
    required this.onRate,
    required this.onClose,
  });
  final Tracks tracks;
  final Track track;
  final double rate;
  final bool showSpeed;
  final ValueChanged<AudioTrack> onAudio;
  final ValueChanged<SubtitleTrack> onSubtitle;
  final ValueChanged<double> onRate;
  final VoidCallback onClose;

  static String _name(String id, String? title, String? lang) {
    final s = [?title, if (lang != null) lang.toUpperCase()].join(' · ');
    return s.isEmpty ? 'Track $id' : s;
  }

  static bool _real(String id) => id != 'auto' && id != 'no';

  @override
  Widget build(BuildContext context) {
    final audio = tracks.audio.where((t) => _real(t.id)).toList();
    final subs = tracks.subtitle.where((t) => _real(t.id)).toList();
    final audioId = _real(track.audio.id) ? track.audio.id : audio.firstOrNull?.id;
    final subId = track.subtitle.id;

    Widget option(String label, bool on, VoidCallback? onTap) => Tappable(
          onTap: onTap,
          radius: Radii.sm,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Icon(on ? Ph.check : Ph.dotOutline, size: 15, color: on ? AppColors.accent : AppColors.n300),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: on ? AppColors.accent : AppColors.n300)),
              ),
            ]),
          ),
        );
    Widget column(String title, List<Widget> children) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(bottom: 4), child: _overline(title)),
            ...children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 2), child: c)),
          ]),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: popoverDecoration(),
      child: Material(
        type: MaterialType.transparency,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Playback', style: NocText.h5)),
            NocIconButton(icon: Ph.x, iconSize: 18, tooltip: 'Close (Esc)', onPressed: onClose),
          ]),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            column('Audio', [
              if (audio.isEmpty) option('Default', true, null),
              for (final t in audio) option(_name(t.id, t.title, t.language), t.id == audioId, () => onAudio(t)),
            ]),
            const SizedBox(width: 14),
            column('Subtitles', [
              option('Off', !subs.any((t) => t.id == subId), () => onSubtitle(SubtitleTrack.no())),
              for (final t in subs) option(_name(t.id, t.title, t.language), t.id == subId, () => onSubtitle(t)),
            ]),
          ]),
          if (showSpeed) ...[
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.only(bottom: 6), child: _overline('Speed')),
            Seg<double>(
              expand: true,
              fontSize: 12.5,
              padding: const EdgeInsets.symmetric(vertical: 6),
              options: [for (final v in _speeds) SegOption(v, '${v == v.truncate() ? v.toInt() : v}×')],
              value: _speeds.contains(rate) ? rate : 1.0,
              onChanged: onRate,
            ),
          ],
        ]),
      ),
    );
  }
}

Widget _overline(String text) => Text(text.toUpperCase(),
    style: const TextStyle(fontSize: 11, letterSpacing: 0.88, color: AppColors.n500, height: 1.4));

// ---------------------------------------------------------------------------
// Up next, help, error
// ---------------------------------------------------------------------------

class _UpNextCard extends StatelessWidget {
  const _UpNextCard({required this.series, required this.next, required this.secs, required this.onCancel, required this.onPlay});
  final MediaItem series;
  final Episode next;
  final int secs;
  final VoidCallback onCancel;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: popoverDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text('Up next in $secs s', style: const TextStyle(fontSize: 12, color: AppColors.n400)),
          const SizedBox(height: 10),
          Row(children: [
            SizedBox(
              width: 96,
              height: 54,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sm),
                child: next.thumb != null && next.thumb!.startsWith('http')
                    ? NetImage(next.thumb, memCacheWidth: 200)
                    : ArtPlaceholder(
                        child: Text('E${next.episode}', style: const TextStyle(fontSize: 11, color: AppColors.n600)),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('E${next.episode} · ${next.title}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ]),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(end: (upNextCountdown - secs + 1) / upNextCountdown),
            duration: const Duration(seconds: 1),
            builder: (_, v, _) => ProgressLine(v),
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            NocButton(label: 'Cancel', onPressed: onCancel),
            const SizedBox(width: 6),
            NocButton.primary(label: 'Play now', icon: PhF.play, onPressed: onPlay),
          ]),
        ]),
      );
}

const _liveKeys = [
  ('Space', 'Play / pause'),
  ('↑ ↓', 'Change channel'),
  ('C', 'Channel list'),
  ('G', 'Guide'),
  ('S', 'Audio & subtitles'),
  ('M', 'Mute'),
  ('P', 'Picture-in-picture'),
  ('F', 'Full screen'),
  ('Esc', 'Close / back'),
  ('?', 'This list'),
];

const _vodKeys = [
  ('Space', 'Play / pause'),
  ('← →', 'Seek 10 s'),
  ('N', 'Next episode'),
  ('E', 'Episodes'),
  ('S', 'Audio, subs & speed'),
  ('M', 'Mute'),
  ('P', 'Picture-in-picture'),
  ('F', 'Full screen'),
  ('Esc', 'Close / back'),
  ('?', 'This list'),
];

class _HelpDialog extends StatelessWidget {
  const _HelpDialog({required this.live, required this.onClose});
  final bool live;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final keys = live ? _liveKeys : _vodKeys;
    Widget cell((String, String) k) => Expanded(
          child: Row(children: [
            KeyCap(k.$1, minWidth: 44, color: AppColors.n300),
            const SizedBox(width: 10),
            Expanded(child: Text(k.$2, style: const TextStyle(fontSize: 13, color: AppColors.n300))),
          ]),
        );
    return GestureDetector(
      onTap: onClose,
      child: ColoredBox(
        color: AppColors.n900.withValues(alpha: 0.6),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: math.min(520, MediaQuery.sizeOf(context).width * 0.92),
              padding: const EdgeInsets.all(11.2),
              decoration: popoverDecoration(),
              child: Material(
                type: MaterialType.transparency,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(child: Text('Keyboard shortcuts', style: NocText.h4)),
                    NocIconButton(icon: Ph.x, iconSize: 18, tooltip: 'Close (Esc)', onPressed: onClose),
                  ]),
                  const SizedBox(height: 8.4),
                  for (var i = 0; i < keys.length; i += 2)
                    Padding(
                      padding: EdgeInsets.only(bottom: i + 2 < keys.length ? 8 : 0),
                      child: Row(children: [
                        cell(keys[i]),
                        const SizedBox(width: 24),
                        if (i + 1 < keys.length) cell(keys[i + 1]) else const Spacer(),
                      ]),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.message, required this.onClose, required this.onRetry});
  final String message;
  final VoidCallback onClose;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: AppColors.video.withValues(alpha: 0.9),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Ph.warningCircle, size: 40, color: AppColors.danger),
              const SizedBox(height: 12),
              Text('Playback failed', style: NocText.h5),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.muted)),
              ),
              const SizedBox(height: 18),
              Row(mainAxisSize: MainAxisSize.min, children: [
                NocButton(label: 'Close', onPressed: onClose),
                const SizedBox(width: 8),
                NocButton.primary(label: 'Retry', icon: Ph.arrowClockwise, onPressed: onRetry),
              ]),
            ]),
          ),
        ),
      );
}
