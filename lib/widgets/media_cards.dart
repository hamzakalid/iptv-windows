import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/account.dart';
import '../models/media.dart';
import '../features/player/player_screen.dart';
import '../state/providers.dart';
import 'common.dart';
import 'nocturne.dart';

/// Opens the right screen for any catalogue item.
void openItem(BuildContext context, MediaItem item) {
  switch (item.kind) {
    case MediaKind.movie:
      context.push('/movie/${item.id}', extra: item);
    case MediaKind.series:
      context.push('/series/${item.id}', extra: item);
    case MediaKind.channel:
      PlayerScreen.open(context, PlayerArgs.channel(item));
  }
}

/// Plays a movie directly, or opens the detail page for anything else.
void playItem(BuildContext context, MediaItem item) {
  if (item.kind == MediaKind.movie) {
    PlayerScreen.open(context, PlayerArgs.movie(item));
  } else {
    openItem(context, item);
  }
}

/// Toggles My List and reports failures as a toast.
void toggleSaved(BuildContext context, WidgetRef ref, MediaItem item) {
  ref.read(favoritesProvider.notifier).toggle(item).catchError((_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t update My List.')));
    }
  });
}

/// "2019 · ★ 7.4" for movies, "2019 · 2 seasons" for series.
String posterSubtitle(MediaItem item) {
  final parts = <String>[
    if (item.year != null) '${item.year}',
    if (item.kind == MediaKind.series)
      item.seasonCount != null ? '${item.seasonCount} season${item.seasonCount == 1 ? '' : 's'}' : 'Series'
    else if (item.rating != null && item.rating! > 0)
      '★ ${item.rating!.toStringAsFixed(1)}',
  ];
  return parts.isEmpty ? item.group : parts.join(' · ');
}

/// Muted meta line under a poster.
class MetaLine extends StatelessWidget {
  const MetaLine(this.item, {super.key});
  final MediaItem item;

  @override
  Widget build(BuildContext context) => Text(posterSubtitle(item),
      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.muted));
}

/// 2:3 poster: bookmark to save, "Watched" tag, progress line, then title
/// and a muted meta line. Hover draws the accent ring.
class PosterCard extends ConsumerWidget {
  const PosterCard({super.key, required this.item, this.width});
  final MediaItem item;
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(favoritesProvider);
    final saved = ref.read(favoritesProvider.notifier).contains(item.id);
    final watched = ref.watch(watchedIdsProvider).contains(item.id);
    final pct = ref.watch(progressByIdProvider)[item.id] ?? 0;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: HoverRing(
              onTap: () => openItem(context, item),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.md),
                child: Stack(fit: StackFit.expand, children: [
                  NetImage(item.logo, label: item.name, memCacheWidth: 400),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GlassIconButton(
                      icon: saved ? PhF.bookmarkSimple : Ph.bookmarkSimple,
                      color: saved ? AppColors.accent : AppColors.n300,
                      tooltip: saved ? 'Remove from My List' : 'Add to My List',
                      onTap: () => toggleSaved(context, ref, item),
                    ),
                  ),
                  if (watched)
                    const Positioned(left: 6, bottom: 8, child: NocTag('Watched', kind: TagKind.accent, icon: Ph.check)),
                  if (pct > 0 && !watched)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ProgressLine(pct, height: 3, track: AppColors.text.withValues(alpha: 0.12)),
                    ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
          const SizedBox(height: 1),
          MetaLine(item),
        ],
      ),
    );
  }
}

/// EPG for a channel card: cached list details first, then a lazy fetch.
ChannelEpg? useChannelEpg(WidgetRef ref, MediaItem channel) =>
    cachedEpg(channel) ?? ref.watch(channelEpgProvider(channel.id)).value;

/// "17:00 – 18:00"
String epgTime(EpgEntry e) => '${formatClock(e.start)} – ${formatClock(e.end)}';

/// Live TV grid card: 16:8 logo area with number, favourite star and a
/// "Playing" tag, then name + group, what's on now, progress and next.
class ChannelCard extends ConsumerWidget {
  const ChannelCard({super.key, required this.item, this.width, this.showEpg = true, this.onTap});
  final MediaItem item;
  final double? width;
  final bool showEpg;

  /// Defaults to playing the channel on its own.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(favoritesProvider);
    final fav = ref.read(favoritesProvider.notifier).contains(item.id);
    final playing = ref.watch(playingContentIdProvider) == item.id;
    final epg = showEpg ? useChannelEpg(ref, item) : null;
    final now = epg?.now;
    final next = epg?.next;
    final muted = TextStyle(fontSize: 11.5, color: AppColors.muted, fontFeatures: NocText.tabular);

    return SizedBox(
      width: width,
      child: HoverRing(
        active: playing,
        onTap: onTap ?? () => openItem(context, item),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Radii.md)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            AspectRatio(
              aspectRatio: 16 / 8,
              child: Stack(fit: StackFit.expand, children: [
                ArtPlaceholder(
                  center: const Alignment(-0.4, -0.6),
                  fontSize: 22,
                  textColor: AppColors.n500,
                  label: item.name,
                  child: item.logo == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(40, 22, 40, 22),
                          child: NetImage(item.logo, fit: BoxFit.contain, label: item.name, memCacheWidth: 300),
                        ),
                ),
                if (item.number != null)
                  Positioned(
                    top: 8,
                    left: 10,
                    child: Text('${item.number}',
                        style: const TextStyle(fontSize: 11, color: AppColors.n400, fontFeatures: NocText.tabular)),
                  ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: NocIconButton(
                    icon: fav ? PhF.star : Ph.star,
                    size: 30,
                    iconSize: 16,
                    color: fav ? AppColors.accent : AppColors.n600,
                    tooltip: fav ? 'Remove from favourites' : 'Favourite',
                    onPressed: () => toggleSaved(context, ref, item),
                  ),
                ),
                if (playing)
                  const Positioned(
                    left: 10,
                    bottom: 8,
                    child: NocTag('Playing', kind: TagKind.accent, icon: PhF.speakerHigh),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Expanded(
                    child: Text(item.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  if (item.group.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Text(item.group,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.n600)),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                Text(now?.title ?? (showEpg ? 'No guide data' : item.group),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: now == null ? AppColors.n600 : AppColors.n300)),
                const SizedBox(height: 8),
                ProgressLine(now?.progress ?? 0),
                const SizedBox(height: 6),
                Row(children: [
                  Text(now == null ? '' : epgTime(now), style: muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(next == null ? '' : 'Next ${formatClock(next.start)} ${next.title}',
                        textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Compact "Live now" tile: logo, "101 · Name", what's on, progress.
class LiveNowTile extends ConsumerWidget {
  const LiveNowTile({super.key, required this.item, this.width = 260, this.logoSize = 48});
  final MediaItem item;
  final double width;
  final double logoSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = useChannelEpg(ref, item)?.now;
    return SizedBox(
      width: width,
      child: HoverRing(
        ring: Shadows.accentRing,
        onTap: () => openItem(context, item),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Radii.md)),
          child: Row(children: [
            LogoTile(
              label: item.name,
              width: logoSize,
              height: logoSize,
              fontSize: 12,
              image: item.logo == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.all(6),
                      child: NetImage(item.logo, fit: BoxFit.contain, label: item.name, memCacheWidth: 120),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Text(channelLabel(item),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.n500)),
                const SizedBox(height: 3),
                Text(now?.title ?? item.group,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
                const SizedBox(height: 5),
                ProgressLine(now?.progress ?? 0),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// "101 · BBC News HD", or just the name when there's no number.
String channelLabel(MediaItem c) => c.number == null ? c.name : '${c.number} · ${c.name}';

/// Outlined chip for a channel ("Recently watched", "Favourite channels").
class ChannelChip extends ConsumerWidget {
  const ChannelChip({super.key, required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = useChannelEpg(ref, item)?.now;
    return _OutlineHover(
      onTap: () => openItem(context, item),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          LogoTile(
            label: item.name,
            image: item.logo == null
                ? null
                : Padding(
                    padding: const EdgeInsets.all(4),
                    child: NetImage(item.logo, fit: BoxFit.contain, label: item.name, memCacheWidth: 96),
                  ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(channelLabel(item), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              Text(now?.title ?? item.group,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Divider-outlined box that turns accent (with a faint tint) on hover.
class _OutlineHover extends StatefulWidget {
  const _OutlineHover({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_OutlineHover> createState() => _OutlineHoverState();
}

class _OutlineHoverState extends State<_OutlineHover> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: _hover ? AppColors.accent.withValues(alpha: 0.08) : Colors.transparent,
              border: Border.all(color: _hover ? AppColors.accent : AppColors.divider),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: widget.child,
          ),
        ),
      );
}

void resumeEntry(BuildContext context, ContinueItem entry) {
  final item = entry.item!;
  if (entry.kind == MediaKind.series) {
    // Episode URLs live on the series detail; open it and let the user pick.
    openItem(context, item);
    return;
  }
  PlayerScreen.open(context, PlayerArgs.movie(item, startAt: entry.positionSecs));
}

/// "Continue watching" card: 16:9 artwork with a centred accent play ring
/// and a progress line, then title + "38% · 1h 02m left" / "S2 · E3 — Title".
class ContinueCard extends StatelessWidget {
  const ContinueCard({super.key, required this.entry, this.width = 280});
  final ContinueItem entry;
  final double width;

  @override
  Widget build(BuildContext context) {
    final item = entry.item!;
    final left = entry.durationSecs == null ? null : entry.durationSecs! - entry.positionSecs;
    final subtitle = entry.kind == MediaKind.series && entry.season != null
        ? 'S${entry.season} · E${entry.episode ?? '?'}${entry.episodeTitle != null ? ' — ${entry.episodeTitle}' : ''}'
        : '${entry.progressPct.round()}%${left != null && left > 0 ? ' · ${formatDuration(left)} left' : ''}';
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: () => resumeEntry(context, entry),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: HoverRing(
              onTap: () => resumeEntry(context, entry),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.md),
                child: Stack(fit: StackFit.expand, children: [
                  NetImage(item.backdrop, label: item.name, memCacheWidth: 600),
                  const Center(child: PlayRing()),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ProgressLine(entry.progressPct / 100,
                        height: 3, track: AppColors.text.withValues(alpha: 0.12)),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(item.name,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
      ),
    );
  }
}

/// Round accent-outlined play glyph over artwork.
class PlayRing extends StatelessWidget {
  const PlayRing({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.accent),
          color: AppColors.bg.withValues(alpha: 0.5),
        ),
        child: Icon(PhF.play, size: size * 0.4, color: AppColors.accent),
      );
}

class ProgressBar extends StatelessWidget {
  const ProgressBar(this.value, {super.key, this.height = 3});
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) =>
      ProgressLine(value, height: height, track: AppColors.text.withValues(alpha: 0.12));
}

/// Picks the right card for an item.
class MediaCard extends StatelessWidget {
  const MediaCard({super.key, required this.item, this.width});
  final MediaItem item;
  final double? width;

  @override
  Widget build(BuildContext context) => item.kind == MediaKind.channel
      ? ChannelCard(item: item, width: width)
      : PosterCard(item: item, width: width);
}
