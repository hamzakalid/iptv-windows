import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../features/player/player_screen.dart';
import '../models/account.dart';
import '../models/media.dart';
import '../state/providers.dart';
import 'common.dart';

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

void resumeEntry(BuildContext context, ContinueItem entry) {
  final item = entry.item!;
  if (entry.kind == MediaKind.series) {
    // Episode URLs live on the series detail, which offers "Resume".
    openItem(context, item);
    return;
  }
  PlayerScreen.open(context, PlayerArgs.movie(item, startAt: entry.positionSecs));
}

/// "2021 · ★ 8.2" under a poster; falls back to the category.
String posterSubtitle(MediaItem item) {
  final parts = [
    if (item.year != null) '${item.year}',
    if (item.rating != null && item.rating! > 0) '★ ${item.rating!.toStringAsFixed(1)}',
  ];
  return parts.isEmpty ? item.group : parts.join(' · ');
}

/// "101 · BBC News" when the provider numbers its channels.
String channelLabel(MediaItem c) => c.number == null ? c.name : '${c.number} · ${c.name}';

/// Movie: "38% · 1h 12m left". Series: "S2 · E3 — Title".
String resumeSubtitle(ContinueItem c) {
  if (c.kind == MediaKind.series && c.season != null) {
    return 'S${c.season} · E${c.episode ?? '?'}${c.episodeTitle != null ? ' — ${c.episodeTitle}' : ''}';
  }
  final left = c.durationSecs == null ? null : c.durationSecs! - c.positionSecs;
  return [
    '${c.progressPct.round()}%',
    if (left != null && left > 60) '${formatDuration(left)} left',
  ].join(' · ');
}

Future<void> toggleSaved(BuildContext context, WidgetRef ref, MediaItem item) async {
  try {
    await ref.read(favoritesProvider.notifier).toggle(item);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update My List: $e')));
    }
  }
}

/// Small square button that sits on artwork (bookmark, favourite star).
class ArtButton extends StatefulWidget {
  const ArtButton({super.key, required this.icon, required this.color, required this.tooltip, required this.onTap, this.scrim = true});
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final bool scrim;

  @override
  State<ArtButton> createState() => _ArtButtonState();
}

class _ArtButtonState extends State<ArtButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.scrim
        ? AppColors.bg.withValues(alpha: _hover ? 0.85 : 0.55)
        : (_hover ? AppColors.wash(0.10) : Colors.transparent);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.md)),
            child: Icon(widget.icon, size: 15, color: widget.color),
          ),
        ),
      ),
    );
  }
}

/// 2:3 poster with a bookmark, "Watched" tag and resume strip, then the
/// title and a muted meta line.
class PosterCard extends ConsumerWidget {
  const PosterCard({super.key, required this.item, this.width});
  final MediaItem item;
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(favoritesProvider);
    final saved = ref.read(favoritesProvider.notifier).contains(item.id);
    final watched = ref.watch(watchedIdsProvider).contains(item.id);
    final resume = ref.watch(resumeProvider)[item.id];
    final pct = watched ? 0.0 : (resume?.progressPct ?? 0) / 100;

    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 2 / 3,
          child: Hoverable(
            onTap: () => openItem(context, item),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.md),
              child: Stack(fit: StackFit.expand, children: [
                NetImage(item.logo, label: item.name, memCacheWidth: 360),
                Positioned(
                  top: 4,
                  right: 4,
                  child: ArtButton(
                    icon: saved ? PhosphorIconsFill.bookmarkSimple : PhosphorIconsRegular.bookmarkSimple,
                    color: saved ? AppColors.accent : AppColors.neutral300,
                    tooltip: saved ? 'Remove from My List' : 'Add to My List',
                    onTap: () => toggleSaved(context, ref, item),
                  ),
                ),
                if (watched)
                  const Positioned(
                    left: 6,
                    bottom: 8,
                    child: Tag('Watched', tone: TagTone.accent, icon: PhosphorIconsRegular.check),
                  ),
                if (pct > 0) ArtProgress(pct),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title),
        const SizedBox(height: 1),
        Text(posterSubtitle(item), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.meta),
      ]),
    );
  }
}

/// Height of a [PosterCard] below its artwork (gap + title + meta line).
const posterCaptionHeight = 44.0;

/// Live TV grid card: logo band with number and favourite star, then the
/// channel name, what's on now with its progress, and what's next.
class ChannelCard extends ConsumerWidget {
  const ChannelCard({super.key, required this.item, this.playing = false});
  final MediaItem item;
  final bool playing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(favoritesProvider);
    final fav = ref.read(favoritesProvider.notifier).contains(item.id);
    final epg = item.epg;
    final now = epg.now;
    final next = epg.next;
    const muted = TextStyle(fontSize: 11.5, color: AppColors.textMuted);

    return Hoverable(
      onTap: () => openItem(context, item),
      color: AppColors.surface,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
            aspectRatio: 2,
            child: Stack(fit: StackFit.expand, children: [
              const ArtFallback(),
              item.logo != null && item.logo!.startsWith('http')
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(36, 22, 36, 18),
                      child: NetImage(item.logo, fit: BoxFit.contain, label: item.name, labelSize: 22, memCacheWidth: 300),
                    )
                  : Center(
                      child: Text(initials(item.name),
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w500, letterSpacing: 0.9, color: AppColors.neutral500)),
                    ),
              if (item.number != null)
                Positioned(
                  top: 8,
                  left: 10,
                  child: Text(item.number!, style: AppText.tabular.copyWith(fontSize: 11, color: AppColors.neutral400)),
                ),
              Positioned(
                top: 4,
                right: 4,
                child: ArtButton(
                  scrim: false,
                  icon: fav ? PhosphorIconsFill.star : PhosphorIconsRegular.star,
                  color: fav ? AppColors.accent : AppColors.neutral600,
                  tooltip: fav ? 'Remove from favourites' : 'Add to favourites',
                  onTap: () => toggleSaved(context, ref, item),
                ),
              ),
              if (playing)
                const Positioned(
                  left: 10,
                  bottom: 8,
                  child: Tag('Playing', tone: TagTone.accent, icon: PhosphorIconsFill.speakerHigh),
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
                        style: const TextStyle(fontSize: 11, color: AppColors.neutral600)),
                  ),
                ],
              ]),
              const SizedBox(height: 4),
              Text(now?.title ?? 'No guide information',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: now == null ? AppColors.neutral600 : AppColors.neutral300)),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
                child: ThinProgress(now?.progress ?? 0),
              ),
              Row(children: [
                Text(now == null ? ' ' : '${formatClock(now.start)} – ${formatClock(now.end)}',
                    style: muted.merge(AppText.tabular)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(next == null ? '' : 'Next ${formatClock(next.start)} ${next.title}',
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: muted.merge(AppText.tabular)),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Height of a [ChannelCard]'s text block below its 2:1 logo band.
const channelCardBodyHeight = 100.0;

/// Compact surface card for the home "Live now" row.
class LiveNowCard extends StatelessWidget {
  const LiveNowCard({super.key, required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final now = item.epg.now;
    return SurfaceCard(
      onTap: () => openItem(context, item),
      child: Row(children: [
        LogoTile(url: item.logo, label: item.name),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text(item.number == null ? item.group : channelLabel(item),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.neutral500)),
            const SizedBox(height: 3),
            Text(now?.title ?? item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
            const SizedBox(height: 6),
            ThinProgress(now?.progress ?? 0),
          ]),
        ),
      ]),
    );
  }
}

/// Outlined chip for a channel ("Recently watched", "Favourite channels").
class ChannelChip extends StatefulWidget {
  const ChannelChip({super.key, required this.item});
  final MediaItem item;

  @override
  State<ChannelChip> createState() => _ChannelChipState();
}

class _ChannelChipState extends State<ChannelChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.item;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => openItem(context, c),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
          decoration: BoxDecoration(
            color: _hover ? AppColors.tint(0.08) : Colors.transparent,
            border: Border.all(color: _hover ? AppColors.accent : AppColors.divider),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            LogoTile(url: c.logo, label: c.name, width: 36, height: 36),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(channelLabel(c), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                Text(c.epg.now?.title ?? c.group,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Surface row for a channel in search results.
class ChannelResultRow extends StatelessWidget {
  const ChannelResultRow({super.key, required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) => SurfaceCard(
        onTap: () => openItem(context, item),
        child: Row(children: [
          LogoTile(url: item.logo, label: item.name, width: 44, height: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(channelLabel(item), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
              const SizedBox(height: 2),
              Text(item.epg.now == null ? item.group : 'Now: ${item.epg.now!.title}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.meta),
            ]),
          ),
          const Icon(PhosphorIconsFill.play, size: 16, color: AppColors.accent),
        ]),
      );
}

/// Round outlined play mark over artwork.
class PlayMark extends StatelessWidget {
  const PlayMark({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.accent),
          color: AppColors.bg.withValues(alpha: size > 60 ? 0.6 : 0.5),
        ),
        child: Icon(PhosphorIconsFill.play, size: size * 0.4, color: AppColors.accent),
      );
}

/// 16:9 "Continue watching" card with a resume strip and a caption.
class ContinueCard extends StatelessWidget {
  const ContinueCard({super.key, required this.entry, this.width = 280});
  final ContinueItem entry;
  final double width;

  @override
  Widget build(BuildContext context) {
    final item = entry.item!;
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Hoverable(
            onTap: () => resumeEntry(context, entry),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.md),
              child: Stack(fit: StackFit.expand, children: [
                NetImage(item.backdrop, label: item.name, labelSize: 0, memCacheWidth: 600),
                const Center(child: PlayMark()),
                ArtProgress(entry.progressPct / 100),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title),
        Text(resumeSubtitle(entry), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.meta),
      ]),
    );
  }
}

/// Picks the right card for an item.
class MediaCard extends StatelessWidget {
  const MediaCard({super.key, required this.item, this.width});
  final MediaItem item;
  final double? width;

  @override
  Widget build(BuildContext context) => item.kind == MediaKind.channel
      ? ChannelCard(item: item)
      : PosterCard(item: item, width: width);
}
