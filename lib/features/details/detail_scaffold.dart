import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../models/media.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/media_cards.dart';
import '../../widgets/media_row.dart';

/// Horizontal inset for detail pages.
double detailPad(BuildContext context) => context.isWide ? 32 : 16;

/// Height of every action button on a detail page.
const detailButtonSize = Size(0, 38);

/// Layout shared by movie and series pages: a soft backdrop band, the
/// poster overlapping it beside the title block, then sections.
class DetailScaffold extends StatelessWidget {
  const DetailScaffold({
    super.key,
    required this.item,
    required this.kindLabel,
    required this.meta,
    required this.actions,
    required this.sections,
    this.progress,
    this.footnote,
    this.loading = false,
  });

  final MediaItem item;

  /// Year, length and genre tags; rating is added automatically.
  final List<Widget> meta;
  final String? plot;

  /// 0–1 when partially watched; shows the progress row.
  final double? progress;
  final String? progressLabel;
  final List<Widget> actions;
  final List<Widget> sections;

  /// Resume bar shown above the actions.
  final Widget? progress;

  /// Small print under the plot (e.g. the director).
  final Widget? footnote;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    final pad = detailPad(context);
    final band = wide ? 300.0 : 220.0;
    final overlap = wide ? 190.0 : 120.0;

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(item.kind.label.toUpperCase(), style: AppText.kicker),
        const SizedBox(height: 10),
        Text(item.name, style: wide ? AppText.h2 : AppText.h3),
        const SizedBox(height: 10),
        DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 13, color: AppColors.neutral300),
          child: Wrap(spacing: 12, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (item.rating != null && item.rating! > 0) StarRating(item.rating!),
            ...meta,
          ]),
        ),
        if (item.plot != null) ...[
          const SizedBox(height: 10),
          _Plot(item.plot!),
        ],
        if (footnote != null) ...[const SizedBox(height: 8), footnote!],
        if (progress != null) ...[const SizedBox(height: 12), progress!],
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: actions),
      ],
    );

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Stack(children: [
            SizedBox(
              height: band,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.4, -1),
                      radius: 1.3,
                      colors: [AppColors.neutral800, AppColors.neutral900, AppColors.bg],
                      stops: [0, 0.55, 1],
                    ),
                  ),
                ),
                if (item.backdrop != item.logo) NetImage(item.backdrop, labelSize: 0, lighten: true),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.bg.withValues(alpha: 0.2), AppColors.bg],
                    ),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(pad, band - overlap, pad, 0),
              child: wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      _Poster(item: item, width: 210),
                      const SizedBox(width: 28),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: titleBlock),
                        ),
                      ),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _Poster(item: item, width: 120),
                      const SizedBox(height: 18),
                      titleBlock,
                    ]),
            ),
            Positioned(
              top: 16,
              left: wide ? 24 : 12,
              child: SafeArea(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.bg.withValues(alpha: 0.6),
                    minimumSize: const Size(0, 34),
                  ),
                  onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                  icon: const Icon(PhosphorIconsRegular.arrowLeft),
                  label: const Text('Back'),
                ),
              ),
            ),
          ]),
        ),
        if (loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          ),
        SliverList.list(children: [...sections, const SizedBox(height: 40)]),
      ]),
    );
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
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.md), boxShadow: Shadows.md),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.md),
          child: AspectRatio(aspectRatio: 2 / 3, child: NetImage(item.logo, label: item.name, labelSize: 26)),
        ),
      );
}

class _Plot extends StatefulWidget {
  const _Plot(this.text);
  final String text;

  @override
  State<_Plot> createState() => _PlotState();
}

class _PlotState extends State<_Plot> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => setState(() => _open = !_open),
        child: Text(
          widget.text,
          maxLines: _open ? null : 4,
          overflow: _open ? null : TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, height: 1.55, color: AppColors.neutral300),
        ),
      );
}

/// Resume bar with a label, capped at 360px.
class ResumeBar extends StatelessWidget {
  const ResumeBar({super.key, required this.value, required this.label});
  final double value;
  final String label;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Row(children: [
          Expanded(child: ThinProgress(value, height: 3)),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.neutral400)),
        ]),
      );
}

/// "My List" / "In My List" toggle.
class MyListButton extends ConsumerWidget {
  const MyListButton({super.key, required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(favoritesProvider);
    final saved = ref.read(favoritesProvider.notifier).contains(item.id);
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: detailButtonSize),
      onPressed: () => toggleSaved(context, ref, item),
      icon: Icon(saved ? PhosphorIconsFill.bookmarkSimple : PhosphorIconsRegular.bookmarkSimple,
          color: saved ? AppColors.accent : null),
      label: Text(saved ? 'In My List' : 'My List'),
    );
  }
}

/// Section title on a detail page.
class DetailHeading extends StatelessWidget {
  const DetailHeading(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(detailPad(context), 32, detailPad(context), 12),
        child: Row(children: [
          Text(title, style: AppText.h5),
          if (trailing != null) ...[const SizedBox(width: 14), Flexible(child: trailing!)],
        ]),
      );
}

/// Row of 72px actor circles (photo or initials) with the name underneath.
class CastRow extends StatelessWidget {
  const CastRow({super.key, required this.actors});
  final List<Actor> actors;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const DetailHeading('Cast'),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: detailPad(context)),
            itemCount: actors.length,
            separatorBuilder: (_, _) => const SizedBox(width: 18),
            itemBuilder: (context, i) {
              final a = actors[i];
              return SizedBox(
                width: 84,
                child: Hoverable(
                  radius: 36,
                  ring: const [],
                  onTap: a.id == null ? null : () => context.push('/actor/${a.id}'),
                  child: Column(children: [
                    Container(
                      width: 72,
                      height: 72,
                      clipBehavior: Clip.antiAlias,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.neutral900,
                        boxShadow: Shadows.sm,
                      ),
                      child: a.profileUrl == null
                          ? Center(
                              child: Text(initials(a.name),
                                  style: const TextStyle(fontSize: 13, color: AppColors.neutral500)),
                            )
                          : NetImage(a.profileUrl, label: a.name, labelSize: 13, memCacheWidth: 200),
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

class SimilarRow extends ConsumerWidget {
  const SimilarRow({super.key, required this.kind, required this.id});
  final MediaKind kind;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(similarProvider((kind: kind, id: id))).value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    final w = context.isWide ? 150.0 : 116.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const DetailHeading('More like this'),
      ArrowScroller(
        height: w * 1.5 + posterCaptionHeight + 8,
        itemCount: items.length,
        arrowInset: 44,
        padding: EdgeInsets.fromLTRB(detailPad(context), 2, detailPad(context), 6),
        itemBuilder: (_, i) => SizedBox(width: w, child: PosterCard(item: items[i])),
      ),
    ]);
  }
}
