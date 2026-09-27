import 'package:flutter/material.dart';

import '../core/icons.dart';
import '../core/theme.dart';
import 'common.dart';
import 'nocturne.dart';

/// Flush-left h5 with an optional muted note and a ghost action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.trailing, this.padding});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    final pad = context.pagePadding;
    return Padding(
      padding: padding ?? EdgeInsets.fromLTRB(pad, 0, pad - 8, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Row(children: [
            Flexible(child: Text(title, style: AppText.h5, maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (subtitle != null) ...[
              const SizedBox(width: 10),
              Flexible(
                child: Text(subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.neutral600)),
              ),
            ],
          ]),
        ),
        ?trailing,
      ]),
    );
  }
}

/// Ghost "See all" / "History" / "Guide" link at the end of a row header.
class RowAction extends StatelessWidget {
  const RowAction(this.label, {super.key, required this.onTap});
  final String label;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        child: Text(label),
      );
}

/// Horizontal list that pages with Nocturne arrow buttons on wide screens.
class ArrowScroller extends StatefulWidget {
  const ArrowScroller({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.separator = 14,
    this.padding,
    this.arrowInset = 0,
  });

  final double height;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double separator;
  final EdgeInsets? padding;

  /// Space at the bottom the arrows ignore (e.g. the title under posters),
  /// so they centre on the artwork.
  final double arrowInset;

  @override
  State<ArrowScroller> createState() => _ArrowScrollerState();
}

class _ArrowScrollerState extends State<ArrowScroller> {
  final _controller = ScrollController();
  bool _hover = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _page(int dir) {
    if (!_controller.hasClients) return;
    final viewport = _controller.position.viewportDimension;
    _controller.animateTo(
      (_controller.offset + dir * viewport * 0.8).clamp(0, _controller.position.maxScrollExtent),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.padding ?? EdgeInsets.fromLTRB(context.pagePadding, 2, context.pagePadding, 6);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: SizedBox(
        height: widget.height,
        child: Stack(clipBehavior: Clip.none, children: [
          ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: pad,
            clipBehavior: Clip.none,
            itemCount: widget.itemCount,
            separatorBuilder: (_, _) => SizedBox(width: widget.separator),
            itemBuilder: widget.itemBuilder,
          ),
          if (context.hasMouse) ...[
            _Arrow(left: true, visible: _hover, inset: widget.arrowInset, onTap: () => _page(-1)),
            _Arrow(left: false, visible: _hover, inset: widget.arrowInset, onTap: () => _page(1)),
          ],
        ]),
      ),
    );
  }
}

/// Surface circle with an n700 hairline and a Phosphor caret.
class _Arrow extends StatelessWidget {
  const _Arrow({required this.left, required this.visible, required this.onTap, required this.inset});
  final bool left;
  final bool visible;
  final double inset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Positioned(
        left: left ? 6 : null,
        right: left ? null : 6,
        top: 0,
        bottom: inset,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: IgnorePointer(
            ignoring: !visible,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(Radii.md),
                  boxShadow: Shadows.md,
                ),
                child: IconButton(
                  tooltip: left ? 'Previous' : 'Next',
                  onPressed: onTap,
                  icon: Icon(left ? PhosphorIconsRegular.caretLeft : PhosphorIconsRegular.caretRight, size: 18),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Titled horizontal row of cards.
class MediaRow extends StatelessWidget {
  const MediaRow({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    required this.itemWidth,
    required this.height,
    this.subtitle,
    this.trailing,
    this.arrowInset = 44,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final int itemCount;
  final double itemWidth;
  final double height;
  final double arrowInset;
  final Widget Function(BuildContext, int) itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader(title, subtitle: subtitle, trailing: trailing),
        ArrowScroller(
          height: height,
          itemCount: itemCount,
          arrowInset: arrowInset,
          itemBuilder: (c, i) => SizedBox(width: itemWidth, child: itemBuilder(c, i)),
        ),
      ]),
    );
  }
}

/// A scrollable row of bordered filter chips (genres, categories).
class ChipStrip extends StatelessWidget {
  const ChipStrip({super.key, required this.labels, required this.selected, required this.onSelect, this.padding});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => ArrowScroller(
        height: 40,
        separator: 6,
        itemCount: labels.length,
        padding: padding ?? EdgeInsets.symmetric(horizontal: context.pagePadding, vertical: 4),
        itemBuilder: (_, i) => Center(child: FilterPill(labels[i], selected: i == selected, onTap: () => onSelect(i))),
      );
}

/// Placeholder row shown while a section loads.
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key, this.itemWidth = 150, this.aspect = 2 / 3});
  final double itemWidth;
  final double aspect;

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: EdgeInsets.fromLTRB(pad, 0, pad, 12), child: const Skeleton(width: 160, height: 18, radius: Radii.sm)),
        SizedBox(
          height: itemWidth / aspect,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: pad),
            itemCount: 8,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, _) => Skeleton(width: itemWidth),
          ),
        ),
      ]),
    );
  }
}
