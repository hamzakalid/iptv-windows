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

/// "2025 • ★ 7.1" under a poster; falls back to the category.
class MetaLine extends StatelessWidget {
  const MetaLine(this.item, {super.key});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted);
    final hasRating = item.rating != null && item.rating! > 0;
    if (item.year == null && !hasRating) {
      return Text(item.group, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted);
    }
    return Row(children: [
      if (item.year != null) Text('${item.year}', style: muted),
      if (item.year != null && hasRating) Text('  •  ', style: muted),
      if (hasRating) StarRating(item.rating!),
    ]);
  }
}

/// 2:3 poster with title and meta line. Hovering (desktop) reveals a
/// quick-play overlay with genre and duration.
class PosterCard extends ConsumerWidget {
  const PosterCard({super.key, required this.item, this.width});
  final MediaItem item;
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final watched = item.kind == MediaKind.movie && ref.watch(watchedIdsProvider).contains(item.id);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Hoverable(
              radius: Radii.card,
              onTap: () => openItem(context, item),
              overlay: context.hasMouse ? _PosterOverlay(item: item) : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.card),
                child: Stack(fit: StackFit.expand, children: [
                  NetImage(item.logo, label: item.name, memCacheWidth: 400),
                  if (watched)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                      ),
                    ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          MetaLine(item),
        ],
      ),
    );
  }
}

class _PosterOverlay extends StatelessWidget {
  const _PosterOverlay({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final info = [
      if (item.genres.isNotEmpty) item.genres.take(2).join(' · '),
      if (item.durationSecs != null && item.durationSecs! > 0) formatDuration(item.durationSecs),
    ].join('  •  ');
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.card),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x33000000), Color(0xD9000000)],
          ),
        ),
        child: Stack(children: [
          Center(
            child: GlassIconButton(icon: Icons.play_arrow_rounded, size: 52, onTap: () => playItem(context, item)),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (info.isNotEmpty)
                Text(info, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.3)),
              if (item.plot != null) ...[
                const SizedBox(height: 4),
                Text(item.plot!, maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.white60, height: 1.3)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// 16:10 tile with a centred channel logo.
class ChannelCard extends StatelessWidget {
  const ChannelCard({super.key, required this.item, this.width});
  final MediaItem item;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Hoverable(
              radius: Radii.card,
              onTap: () => openItem(context, item),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.card),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1F2430), Color(0xFF161A22)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Stack(children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item.logo == null
                            ? NetImage(null, label: item.name)
                            : NetImage(item.logo, fit: BoxFit.contain, label: item.name, memCacheWidth: 300),
                      ),
                    ),
                  ),
                  const Positioned(top: 8, left: 8, child: LiveBadge()),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          if (item.group.isNotEmpty)
            Text(item.group, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
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

/// Landscape card with a progress bar, for "Continue watching".
class ContinueCard extends StatelessWidget {
  const ContinueCard({super.key, required this.entry, this.width = 280});
  final ContinueItem entry;
  final double width;

  @override
  Widget build(BuildContext context) {
    final item = entry.item!;
    final t = Theme.of(context).textTheme;
    final subtitle = entry.kind == MediaKind.series && entry.season != null
        ? 'S${entry.season} · E${entry.episode ?? '?'}${entry.episodeTitle != null ? ' · ${entry.episodeTitle}' : ''}'
        : '${formatDuration(entry.positionSecs)} watched · ${(entry.progressPct).round()}%';
    return SizedBox(
      width: width,
      child: Hoverable(
        radius: Radii.card,
        onTap: () => resumeEntry(context, entry),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.card),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(fit: StackFit.expand, children: [
              NetImage(item.backdrop, label: item.name, memCacheWidth: 600),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xE6000000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.35, 1],
                  ),
                ),
              ),
              Center(child: GlassIconButton(icon: Icons.play_arrow_rounded, size: 46, onTap: () => resumeEntry(context, entry))),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(color: Colors.white70)),
                  const SizedBox(height: 8),
                  ProgressBar(entry.progressPct / 100),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class ProgressBar extends StatelessWidget {
  const ProgressBar(this.value, {super.key, this.height = 4});
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: value.clamp(0, 1),
          minHeight: height,
          backgroundColor: Colors.white24,
          color: AppColors.accent,
        ),
      );
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

/// One slide of the featured carousel: a rounded backdrop card with genre
/// pills on top, title + actions at the bottom and a save button.
class HeroCard extends ConsumerWidget {
  const HeroCard({super.key, required this.item, this.compact = false});
  final MediaItem item;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    ref.watch(favoritesProvider);
    final saved = ref.read(favoritesProvider.notifier).contains(item.id);
    final pills = <String>{
      item.kind.label,
      ...item.genres.take(3),
      if (item.genres.isEmpty && item.group.isNotEmpty) item.group,
    }.toList();
    final details = [
      if (item.year != null) '${item.year}',
      if (item.durationSecs != null && item.durationSecs! > 0) formatDuration(item.durationSecs),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.hero),
      child: Stack(fit: StackFit.expand, children: [
        NetImage(item.backdrop, label: item.name),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x66000000), Colors.transparent, Color(0xE6000000)],
              stops: [0, 0.35, 1],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Color(0x99000000), Colors.transparent], stops: [0, 0.65]),
          ),
        ),
        Positioned(
          top: compact ? 12 : 18,
          left: compact ? 12 : 20,
          right: 60,
          child: Wrap(spacing: 6, runSpacing: 6, children: [for (final p in pills) Pill(p)]),
        ),
        Positioned(
          top: compact ? 8 : 14,
          right: compact ? 8 : 14,
          child: GlassIconButton(
            icon: saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: saved ? AppColors.accent : Colors.white,
            tooltip: saved ? 'Remove from My List' : 'Add to My List',
            onTap: () => ref.read(favoritesProvider.notifier).toggle(item).catchError((_) {}),
          ),
        ),
        Positioned(
          left: compact ? 14 : 24,
          right: compact ? 14 : 24,
          bottom: compact ? 14 : 22,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: (compact ? t.headlineSmall : t.headlineLarge)?.copyWith(height: 1.05)),
                const SizedBox(height: 8),
                Row(children: [
                  if (item.rating != null && item.rating! > 0) ...[
                    StarRating(item.rating!, size: 13),
                    const SizedBox(width: 10),
                  ],
                  Text(details.join('  •  '), style: t.bodyMedium?.copyWith(color: Colors.white70)),
                ]),
                if (!compact && item.plot != null) ...[
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Text(item.plot!, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: t.bodyMedium?.copyWith(color: Colors.white70, height: 1.45)),
                  ),
                ],
                SizedBox(height: compact ? 12 : 16),
                Row(children: [
                  GradientButton(
                    label: item.kind == MediaKind.movie ? 'Play' : 'Watch',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => playItem(context, item),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.35),
                      side: const BorderSide(color: Colors.white24),
                    ),
                    onPressed: () => openItem(context, item),
                    icon: const Icon(Icons.info_outline_rounded, size: 20),
                    label: Text(compact ? 'Info' : 'Details'),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
