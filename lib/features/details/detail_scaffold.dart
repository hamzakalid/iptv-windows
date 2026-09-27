import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/media.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/media_cards.dart';
import '../../widgets/media_row.dart';

/// Cinematic layout shared by movie and series pages: blurred backdrop,
/// poster + title block, then arbitrary sections underneath.
class DetailScaffold extends StatelessWidget {
  const DetailScaffold({
    super.key,
    required this.item,
    required this.meta,
    required this.actions,
    required this.sections,
    this.loading = false,
  });

  final MediaItem item;
  final List<Widget> meta;
  final List<Widget> actions;
  final List<Widget> sections;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = context.isWide;
    final pad = context.pagePadding;
    final heroHeight = wide ? 520.0 : 300.0;

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(item.name, style: (wide ? t.displaySmall : t.headlineMedium)?.copyWith(height: 1.1)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: meta),
        const SizedBox(height: 20),
        Wrap(spacing: 12, runSpacing: 12, children: actions),
      ],
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(6),
          child: IconButton.filledTonal(
            style: IconButton.styleFrom(backgroundColor: Colors.black45),
            onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
      ),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Stack(children: [
            SizedBox(
              height: heroHeight,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                // Posters used as backdrops are blurred; clip so the blur
                // doesn't bleed past the hero's bottom edge.
                ClipRect(
                  child: ImageFiltered(
                    imageFilter:
                        item.backdrop == item.logo ? ImageFilter.blur(sigmaX: 18, sigmaY: 18) : ImageFilter.blur(),
                    child: NetImage(item.backdrop, label: item.name),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66000000), Color(0x9909090F), AppColors.bg],
                      stops: [0, 0.6, 1],
                    ),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(pad, wide ? 200 : 140, pad, 0),
              child: wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      _Poster(item: item, width: 220),
                      const SizedBox(width: 32),
                      Expanded(child: titleBlock),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _Poster(item: item, width: 130),
                      const SizedBox(height: 18),
                      titleBlock,
                    ]),
            ),
          ]),
        ),
        if (loading)
          const SliverToBoxAdapter(
            child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
          ),
        SliverList.list(children: [const SizedBox(height: 28), ...sections, const SizedBox(height: 32)]),
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 12))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(aspectRatio: 2 / 3, child: NetImage(item.logo, label: item.name)),
        ),
      );
}

class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(favoritesProvider);
    final saved = ref.read(favoritesProvider.notifier).contains(item.id);
    return OutlinedButton.icon(
      onPressed: () async {
        try {
          await ref.read(favoritesProvider.notifier).toggle(item);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update My List: $e')));
          }
        }
      },
      icon: Icon(saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: saved ? AppColors.accent : null),
      label: Text(saved ? 'In My List' : 'My List'),
    );
  }
}

/// Paragraph section with a heading and optional expand toggle.
class TextSection extends StatefulWidget {
  const TextSection({super.key, required this.title, required this.text, this.footer});
  final String title;
  final String text;
  final Widget? footer;

  @override
  State<TextSection> createState() => _TextSectionState();
}

class _TextSectionState extends State<TextSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader(widget.title),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  widget.text,
                  maxLines: _expanded ? null : 4,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                  style: t.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.82), height: 1.6),
                ),
              ),
              if (widget.footer != null) ...[const SizedBox(height: 14), widget.footer!],
            ]),
          ),
        ),
      ]),
    );
  }
}

class CastRow extends StatelessWidget {
  const CastRow({super.key, required this.actors});
  final List<Actor> actors;

  @override
  Widget build(BuildContext context) => MediaRow(
        title: 'Cast',
        itemCount: actors.length,
        itemWidth: 96,
        height: 150,
        itemBuilder: (context, i) {
          final a = actors[i];
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: a.id == null ? null : () => context.push('/actor/${a.id}'),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
                child: ClipOval(child: SizedBox.square(dimension: 84, child: NetImage(a.profileUrl, label: a.name))),
              ),
              const SizedBox(height: 8),
              Text(a.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
            ]),
          );
        },
      );
}

class SimilarRow extends ConsumerWidget {
  const SimilarRow({super.key, required this.kind, required this.id});
  final MediaKind kind;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(similarProvider((kind: kind, id: id))).value ?? const [];
    final w = context.isWide ? 160.0 : 124.0;
    return MediaRow(
      title: 'More like this',
      itemCount: items.length,
      itemWidth: w,
      height: w * 1.5 + 50,
      itemBuilder: (_, i) => PosterCard(item: items[i]),
    );
  }
}
