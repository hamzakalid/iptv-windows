import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/icons.dart';
import '../core/theme.dart';
import 'nocturne.dart';

/// Two-letter monogram for artwork fallbacks ("The Long Road" → "TL").
String initials(String? label) => (label ?? '')
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty && RegExp(r'^[\p{L}\p{N}]', unicode: true).hasMatch(w))
    .take(2)
    .map((w) => w.characters.first.toUpperCase())
    .join();

/// Network image with a Nocturne fallback: a soft neutral radial ground with
/// the title's initials. [lighten] blends the photo into the page ground so
/// its darkest values fall away (the system's `.lighten` treatment).
class NetImage extends StatelessWidget {
  const NetImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.label,
    this.labelSize = 20,
    this.memCacheWidth,
    this.lighten = false,
  });

  final String? url;
  final BoxFit fit;
  final String? label;
  final double labelSize;
  final int? memCacheWidth;
  final bool lighten;

  @override
  Widget build(BuildContext context) {
    final fallback = ArtFallback(label: label, labelSize: labelSize);
    if (url == null || !url!.startsWith('http')) return fallback;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      memCacheWidth: memCacheWidth,
      color: lighten ? AppColors.bg : null,
      colorBlendMode: lighten ? BlendMode.lighten : null,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, _) => const ColoredBox(color: AppColors.neutral900),
      errorWidget: (_, _, _) => fallback,
    );
  }
}

/// Placeholder art: neutral-800 fading to neutral-900 from the top-left.
class ArtFallback extends StatelessWidget {
  const ArtFallback({super.key, this.label, this.labelSize = 20});
  final String? label;
  final double labelSize;

  @override
  Widget build(BuildContext context) {
    final ini = initials(label);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.4, -0.7),
          radius: 1.1,
          colors: [AppColors.neutral800, AppColors.neutral900],
          stops: [0, 0.7],
        ),
      ),
      child: ini.isEmpty || labelSize <= 0
          ? const SizedBox.expand()
          : Center(
              child: Text(ini,
                  style: TextStyle(
                    fontSize: labelSize,
                    fontWeight: FontWeight.w500,
                    letterSpacing: labelSize * 0.04,
                    color: AppColors.neutral600,
                  )),
            ),
    );
  }
}

/// Small square tile for a channel logo (or its initials).
class LogoTile extends StatelessWidget {
  const LogoTile({super.key, required this.url, required this.label, this.width = 48, this.height = 48});
  final String? url;
  final String label;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: AppColors.neutral900, borderRadius: BorderRadius.circular(Radii.sm)),
        alignment: Alignment.center,
        child: url != null && url!.startsWith('http')
            ? Padding(
                padding: const EdgeInsets.all(5),
                child: NetImage(url, fit: BoxFit.contain, label: label, labelSize: 11, memCacheWidth: 160),
              )
            : Text(initials(label),
                style: TextStyle(fontSize: height < 36 ? 10.5 : 12, color: AppColors.neutral400)),
      );
}

/// Pulsing block shown while content loads.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height, this.radius = Radii.md});
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
        opacity: Tween(begin: 0.5, end: 1.0).animate(_c),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.neutral900,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 36, color: AppColors.neutral600),
              const SizedBox(height: 14),
              Text(title, style: AppText.h5, textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(message!,
                    style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted, height: 1.5),
                    textAlign: TextAlign.center),
              ],
              if (action != null) ...[const SizedBox(height: 20), action!],
            ]),
          ),
        ),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: PhosphorIconsRegular.cloudX,
        title: 'Something went wrong',
        message: error.toString(),
        action: onRetry == null
            ? null
            : OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(PhosphorIconsRegular.arrowClockwise),
                label: const Text('Try again'),
              ),
      );
}

enum TagTone { accent, neutral, outline }

/// Small label tinted from the ramps.
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.tone = TagTone.neutral, this.icon, this.leading});
  final String label;
  final TagTone tone;
  final IconData? icon;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      TagTone.accent => (AppColors.accent800, AppColors.accent100),
      TagTone.neutral => (AppColors.neutral800, AppColors.neutral100),
      TagTone.outline => (Colors.transparent, AppColors.accent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.md * 0.75),
        border: tone == TagTone.outline ? Border.all(color: AppColors.accent) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (leading != null) ...[leading!, const SizedBox(width: 5)],
        if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
        Text(label, style: TextStyle(fontSize: 11, letterSpacing: 0.22, color: fg, height: 1.3)),
      ]),
    );
  }
}

/// Uppercase section label ("GENRES").
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.padding = EdgeInsets.zero});
  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: padding, child: Text(text.toUpperCase(), style: AppText.eyebrow));
}

/// Keyboard hint ("/", "C", "Esc").
class Kbd extends StatelessWidget {
  const Kbd(this.label, {super.key, this.minWidth = 0});
  final String label;
  final double minWidth;

  @override
  Widget build(BuildContext context) => Container(
        constraints: BoxConstraints(minWidth: minWidth),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, height: 16 / 11, color: AppColors.neutral500)),
      );
}

/// Hairline progress: a 2–3px track with an accent fill.
class ThinProgress extends StatelessWidget {
  const ThinProgress(this.value, {super.key, this.height = 2, this.track = AppColors.neutral800, this.color = AppColors.accent, this.rounded = true});
  final double value;
  final double height;
  final Color track;
  final Color color;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(rounded ? height : 0);
    return Container(
      height: height,
      decoration: BoxDecoration(color: track, borderRadius: r),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(decoration: BoxDecoration(color: color, borderRadius: r)),
      ),
    );
  }
}

/// A progress strip pinned to the bottom edge of artwork.
class ArtProgress extends StatelessWidget {
  const ArtProgress(this.value, {super.key});
  final double value;

  @override
  Widget build(BuildContext context) => Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: ThinProgress(value, height: 3, track: AppColors.wash(0.12), rounded: false),
      );
}

/// Accent star + rating, e.g. "★ 7.1".
class StarRating extends StatelessWidget {
  const StarRating(this.rating, {super.key, this.size = 13});
  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(PhosphorIconsFill.star, size: size, color: AppColors.accent300),
        SizedBox(width: size * 0.3),
        Text(rating.toStringAsFixed(1), style: TextStyle(fontSize: size, color: AppColors.accent300)),
      ]);
}

/// Circular monogram in the accent ramp.
class Avatar extends StatelessWidget {
  const Avatar(this.label, {super.key, this.size = 30});
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: AppColors.accent800, shape: BoxShape.circle),
        child: Text(label.isEmpty ? '?' : label.characters.first.toUpperCase(),
            style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w500, color: AppColors.accent100)),
      );
}

/// Pointer + keyboard affordance for cards: the accent ring (and ambient
/// shade) on hover or keyboard focus; Enter/Space activate.
class Hoverable extends StatefulWidget {
  const Hoverable({
    super.key,
    required this.child,
    required this.onTap,
    this.radius = Radii.md,
    this.ring = Shadows.ring,
    this.color,
    this.hoverColor,
    this.tooltip,
  });
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final List<BoxShadow> ring;

  /// Resting fill (e.g. a surface card); null for none.
  final Color? color;

  /// Fill while hovered, for row-style items that tint instead of ringing.
  final Color? hoverColor;
  final String? tooltip;

  @override
  State<Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<Hoverable> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final on = _hover || _focus;
    final tints = widget.hoverColor != null;
    Widget child = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      decoration: BoxDecoration(
        color: on && tints ? widget.hoverColor : widget.color,
        borderRadius: BorderRadius.circular(widget.radius),
        boxShadow: on && (!tints || _focus) ? widget.ring : const [],
      ),
      child: widget.child,
    );
    if (widget.tooltip != null) child = Tooltip(message: widget.tooltip!, child: child);
    return FocusableActionDetector(
      enabled: widget.onTap != null,
      mouseCursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onTap?.call();
          return null;
        }),
      },
      child: GestureDetector(onTap: widget.onTap, behavior: HitTestBehavior.opaque, child: child),
    );
  }
}

/// One option in a [SegmentedControl].
class Segment<T> {
  const Segment(this.value, this.label, {this.icon, this.trailing});
  final T value;
  final String label;
  final IconData? icon;

  /// Muted suffix such as a result count.
  final String? trailing;
}

/// Joined options inside one divider outline; the selected one takes the
/// accent colour and an inset accent hairline.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.expand = false,
    this.dense = false,
  });
  final List<Segment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Share the available width equally (e.g. playback speed).
  final bool expand;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      final on = s.value == selected;
      final button = _SegmentButton(
        segment: s,
        selected: on,
        dense: dense,
        tight: expand,
        divided: i > 0,
        onTap: () => onChanged(s.value),
      );
      items.add(expand ? Expanded(child: button) : button);
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, children: items),
      ),
    );
  }
}

class _SegmentButton<T> extends StatefulWidget {
  const _SegmentButton({
    required this.segment,
    required this.selected,
    required this.dense,
    required this.tight,
    required this.divided,
    required this.onTap,
  });
  final Segment<T> segment;
  final bool selected;
  final bool dense;

  /// Shares a fixed width with its siblings, so keeps its side padding small.
  final bool tight;
  final bool divided;
  final VoidCallback onTap;

  @override
  State<_SegmentButton<T>> createState() => _SegmentButtonState<T>();
}

class _SegmentButtonState<T> extends State<_SegmentButton<T>> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.segment;
    final fg = widget.selected ? AppColors.accent : AppColors.neutral400;
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onTap();
          return null;
        }),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            border: widget.divided ? const Border(left: BorderSide(color: AppColors.divider)) : null,
          ),
          child: Container(
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(
              horizontal: widget.tight ? 2 : (widget.dense ? 10 : 12),
              vertical: widget.dense ? 6 : 8,
            ),
            color: _hover && !widget.selected ? AppColors.wash(0.07) : null,
            // Painted over the content so selecting never shifts the layout.
            foregroundDecoration: widget.selected || _focus
                ? BoxDecoration(border: Border.all(color: AppColors.accent, width: _focus ? 2 : 1))
                : null,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (s.icon != null) ...[Icon(s.icon, size: 15, color: fg), const SizedBox(width: 6)],
              Flexible(
                child: Text(s.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: TextStyle(fontSize: widget.dense ? 12.5 : 13, color: fg, height: 1.2)),
              ),
              if (s.trailing != null && s.trailing!.isNotEmpty) ...[
                const SizedBox(width: 5),
                Text(s.trailing!, style: const TextStyle(fontSize: 13, color: AppColors.neutral600, height: 1.2)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// Bordered filter chip (genres, categories). Selected: accent edge, a faint
/// accent wash and accent-300 text.
class FilterPill extends StatelessWidget {
  const FilterPill(this.label, {super.key, this.selected = false, this.onTap, this.icon, this.dense = false});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.accent300 : AppColors.neutral300;
    return _PillFrame(
      selected: selected,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 12, vertical: dense ? 4 : 5),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 6)],
          Text(label, style: TextStyle(fontSize: dense ? 12.5 : 13, color: fg, height: 1.35)),
        ]),
      ),
    );
  }
}

class _PillFrame extends StatefulWidget {
  const _PillFrame({required this.selected, required this.onTap, required this.child});
  final bool selected;
  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_PillFrame> createState() => _PillFrameState();
}

class _PillFrameState extends State<_PillFrame> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final edge = widget.selected || _hover || _focus ? AppColors.accent : AppColors.divider;
    return FocusableActionDetector(
      enabled: widget.onTap != null,
      mouseCursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onTap?.call();
          return null;
        }),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: widget.selected ? AppColors.tint(0.10) : Colors.transparent,
            border: Border.all(color: edge),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// A row in a side list (genres, categories, channel lists): selected rows
/// take a faint accent wash, accent-300 text and a 2px accent bar.
class SideListItem extends StatelessWidget {
  const SideListItem({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    this.barInset = 8,
  });
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final EdgeInsets padding;
  final double barInset;

  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        color: selected ? AppColors.tint(0.10) : null,
        hoverColor: selected ? AppColors.tint(0.14) : AppColors.wash(0.06),
        ring: Shadows.ringFlat,
        child: Stack(children: [
          Padding(padding: padding, child: child),
          Positioned(
            left: 0,
            top: barInset,
            bottom: barInset,
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                color: selected ? AppColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ]),
      );
}

/// Label + count row used inside [SideListItem].
class SideListLabel extends StatelessWidget {
  const SideListLabel(this.label, {super.key, required this.selected, this.count});
  final String label;
  final bool selected;
  final String? count;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, color: selected ? AppColors.accent300 : AppColors.neutral400)),
        ),
        if (count != null) Text(count!, style: const TextStyle(fontSize: 11, color: AppColors.neutral600)),
      ]);
}

/// Surface card on the page ground with an optional accent ring on hover.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10)});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        color: AppColors.surface,
        ring: Shadows.ringFlat,
        child: Padding(padding: padding, child: child),
      );
}

/// Floating panel at the top elevation (popovers, player menus).
class Popover extends StatelessWidget {
  const Popover({super.key, required this.child, this.width, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final double? width;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: Shadows.lg,
        ),
        child: child,
      );
}
