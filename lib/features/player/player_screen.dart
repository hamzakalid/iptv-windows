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

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final _player = Player();
  late final _video = VideoController(_player);
  late PlayerArgs _args = widget.args;
  Timer? _reporter;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<String>? _errorSub;
  String? _error;
  EpgEntry? _now;
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
    _completedSub = _player.stream.completed.listen((done) {
      if (done && _hasNext) _playNext();
    });
    _errorSub = _player.stream.error.listen((e) {
      if (mounted) setState(() => _error = e);
    });
    _start();
    _reporter = Timer.periodic(const Duration(seconds: 15), (_) => _report());
  }

  Future<void> _start() async {
    final repo = _repo;
    var startAt = _args.startAt;
    if (_args.isLive) {
      _loadEpg();
      unawaited(repo.reportProgress(kind: MediaKind.channel, contentId: _args.item.id).catchError((_) {}));
    } else if (startAt == null) {
      // Resume where the user left off unless they'd basically finished.
      final p = await repo.progressFor(_args.item.id, episodeId: _args.episode?.id).catchError((_) => null);
      if (p != null && !p.completed && p.positionSecs > 30) startAt = p.positionSecs;
    }
    if (!mounted) return;
    setState(() => _error = null);
    await _player.open(Media(_args.url, start: startAt == null ? null : Duration(seconds: startAt)));
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

  bool get _hasNext => _args.queue.isNotEmpty && _args.queueIndex < _args.queue.length - 1;

  void _playNext() {
    _report();
    setState(() => _args = PlayerArgs.episode(_args.item, _args.queue, _args.queueIndex + 1, startAt: 0));
    _start();
  }

  @override
  void dispose() {
    _report();
    _reporter?.cancel();
    _completedSub?.cancel();
    _errorSub?.cancel();
    _player.dispose();
    // Progress changed; refresh anything that shows it.
    _container.invalidate(homeProvider);
    if (_isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([]);
    }
    super.dispose();
  }

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
                if (_args.isLive) ...[_liveDot(), const SizedBox(width: 8)],
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

  Widget _liveDot() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: AppColors.live, borderRadius: BorderRadius.circular(4)),
        child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
      );

  @override
  Widget build(BuildContext context) {
    final top = [_topBar()];
    final video = Video(controller: _video, controls: AdaptiveVideoControls);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: MaterialVideoControlsTheme(
            normal: MaterialVideoControlsThemeData(
              topButtonBar: top,
              seekBarPositionColor: AppColors.accent,
              seekBarThumbColor: AppColors.accent,
              displaySeekBar: !_args.isLive,
            ),
            fullscreen: MaterialVideoControlsThemeData(topButtonBar: top, displaySeekBar: !_args.isLive),
            child: MaterialDesktopVideoControlsTheme(
              normal: MaterialDesktopVideoControlsThemeData(
                topButtonBar: top,
                seekBarPositionColor: AppColors.accent,
                seekBarThumbColor: AppColors.accent,
                displaySeekBar: !_args.isLive,
              ),
              fullscreen: MaterialDesktopVideoControlsThemeData(topButtonBar: top, displaySeekBar: !_args.isLive),
              child: video,
            ),
          ),
        ),
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
