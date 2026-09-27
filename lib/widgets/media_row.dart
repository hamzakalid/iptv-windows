import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'common.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(context.pagePadding, 0, context.pagePadding, 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleLarge?.copyWith(fontSize: 19)),
            if (subtitle != null) Text(subtitle!, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          ]),
        ),
        ?trailing,
      ]),
    );
  }
}

class SeeAllButton extends StatelessWidget {
  const SeeAllButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Text('See all'),
          Icon(Icons.chevron_right_rounded, size: 18),
        ]),
      );
}

/// Horizontal list that pages with arrow buttons on wide screens.
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
    final pad = widget.padding ?? EdgeInsets.symmetric(horizontal: context.pagePadding, vertical: 6);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: SizedBox(
        height: widget.height,
        child: Stack(children: [
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

class _Arrow extends StatelessWidget {
  const _Arrow({required this.left, required this.visible, required this.onTap, required this.inset});
  final bool left;
  final bool visible;
  final double inset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Positioned(
        left: left ? 4 : null,
        right: left ? null : 4,
        top: 0,
        bottom: inset,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: IgnorePointer(
            ignoring: !visible,
            child: Center(
              child: Material(
                color: AppColors.surfaceHigh.withValues(alpha: 0.92),
                shape: const CircleBorder(side: BorderSide(color: AppColors.outline)),
                child: IconButton(
                  onPressed: onTap,
                  icon: Icon(left ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, size: 26),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Titled horizontal carousel of cards.
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
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final int itemCount;
  final double itemWidth;
  final double height;
  final Widget Function(BuildContext, int) itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader(title, subtitle: subtitle, trailing: trailing),
        ArrowScroller(
          height: height,
          itemCount: itemCount,
          arrowInset: 44,
          itemBuilder: (c, i) => SizedBox(width: itemWidth, child: itemBuilder(c, i)),
        ),
      ]),
    );
  }
}

/// A scrollable row of selectable pills (genres, categories, scopes).
class ChipStrip extends StatelessWidget {
  const ChipStrip({super.key, required this.labels, required this.selected, required this.onSelect, this.leading});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => ArrowScroller(
        height: 48,
        separator: 8,
        itemCount: labels.length,
        padding: EdgeInsets.symmetric(horizontal: context.pagePadding, vertical: 6),
        itemBuilder: (_, i) => Pill(labels[i], selected: i == selected, onTap: () => onSelect(i)),
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
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: EdgeInsets.fromLTRB(pad, 0, pad, 14), child: const Skeleton(width: 180, height: 22)),
        SizedBox(
          height: itemWidth / aspect,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: pad),
            itemCount: 8,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, _) => Skeleton(width: itemWidth, radius: Radii.card),
          ),
        ),
      ]),
    );
  }
}
