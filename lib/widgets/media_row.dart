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
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleLarge?.copyWith(fontSize: 20)),
            if (subtitle != null) Text(subtitle!, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          ]),
        ),
        ?trailing,
      ]),
    );
  }
}

/// Titled horizontal carousel. On wide screens it shows paging arrows,
/// since horizontal scrolling with a mouse wheel is awkward.
class MediaRow extends StatefulWidget {
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
  State<MediaRow> createState() => _MediaRowState();
}

class _MediaRowState extends State<MediaRow> {
  final _controller = ScrollController();
  bool _hover = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _page(int dir) {
    final viewport = _controller.position.viewportDimension;
    _controller.animateTo(
      (_controller.offset + dir * viewport * 0.85).clamp(0, _controller.position.maxScrollExtent),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return const SizedBox.shrink();
    final pad = context.pagePadding;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader(widget.title, subtitle: widget.subtitle, trailing: widget.trailing),
        MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: SizedBox(
            height: widget.height,
            child: Stack(children: [
              ListView.separated(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: pad, vertical: 6),
                clipBehavior: Clip.none,
                itemCount: widget.itemCount,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (c, i) => SizedBox(width: widget.itemWidth, child: widget.itemBuilder(c, i)),
              ),
              if (context.isWide) ...[
                _Arrow(left: true, visible: _hover, onTap: () => _page(-1)),
                _Arrow(left: false, visible: _hover, onTap: () => _page(1)),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.left, required this.visible, required this.onTap});
  final bool left;
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Positioned(
        left: left ? 4 : null,
        right: left ? null : 4,
        top: 0,
        bottom: 40,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: IgnorePointer(
            ignoring: !visible,
            child: Center(
              child: Material(
                color: Colors.black.withValues(alpha: 0.7),
                shape: const CircleBorder(side: BorderSide(color: Colors.white24)),
                child: IconButton(
                  onPressed: onTap,
                  icon: Icon(left ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, size: 28),
                ),
              ),
            ),
          ),
        ),
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
            itemBuilder: (_, _) => Skeleton(width: itemWidth, radius: 14),
          ),
        ),
      ]),
    );
  }
}
