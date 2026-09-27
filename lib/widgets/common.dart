import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'nocturne.dart';

/// Network image with a Nocturne placeholder and a monogram fallback.
class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover, this.label, this.memCacheWidth, this.fontSize = 20});

  final String? url;
  final BoxFit fit;
  final String? label;
  final int? memCacheWidth;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final fallback = ArtPlaceholder(label: label, fontSize: fontSize);
    if (url == null || !url!.startsWith('http')) return fallback;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      memCacheWidth: memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, _) => const ArtPlaceholder(child: SizedBox.shrink()),
      errorWidget: (_, _, _) => fallback,
    );
  }
}

/// Pulsing box used while content loads.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height, this.radius = Radii.md});
  final double? width;
  final double? height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.n900,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}

/// The primary call to action — in Nocturne an accent outline, not a fill.
/// Kept under its old name so existing call sites keep working.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, this.icon, this.onPressed, this.loading = false});

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.accent),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 1.5)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w500)),
        ]),
      );
    }
    return NocButton.primary(label: label, icon: icon, onPressed: onPressed, height: 38);
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.n800),
                  color: AppColors.n900,
                ),
                child: Icon(icon, size: 28, color: AppColors.n500),
              ),
              const SizedBox(height: 18),
              Text(title, style: NocText.h5, textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(message!,
                    style: TextStyle(fontSize: 13.5, color: AppColors.muted, height: 1.5), textAlign: TextAlign.center),
              ],
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Ph.cloudSlash,
        title: 'Something went wrong',
        message: error.toString(),
        action: onRetry == null
            ? null
            : NocButton(label: 'Try again', icon: Ph.arrowClockwise, onPressed: onRetry),
      );
}

class RatingBadge extends StatelessWidget {
  const RatingBadge(this.rating, {super.key});
  final double rating;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.bg.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: StarRating(rating, size: 11),
      );
}

class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key});

  @override
  Widget build(BuildContext context) => const NocTag('LIVE', kind: TagKind.accent);
}

class MetaChip extends StatelessWidget {
  const MetaChip(this.label, {super.key, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => NocTag(label, icon: icon);
}

/// Card wrapper that shows the Nocturne hover ring (and optionally an
/// overlay) on desktop.
class Hoverable extends StatefulWidget {
  const Hoverable({super.key, required this.child, required this.onTap, this.radius = Radii.md, this.overlay});
  final Widget child;
  final VoidCallback onTap;
  final double radius;

  /// Drawn on top of [child] while hovered; fades in and out.
  final Widget? overlay;

  @override
  State<Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<Hoverable> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: _hover ? Shadows.hoverRing : const [],
          ),
          child: widget.overlay == null
              ? widget.child
              : Stack(fit: StackFit.passthrough, children: [
                  widget.child,
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !_hover,
                      child: AnimatedOpacity(
                        opacity: _hover ? 1 : 0,
                        duration: const Duration(milliseconds: 160),
                        child: widget.overlay,
                      ),
                    ),
                  ),
                ]),
        ),
      ),
    );
  }
}

/// Genre / filter pill: divider outline; selected gets an accent outline,
/// a faint accent tint and accent-300 text.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.selected = false, this.onTap, this.icon, this.compact = false});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.a300 : AppColors.n300;
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 4 : 5),
      decoration: BoxDecoration(
        color: selected ? AppColors.accentTint : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: selected ? AppColors.accent : AppColors.divider),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 6)],
        Text(label, style: TextStyle(fontSize: compact ? 12.5 : 13, color: fg, height: 1.4)),
      ]),
    );
    if (onTap == null) return child;
    return Tappable(onTap: onTap, child: child);
  }
}

/// Small translucent icon button used over artwork (bookmark on posters).
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, required this.onTap, this.size = 30, this.color, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final b = Tappable(
      onTap: onTap,
      hover: AppColors.bg.withValues(alpha: 0.3),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.bg.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Icon(icon, size: size * 0.5, color: color ?? AppColors.n300),
      ),
    );
    return tooltip == null ? b : Tooltip(message: tooltip!, child: b);
  }
}

/// Filled star + rating in accent-300, e.g. "★ 7.1".
class StarRating extends StatelessWidget {
  const StarRating(this.rating, {super.key, this.size = 12});
  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(PhF.star, size: size + 1, color: AppColors.a300),
        const SizedBox(width: 3),
        Text(rating.toStringAsFixed(1), style: TextStyle(fontSize: size, color: AppColors.a300)),
      ]);
}
