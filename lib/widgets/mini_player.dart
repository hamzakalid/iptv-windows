import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/theme.dart';
import '../state/playback.dart';
import 'media_cards.dart';
import 'nocturne.dart';

/// Picture-in-picture: the stream keeps playing in a floating card while the
/// user browses. Click the video (or expand) to go back to the full player.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, this.onExpand});

  /// Opens the full player. Defaults to pushing `/player` from [context];
  /// pass one when mounted above the router (MaterialApp.builder).
  final void Function(PlayerArgs args)? onExpand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(playbackProvider);
    if (s == null || !s.pip) return const SizedBox.shrink();
    final a = s.args;
    final ctrl = ref.read(playbackProvider.notifier);
    void expand() => onExpand != null ? onExpand!(a) : context.push('/player', extra: a);

    final now = a.isLive ? useChannelEpg(ref, a.item)?.now : null;
    final title = a.isLive ? channelLabel(a.item) : a.title;
    final sub = a.isLive ? (now?.title ?? a.item.group) : (a.subtitle ?? '');

    return Container(
      width: 336,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: Shadows.lg,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: expand,
              child: Stack(fit: StackFit.expand, children: [
                IgnorePointer(
                  child: Video(controller: s.video, controls: NoVideoControls, fill: AppColors.video),
                ),
                if (a.isLive) const Positioned(top: 8, left: 8, child: NocTag('LIVE', kind: TagKind.accent)),
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                if (sub.isNotEmpty)
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
              ]),
            ),
            const SizedBox(width: 4),
            StreamBuilder<bool>(
              stream: s.player.stream.playing,
              initialData: s.player.state.playing,
              builder: (_, snap) => NocIconButton(
                icon: snap.data ?? false ? PhF.pause : PhF.play,
                iconSize: 18,
                tooltip: 'Play / pause',
                onPressed: ctrl.togglePlay,
              ),
            ),
            const SizedBox(width: 4),
            NocIconButton(icon: Ph.arrowsOutSimple, iconSize: 18, tooltip: 'Back to player', onPressed: expand),
            const SizedBox(width: 4),
            NocIconButton(icon: Ph.x, iconSize: 18, tooltip: 'Close', onPressed: ctrl.stop),
          ]),
        ),
      ]),
    );
  }
}
