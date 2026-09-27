import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../models/media.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/media_cards.dart';
import '../../widgets/media_row.dart';
import '../../widgets/nocturne.dart';

/// "1h 02m" / "48m", as in the design's `hm()`.
String hm(int secs) {
  final m = (secs / 60).round();
  final mm = '${m % 60}'.padLeft(2, '0');
  return m >= 60 ? '${m ~/ 60}h ${mm}m' : '${mm}m';
}

void goBack(BuildContext context) => context.canPop() ? context.pop() : context.go('/home');

/// Horizontal page gutter for the details layout: 32 on desktop.
double detailGutter(BuildContext context) => context.isWide ? 32 : 16;

/// Full-page shell with Esc-to-go-back; used by the details and actor pages
/// (also while they load or fail).
class DetailPage extends StatelessWidget {
  const DetailPage({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        body: CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => goBack(context)},
          child: Focus(autofocus: true, child: child),
        ),
      );
}

/// `btn-secondary` "Back" at 34px over a 60% ground.
class BackButtonChip extends StatelessWidget {
  const BackButtonChip({super.key});

  @override
  Widget build(BuildContext context) => NocButton(
        label: 'Back',
        icon: Ph.arrowLeft,
        height: 34,
        background: AppColors.bg.withValues(alpha: 0.6),
        onPressed: () => goBack(context),
      );
}

/// Page shown while there is nothing to render yet (no preview) or the load
/// failed.
class DetailPlaceholder extends StatelessWidget {
  const DetailPlaceholder({super.key, this.error, this.onRetry});
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => DetailPage(
        child: Stack(children: [
          Positioned.fill(
            child: error != null
                ? ErrorView(error: error!, onRetry: onRetry)
                : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          Positioned(top: 16, left: context.isWide ? 24 : 16, child: const BackButtonChip()),
        ]),
      );
}

/// Nocturne details layout shared by movies and series: a 300px backdrop band
/// faded into the ground, the poster + info block overlapping it, then
/// sections (episodes, cast, more like this) underneath.
class DetailScaffold extends StatelessWidget {
  const DetailScaffold({
    super.key,
    required this.item,
    required this.kindLabel,
    required this.meta,
    required this.actions,
    required this.sections,
    this.plot,
    this.progress,
    this.progressLabel,
    this.loading = false,
  });

  final MediaItem item;
  final String kindLabel;
  final List<Widget> meta;
  final String? plot;

  /// 0–1 when partially watched; shows the progress row.
  final double? progress;
  final String? progressLabel;
  final List<Widget> actions;
  final List<Widget> sections;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    final g = detailGutter(context);
    final bandHeight = wide ? 300.0 : 220.0;
    final overlap = wide ? 190.0 : 130.0;

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(kindLabel.toUpperCase(),
            style: const TextStyle(fontSize: 10, letterSpacing: 1, color: AppColors.accent, height: 1.4)),
        const SizedBox(height: 10),
        Text(item.name, style: wide ? NocText.h2 : NocText.h3),
        const SizedBox(height: 10),
        DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 13, color: AppColors.n300),
          child: Wrap(spacing: 12, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: meta),
        ),
        if (plot != null) ...[
          const SizedBox(height: 10),
          Text(plot!, style: const TextStyle(fontSize: 15, height: 1.55, color: AppColors.n300)),
        ],
        if (progress != null) ...[
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Row(children: [
              Expanded(child: ProgressLine(progress!, height: 3)),
              if (progressLabel != null) ...[
                const SizedBox(width: 10),
                Text(progressLabel!, style: const TextStyle(fontSize: 12, color: AppColors.n400)),
              ],
            ]),
          ),
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: actions),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: SizedBox(width: 120, child: LinearProgressIndicator(minHeight: 2)),
          ),
      ],
    );

    final block = LayoutBuilder(builder: (context, c) {
      final side = c.maxWidth >= 210 + 28 + 300;
      final poster = _Poster(item: item, width: side ? 210 : (wide ? 180 : 132));
      if (!side) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [poster, const SizedBox(height: 20), info],
        );
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        poster,
        const SizedBox(width: 28),
        Flexible(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: info)),
      ]);
    });

    return DetailPage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Stack(children: [
            Positioned(top: 0, left: 0, right: 0, height: bandHeight, child: _Backdrop(item: item)),
            Padding(padding: EdgeInsets.fromLTRB(g, bandHeight - overlap, g, 0), child: block),
            Positioned(top: 16, left: wide ? 24 : 16, child: const BackButtonChip()),
          ]),
          ...sections,
        ]),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final url = item.backdrop;
    final hasImage = url != null && url.startsWith('http');
    return Stack(fit: StackFit.expand, children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.4, -1),
            radius: 1.3,
            colors: [AppColors.n800, AppColors.n900, AppColors.bg],
            stops: [0, 0.55, 1],
          ),
        ),
      ),
      if (hasImage)
        ClipRect(
          // Posters standing in for a backdrop are blurred into a wash.
          child: ImageFiltered(
            imageFilter: url == item.logo ? ImageFilter.blur(sigmaX: 24, sigmaY: 24) : ImageFilter.blur(),
            child: Opacity(opacity: 0.55, child: NetImage(url, label: item.name)),
          ),
        ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bg.withValues(alpha: 0.2), AppColors.bg.withValues(alpha: 0.55), AppColors.bg],
            stops: const [0, 0.55, 1],
          ),
        ),
      ),
    ]);
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.item, required this.width});
  final MediaItem item;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.md), boxShadow: Shadows.md),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.md),
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: NetImage(item.logo, label: item.name, fontSize: 26, memCacheWidth: 500),
          ),
        ),
      );
}

/// Accent-300 "★ 7.4".
class RatingMeta extends StatelessWidget {
  const RatingMeta(this.rating, {super.key});
  final double rating;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(PhF.star, size: 13, color: AppColors.a300),
        const SizedBox(width: 4),
        Text(rating.toStringAsFixed(1), style: const TextStyle(color: AppColors.a300)),
      ]);
}

/// Shared meta row: rating, year, length, neutral genre tags.
List<Widget> detailMeta(MediaItem item, {String? length, List<String>? genres}) => [
      if (item.rating != null && item.rating! > 0) RatingMeta(item.rating!),
      if (item.year != null) Text('${item.year}'),
      if (length != null && length.isNotEmpty) Text(length),
      for (final g in (genres ?? item.genres).take(3)) NocTag(g),
    ];

/// Secondary My List / In My List toggle.
class SaveButton extends ConsumerWidget {
  const SaveButton({super.key, required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(favoritesProvider);
    final saved = ref.read(favoritesProvider.notifier).contains(item.id);
    return NocButton(
      label: saved ? 'In My List' : 'My List',
      icon: saved ? PhF.bookmarkSimple : Ph.bookmarkSimple,
      height: 38,
      onPressed: () => toggleSaved(context, ref, item),
    );
  }
}

/// Ghost "Trailer": opens the provider's trailer (URL or YouTube id).
class TrailerButton extends StatelessWidget {
  const TrailerButton({super.key, required this.trailer});
  final String trailer;

  @override
  Widget build(BuildContext context) => NocButton.ghost(
        label: 'Trailer',
        icon: Ph.filmReel,
        height: 38,
        fontSize: 14,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        onPressed: () => launchUrl(
          Uri.parse(trailer.startsWith('http') ? trailer : 'https://www.youtube.com/watch?v=$trailer'),
          mode: LaunchMode.externalApplication,
        ),
      );
}

/// h5 section heading at the details gutter (padding 32/32/12).
class DetailHeading extends StatelessWidget {
  const DetailHeading(this.title, {super.key, this.trailing, this.top = 32, this.bottom = 12});
  final String title;
  final Widget? trailing;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final g = detailGutter(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(g, top, g, bottom),
      child: Row(children: [
        Text(title, style: NocText.h5),
        if (trailing != null) ...[const SizedBox(width: 14), Flexible(child: trailing!)],
      ]),
    );
  }
}

/// Row of 72px actor circles (photo or initials) with the name underneath.
class CastRow extends StatelessWidget {
  const CastRow({super.key, required this.actors});
  final List<Actor> actors;

  @override
  Widget build(BuildContext context) {
    final g = detailGutter(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const DetailHeading('Cast'),
      SizedBox(
        height: 122,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.fromLTRB(g, 1, g, 4),
          itemCount: actors.length,
          separatorBuilder: (_, _) => const SizedBox(width: 18),
          itemBuilder: (context, i) {
            final a = actors[i];
            final photo = a.profileUrl != null && a.profileUrl!.startsWith('http');
            return Tappable(
              onTap: a.id == null ? null : () => context.push('/actor/${a.id}'),
              child: SizedBox(
                width: 84,
                child: Column(children: [
                  Container(
                    width: 72,
                    height: 72,
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.n900,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.n800, spreadRadius: 1)],
                    ),
                    child: photo
                        ? SizedBox.expand(child: NetImage(a.profileUrl, label: a.name, memCacheWidth: 200, fontSize: 13))
                        : Text(initials(a.name), style: const TextStyle(fontSize: 13, color: AppColors.n500)),
                  ),
                  const SizedBox(height: 6),
                  Text(a.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, height: 1.3)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

/// "More like this": a row of 150px PosterCards.
class SimilarRow extends ConsumerWidget {
  const SimilarRow({super.key, required this.kind, required this.id});
  final MediaKind kind;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(similarProvider((kind: kind, id: id))).value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    final g = detailGutter(context);
    final w = context.isWide ? 150.0 : 120.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const DetailHeading('More like this'),
      ArrowScroller(
        height: w * 1.5 + 56,
        padding: EdgeInsets.fromLTRB(g, 2, g, 6),
        arrowInset: 46,
        itemCount: items.length,
        itemBuilder: (_, i) => PosterCard(item: items[i], width: w),
      ),
    ]);
  }
}
