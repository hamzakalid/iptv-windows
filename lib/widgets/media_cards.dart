import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../models/account.dart';
import '../models/media.dart';
import '../features/player/player_screen.dart';
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

/// 2:3 poster with title underneath. Used for movies and series.
class PosterCard extends StatelessWidget {
  const PosterCard({super.key, required this.item, this.width});
  final MediaItem item;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Hoverable(
              onTap: () => openItem(context, item),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(fit: StackFit.expand, children: [
                  NetImage(item.logo, label: item.name, memCacheWidth: 400),
                  if (item.rating != null && item.rating! > 0)
                    Positioned(top: 8, left: 8, child: RatingBadge(item.rating!)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          Text(
            [if (item.year != null) '${item.year}', if (item.group.isNotEmpty) item.group].join(' • '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
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
              onTap: () => openItem(context, item),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1C1A2E), Color(0xFF13121C)],
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
        ],
      ),
    );
  }
}

/// Landscape card with a progress bar, for "Continue watching".
class ContinueCard extends StatelessWidget {
  const ContinueCard({super.key, required this.entry, this.width = 280});
  final ContinueItem entry;
  final double width;

  void _resume(BuildContext context) {
    final item = entry.item!;
    if (entry.kind == MediaKind.series) {
      // Episode URLs live on the series detail; open it and let the user pick.
      openItem(context, item);
      return;
    }
    PlayerScreen.open(context, PlayerArgs.movie(item, startAt: entry.positionSecs));
  }

  @override
  Widget build(BuildContext context) {
    final item = entry.item!;
    final t = Theme.of(context).textTheme;
    final subtitle = entry.kind == MediaKind.series && entry.season != null
        ? 'S${entry.season} · E${entry.episode ?? '?'}${entry.episodeTitle != null ? ' · ${entry.episodeTitle}' : ''}'
        : '${(entry.progressPct).round()}% watched';
    return SizedBox(
      width: width,
      child: Hoverable(
        onTap: () => _resume(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
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
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.45),
                    border: Border.all(color: Colors.white54),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                ),
              ),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (entry.progressPct / 100).clamp(0, 1),
                      minHeight: 4,
                      backgroundColor: Colors.white24,
                      color: AppColors.accent,
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
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
      ? ChannelCard(item: item, width: width)
      : PosterCard(item: item, width: width);
}
