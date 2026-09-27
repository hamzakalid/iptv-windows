import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Network image with a branded placeholder and a monogram fallback.
class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover, this.label, this.memCacheWidth});

  final String? url;
  final BoxFit fit;
  final String? label;
  final int? memCacheWidth;

  @override
  Widget build(BuildContext context) {
    final fallback = _Fallback(label: label);
    if (url == null || !url!.startsWith('http')) return fallback;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      memCacheWidth: memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, _) => const ColoredBox(color: AppColors.surfaceHigh),
      errorWidget: (_, _, _) => fallback,
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    final initials = (label ?? '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && RegExp(r'^[\p{L}\p{N}]', unicode: true).hasMatch(w))
        .take(2)
        .map((w) => w.characters.first.toUpperCase())
        .join();
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF221A3D), Color(0xFF2D1530)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials.isEmpty ? '•' : initials,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white54),
        ),
      ),
    );
  }
}

/// Pulsing grey box used while content loads.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height, this.radius = 12});
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
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}

class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, this.icon, this.onPressed, this.loading = false});

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  else if (icon != null)
                    Icon(icon, color: Colors.white, size: 22),
                  if (loading || icon != null) const SizedBox(width: 10),
                  Text(label,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [
                    AppColors.primary.withValues(alpha: 0.25),
                    AppColors.accent.withValues(alpha: 0.15),
                  ]),
                ),
                child: Icon(icon, size: 40, color: AppColors.text),
              ),
              const SizedBox(height: 20),
              Text(title, style: t.titleLarge, textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(message!, style: t.bodyMedium?.copyWith(color: AppColors.textMuted), textAlign: TextAlign.center),
              ],
              if (action != null) ...[const SizedBox(height: 24), action!],
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
        icon: Icons.cloud_off_rounded,
        title: 'Something went wrong',
        message: error.toString(),
        action: onRetry == null
            ? null
            : OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again')),
      );
}

class RatingBadge extends StatelessWidget {
  const RatingBadge(this.rating, {super.key});
  final double rating;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFACC15)),
          const SizedBox(width: 2),
          Text(rating.toStringAsFixed(1),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      );
}

class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: AppColors.live, borderRadius: BorderRadius.circular(6)),
        child: const Text('LIVE',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Colors.white)),
      );
}

class MetaChip extends StatelessWidget {
  const MetaChip(this.label, {super.key, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: AppColors.textMuted), const SizedBox(width: 4)],
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
        ]),
      );
}

/// Adds a subtle lift + glow when hovered (desktop) and a press scale.
class Hoverable extends StatefulWidget {
  const Hoverable({super.key, required this.child, required this.onTap, this.radius = 14});
  final Widget child;
  final VoidCallback onTap;
  final double radius;

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
        child: AnimatedScale(
          scale: _hover ? 1.04 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              boxShadow: _hover
                  ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 1)]
                  : const [],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
