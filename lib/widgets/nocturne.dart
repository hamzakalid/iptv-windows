import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/theme.dart';

export 'package:phosphor_flutter/phosphor_flutter.dart' show PhosphorIconsRegular, PhosphorIconsFill;

/// Nocturne building blocks shared by every screen: outlined buttons,
/// segmented controls, tags, key caps, side-list rows, hover rings and the
/// monogram artwork placeholder.

typedef Ph = PhosphorIconsRegular;
typedef PhF = PhosphorIconsFill;

// ---------------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------------

enum NocButtonKind { primary, secondary, ghost }

/// `.btn` — primary is an accent outline, secondary a divider outline,
/// ghost is accent text. Never a filled flood.
class NocButton extends StatelessWidget {
  const NocButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.kind = NocButtonKind.secondary,
    this.height = 36,
    this.fontSize = 14,
    this.padding,
    this.foreground,
    this.background,
    this.tooltip,
  });

  const NocButton.primary({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.height = 36,
    this.fontSize = 14,
    this.padding,
    this.foreground,
    this.background,
    this.tooltip,
  }) : kind = NocButtonKind.primary;

  const NocButton.ghost({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.height = 32,
    this.fontSize = 13,
    this.padding,
    this.foreground,
    this.background,
    this.tooltip,
  }) : kind = NocButtonKind.ghost;

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final NocButtonKind kind;
  final double height;
  final double fontSize;
  final EdgeInsets? padding;
  final Color? foreground;
  final Color? background;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final (fg, border, hover) = switch (kind) {
      NocButtonKind.primary => (AppColors.accent, AppColors.accent, AppColors.accent.withValues(alpha: 0.12)),
      NocButtonKind.secondary => (AppColors.text, AppColors.divider, AppColors.hover),
      NocButtonKind.ghost => (AppColors.accent, Colors.transparent, AppColors.accent.withValues(alpha: 0.10)),
    };
    final color = foreground ?? fg;
    final enabled = onPressed != null;
    final pad = padding ??
        EdgeInsets.symmetric(horizontal: kind == NocButtonKind.ghost ? 6 : (height >= 38 ? 16 : 10));
    final b = _Pressable(
      onTap: onPressed,
      hover: hover,
      radius: Radii.md,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          height: height,
          padding: pad,
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: fontSize + 2, color: color), if (label.isNotEmpty) const SizedBox(width: 6)],
            if (label.isNotEmpty)
              Text(label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500, color: color, height: 1.2)),
          ]),
        ),
      ),
    );
    return tooltip == null ? b : Tooltip(message: tooltip!, child: b);
  }
}

/// `.btn-icon` — 36×36, transparent, hover tint.
class NocIconButton extends StatelessWidget {
  const NocIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 36,
    this.iconSize = 20,
    this.color,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? color;

  /// Small accent dot, top-right (e.g. unread "What's new").
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final b = _Pressable(
      onTap: onPressed,
      hover: AppColors.hover,
      radius: Radii.md,
      child: SizedBox.square(
        dimension: size,
        child: Stack(alignment: Alignment.center, children: [
          Icon(icon, size: iconSize, color: color ?? AppColors.text),
          if (badge)
            const Positioned(
              top: 6,
              right: 7,
              child: SizedBox.square(
                dimension: 7,
                child: DecoratedBox(decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
              ),
            ),
        ]),
      ),
    );
    return tooltip == null ? b : Tooltip(message: tooltip!, child: b);
  }
}

/// Hover + pressed tint with a pointer cursor; no ripple.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap, required this.hover, required this.radius});
  final Widget child;
  final VoidCallback? onTap;
  final Color hover;
  final double radius;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final tint = !enabled
        ? Colors.transparent
        : _down
            ? widget.hover.withValues(alpha: (widget.hover.a * 1.8).clamp(0, 1))
            : _hover
                ? widget.hover
                : Colors.transparent;
    return FocusableActionDetector(
      enabled: enabled,
      mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onTap?.call())},
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(widget.radius)),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Generic tappable area with the Nocturne hover tint.
class Tappable extends StatelessWidget {
  const Tappable({super.key, required this.child, this.onTap, this.radius = Radii.md, this.hover});
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final Color? hover;

  @override
  Widget build(BuildContext context) =>
      _Pressable(onTap: onTap, hover: hover ?? AppColors.text.withValues(alpha: 0.06), radius: radius, child: child);
}

// ---------------------------------------------------------------------------
// Segmented control
// ---------------------------------------------------------------------------

class SegOption<T> {
  const SegOption(this.value, this.label, {this.icon, this.count});
  final T value;
  final String label;
  final IconData? icon;

  /// Muted trailing count ("Movies 12").
  final String? count;
}

/// `.seg` — a divider-outlined strip; the selected option gets an inset
/// 1px accent ring and accent text.
class Seg<T> extends StatelessWidget {
  const Seg({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.fontSize = 13,
    this.expand = false,
  });

  final List<SegOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final EdgeInsets padding;
  final double fontSize;

  /// Stretch options to fill the width (speed picker).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    Widget opt(SegOption<T> o) {
      final on = o.value == value;
      final fg = on ? AppColors.accent : AppColors.n400;
      final child = Tappable(
        radius: 0,
        onTap: () => onChanged(o.value),
        child: Container(
          padding: padding,
          alignment: Alignment.center,
          decoration: BoxDecoration(border: on ? Border.all(color: AppColors.accent) : null),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (o.icon != null) ...[Icon(o.icon, size: fontSize + 1, color: fg), const SizedBox(width: 5)],
            Text(o.label, style: TextStyle(fontSize: fontSize, color: fg, height: 1.2)),
            if (o.count != null && o.count!.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(o.count!, style: TextStyle(fontSize: fontSize, color: AppColors.n600, height: 1.2)),
            ],
          ]),
        ),
      );
      return expand ? Expanded(child: child) : child;
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final o in options) opt(o)],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tags, key caps, overlines
// ---------------------------------------------------------------------------

enum TagKind { accent, neutral, outline }

/// `.tag` — small label tinted from the ramps.
class NocTag extends StatelessWidget {
  const NocTag(this.label, {super.key, this.kind = TagKind.neutral, this.icon, this.leading});
  final String label;
  final TagKind kind;
  final IconData? icon;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (kind) {
      TagKind.accent => (AppColors.a800, AppColors.a100, null),
      TagKind.neutral => (AppColors.n800, AppColors.n100, null),
      TagKind.outline => (Colors.transparent, AppColors.accent, AppColors.accent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: border == null ? null : Border.all(color: border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (leading != null) ...[leading!, const SizedBox(width: 5)],
        if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
        Text(label, style: TextStyle(fontSize: 11, letterSpacing: 0.22, color: fg, height: 1.3)),
      ]),
    );
  }
}

/// Outlined keyboard hint ("C", "/", "Esc").
class KeyCap extends StatelessWidget {
  const KeyCap(this.label, {super.key, this.minWidth = 0, this.color});
  final String label;
  final double minWidth;
  final Color? color;

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
            style: TextStyle(fontSize: 11, height: 16 / 11, color: color ?? AppColors.n500)),
      );
}

/// Uppercase section label ("CATEGORIES").
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.padding = EdgeInsets.zero});
  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: padding, child: Text(text.toUpperCase(), style: NocText.overline));
}

/// Page title block: h3 + muted caption.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.caption});
  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: NocText.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(caption!, style: NocText.muted, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ],
      );
}

/// Row heading: h5 title, optional muted note, optional ghost action.
class RowHeading extends StatelessWidget {
  const RowHeading(this.title, {super.key, this.note, this.action, this.onAction, this.padding});
  final String title;
  final String? note;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    return Padding(
      padding: padding ?? EdgeInsets.fromLTRB(pad, 28, pad, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text(title, style: NocText.h5),
        const SizedBox(width: 10),
        Expanded(
          child: note == null
              ? const SizedBox.shrink()
              : Text(note!, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.n600)),
        ),
        if (action != null) NocButton.ghost(label: action!, onPressed: onAction),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Lists, progress, cards
// ---------------------------------------------------------------------------

/// Aside list row (categories / genres): selected rows get an accent tint,
/// accent-300 text and a 2px accent bar on the left edge.
class SideListItem extends StatelessWidget {
  const SideListItem({super.key, required this.label, this.count, required this.selected, required this.onTap});
  final String label;
  final String? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: Tappable(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: selected ? AppColors.accentTint : Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Stack(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Row(children: [
                  Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.5, color: selected ? AppColors.a300 : AppColors.n400)),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 8),
                    Text(count!, style: const TextStyle(fontSize: 11, color: AppColors.n600)),
                  ],
                ]),
              ),
              if (selected)
                Positioned(
                  left: 0,
                  top: 8,
                  bottom: 8,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
            ]),
          ),
        ),
      );
}

/// Thin progress line: neutral-800 track, accent fill.
class ProgressLine extends StatelessWidget {
  const ProgressLine(this.value, {super.key, this.height = 2, this.track, this.color});
  final double value;
  final double height;
  final Color? track;
  final Color? color;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: Stack(children: [
            Positioned.fill(child: ColoredBox(color: track ?? AppColors.n800)),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              heightFactor: 1,
              child: ColoredBox(color: color ?? AppColors.accent),
            ),
          ]),
        ),
      );
}

/// Adds the Nocturne hover ring (1px accent + ambient shadow) to a card.
class HoverRing extends StatefulWidget {
  const HoverRing({
    super.key,
    required this.child,
    this.onTap,
    this.radius = Radii.md,
    this.ring = Shadows.hoverRing,
    this.active = false,
    this.onSecondaryTap,
  });
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onSecondaryTap;
  final double radius;
  final List<BoxShadow> ring;

  /// Keep the ring on (e.g. the channel that is playing in PiP).
  final bool active;

  @override
  State<HoverRing> createState() => _HoverRingState();
}

class _HoverRingState extends State<HoverRing> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onSecondaryTap: widget.onSecondaryTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              boxShadow: _hover ? widget.ring : (widget.active ? Shadows.accentRing : const []),
            ),
            child: widget.child,
          ),
        ),
      );
}

/// Poster / backdrop placeholder: a soft radial of the neutral ramp with a
/// monogram. Used wherever artwork is missing.
class ArtPlaceholder extends StatelessWidget {
  const ArtPlaceholder({
    super.key,
    this.label,
    this.fontSize = 20,
    this.center = const Alignment(-0.4, -0.7),
    this.from = AppColors.n800,
    this.textColor = AppColors.n600,
    this.child,
  });
  final String? label;
  final double fontSize;
  final Alignment center;
  final Color from;
  final Color textColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: center,
            radius: 1.1,
            colors: [from, AppColors.n900],
            stops: const [0, 0.7],
          ),
        ),
        child: Center(
          child: child ??
              Text(initials(label),
                  style: TextStyle(
                      fontSize: fontSize, fontWeight: FontWeight.w500, letterSpacing: fontSize * 0.04, color: textColor)),
        ),
      );
}

/// Up to two initials from a title ("BBC News HD" → "BN").
String initials(String? name) {
  final words = (name ?? '')
      .replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), '')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(2);
  final s = words.map((w) => w.characters.first.toUpperCase()).join();
  return s.isEmpty ? '•' : s;
}

/// Small rounded logo tile with initials (channel chips, list rows).
class LogoTile extends StatelessWidget {
  const LogoTile({super.key, required this.label, this.width = 36, this.height = 36, this.fontSize = 11, this.image});
  final String label;
  final double width;
  final double height;
  final double fontSize;

  /// Optional real logo drawn over the tile.
  final Widget? image;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: AppColors.n900, borderRadius: BorderRadius.circular(Radii.sm)),
        alignment: Alignment.center,
        child: image ?? Text(initials(label), style: TextStyle(fontSize: fontSize, color: AppColors.n400)),
      );
}

/// Translucent panel used for player drawers (surface @94% + blur edge).
BoxDecoration drawerDecoration({bool bottom = false}) => BoxDecoration(
      color: AppColors.surface.withValues(alpha: bottom ? 0.95 : 0.94),
      boxShadow: [
        BoxShadow(color: AppColors.n800, offset: bottom ? const Offset(0, -1) : const Offset(-1, 0)),
        BoxShadow(
          color: const Color(0x80000000),
          blurRadius: 40,
          offset: bottom ? const Offset(0, -16) : const Offset(-16, 0),
        ),
      ],
    );

/// Popover card at the top elevation (menus, "What's new", settings).
BoxDecoration popoverDecoration() => BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(Radii.lg),
      boxShadow: Shadows.lg,
    );
