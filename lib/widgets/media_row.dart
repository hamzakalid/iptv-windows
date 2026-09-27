import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'common.dart';
import 'nocturne.dart';

/// h5 row title with an optional muted note and trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 0, pad, 10),
      child: Row(children: [
        Flexible(child: Text(title, style: NocText.h5, maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 10),
        Expanded(
          child: subtitle == null
              ? const SizedBox.shrink()
              : Text(subtitle!,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.n600)),
        ),
        ?trailing,
      ]),
    );
  }
}

/// Ghost "See all" action.
class SeeAllButton extends StatelessWidget {
  const SeeAllButton({super.key, required this.onTap, this.label = 'See all'});
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) => NocButton.ghost(label: label, onPressed: onTap);
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
    final pad = widget.padding ?? EdgeInsets.fromLTRB(context.pagePadding, 4, context.pagePadding, 6);
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
        left: left ? 8 : null,
        right: left ? null : 8,
        top: 0,
        bottom: inset,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: IgnorePointer(
            ignoring: !visible,
            child: Center(
              child: Tooltip(
                message: left ? 'Previous' : 'Next',
                child: Tappable(
                  onTap: onTap,
                  radius: 18,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.94),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.n700),
                      boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4))],
                    ),
                    child: Icon(left ? Ph.caretLeft : Ph.caretRight, size: 18, color: AppColors.text),
                  ),
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
      padding: const EdgeInsets.only(bottom: 22),
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
        height: 44,
        separator: 6,
        itemCount: labels.length,
        padding: EdgeInsets.symmetric(horizontal: context.pagePadding, vertical: 6),
        itemBuilder: (_, i) => Center(child: Pill(labels[i], selected: i == selected, onTap: () => onSelect(i))),
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
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: EdgeInsets.fromLTRB(pad, 0, pad, 12), child: const Skeleton(width: 160, height: 18)),
        SizedBox(
          height: itemWidth / aspect,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: pad),
            itemCount: 8,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, _) => Skeleton(width: itemWidth, radius: Radii.md),
          ),
        ),
      ]),
    );
  }
}
