import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const appName = 'Nova TV';

/// Nocturne design tokens: a quiet blue-grey ground, Inter at medium weight
/// and one blurple accent used as a line and a glow rather than a flood.
/// Contrast comes from the tonal ramps, not saturation.
abstract final class AppColors {
  static const bg = Color(0xFF161826);
  static const surface = Color(0xFF232532);
  static const text = Color(0xFFE9E9ED);
  static const accent = Color(0xFF9184D9);

  // Neutral ramp (OKLCH, shared lightness scale with the accent ramp).
  static const n100 = Color(0xFFF3F5FE);
  static const n200 = Color(0xFFE4E7F5);
  static const n300 = Color(0xFFCFD3E5);
  static const n400 = Color(0xFFB2B6CA);
  static const n500 = Color(0xFF9397AB);
  static const n600 = Color(0xFF75798C);
  static const n700 = Color(0xFF595D6C);
  static const n800 = Color(0xFF3F424D);
  static const n900 = Color(0xFF292B31);

  // Accent ramp.
  static const a100 = Color(0xFFF5F4FF);
  static const a200 = Color(0xFFE7E5FE);
  static const a300 = Color(0xFFD2CEFD);
  static const a400 = Color(0xFFB5ABFC);
  static const a500 = Color(0xFF968AE0);
  static const a600 = Color(0xFF796CBF);
  static const a700 = Color(0xFF5D5294);
  static const a800 = Color(0xFF423A6A);
  static const a900 = Color(0xFF2B2741);

  /// Player letterbox — the one place darker than the ground.
  static const video = Color(0xFF0B0C13);

  /// `color-mix(text 16%)` — outlines, dividers, segmented borders.
  static final divider = text.withValues(alpha: 0.16);

  /// `color-mix(text 55%)` — secondary copy.
  static final muted = text.withValues(alpha: 0.55);

  /// Hover tint over any surface.
  static final hover = text.withValues(alpha: 0.07);

  /// Selected-row tint.
  static final accentTint = accent.withValues(alpha: 0.10);

  // Rail background: neutral-900 at 55% over the ground.
  static final rail = Color.alphaBlend(n900.withValues(alpha: 0.55), bg);

  // ---- Legacy names, remapped onto Nocturne so older widgets follow. ----
  static const surfaceHigh = n900;
  static const surfaceHover = Color(0xFF2F3140);
  static const outline = n800;
  static const primary = accent;
  static const gold = a300;
  static const textMuted = n500;
  static const success = a400;
  static const warning = a300;
  static const danger = Color(0xFFE08A8A);
  static const live = accent;
}

/// Corner radii: sm 4 · md 8 · lg 14.
abstract final class Radii {
  static const sm = 4.0;
  static const md = 8.0;
  static const lg = 14.0;
  static const card = md;
  static const hero = lg;
  static const chip = md;
  static const input = md;
}

/// Elevation on a dark ground: a hairline edge plus ambient darkness.
abstract final class Shadows {
  static const sm = [BoxShadow(color: AppColors.n800, spreadRadius: 1)];
  static const md = [
    BoxShadow(color: AppColors.n700, spreadRadius: 1),
    BoxShadow(color: Color(0x8C000000), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const lg = [
    BoxShadow(color: AppColors.n500, spreadRadius: 1),
    BoxShadow(color: Color(0xA6000000), blurRadius: 40, offset: Offset(0, 16)),
  ];

  /// Hover ring on cards: 1px accent + md ambient.
  static const hoverRing = [
    BoxShadow(color: AppColors.accent, spreadRadius: 1),
    BoxShadow(color: Color(0x8C000000), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const accentRing = [BoxShadow(color: AppColors.accent, spreadRadius: 1)];
}

/// Nocturne type scale: Inter, headings at weight 500, tight tracking.
abstract final class NocText {
  static TextStyle _h(double size) => GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w500,
        height: 1.12,
        letterSpacing: -0.015 * size,
        color: AppColors.text,
      );
  static TextStyle get h1 => _h(42);
  static TextStyle get h2 => _h(32);
  static TextStyle get h3 => _h(25);
  static TextStyle get h4 => _h(20);
  static TextStyle get h5 => _h(16);

  /// Uppercase overline ("GENRES", "RECENT SEARCHES").
  static TextStyle get overline =>
      TextStyle(fontSize: 11, letterSpacing: 0.88, color: AppColors.muted, height: 1.4);

  static TextStyle get muted => TextStyle(fontSize: 12, color: AppColors.muted);

  static const tabular = [FontFeature.tabularFigures()];
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.accent, brightness: Brightness.dark).copyWith(
    primary: AppColors.accent,
    onPrimary: AppColors.bg,
    secondary: AppColors.accent,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    surfaceContainerHighest: AppColors.n900,
    outline: AppColors.divider,
    outlineVariant: AppColors.n800,
    error: AppColors.danger,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark);
  final inter = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: AppColors.text,
    displayColor: AppColors.text,
  );
  TextStyle? heading(TextStyle? s, double size) =>
      s?.copyWith(fontSize: size, fontWeight: FontWeight.w500, height: 1.12, letterSpacing: -0.015 * size);

  OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(color: c),
      );

  // Buttons are outlined, never filled: primary = accent line, secondary =
  // divider line, ghost = accent text.
  ButtonStyle button({required Color fg, required Color border, required Color hover}) => ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? fg.withValues(alpha: 0.45) : fg),
        backgroundColor: WidgetStateProperty.all(Colors.transparent),
        overlayColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.pressed)) return hover.withValues(alpha: hover.a * 1.8);
          if (s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)) return hover;
          return null;
        }),
        side: WidgetStateProperty.resolveWith((s) => BorderSide(
            color: s.contains(WidgetState.disabled) ? border.withValues(alpha: border.a * 0.45) : border)),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md))),
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
        minimumSize: WidgetStateProperty.all(const Size(36, 36)),
        elevation: WidgetStateProperty.all(0),
        textStyle: WidgetStateProperty.all(GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
        iconSize: WidgetStateProperty.all(16),
        visualDensity: VisualDensity.standard,
      );
  final primaryBtn =
      button(fg: AppColors.accent, border: AppColors.accent, hover: AppColors.accent.withValues(alpha: 0.12));
  final secondaryBtn = button(fg: AppColors.text, border: AppColors.divider, hover: AppColors.hover);
  final ghostBtn = button(
    fg: AppColors.accent,
    border: Colors.transparent,
    hover: AppColors.accent.withValues(alpha: 0.10),
  ).copyWith(padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 6, vertical: 6)));

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    textTheme: inter.copyWith(
      displayLarge: heading(inter.displayLarge, 42),
      displayMedium: heading(inter.displayMedium, 42),
      displaySmall: heading(inter.displaySmall, 42),
      headlineLarge: heading(inter.headlineLarge, 32),
      headlineMedium: heading(inter.headlineMedium, 25),
      headlineSmall: heading(inter.headlineSmall, 20),
      titleLarge: heading(inter.titleLarge, 16),
      titleMedium: inter.titleMedium?.copyWith(fontWeight: FontWeight.w500),
      titleSmall: inter.titleSmall?.copyWith(fontWeight: FontWeight.w500),
      bodyMedium: inter.bodyMedium?.copyWith(fontSize: 14),
      bodySmall: inter.bodySmall?.copyWith(fontSize: 12),
    ),
    hoverColor: AppColors.hover,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    focusColor: AppColors.accent.withValues(alpha: 0.18),
    iconTheme: const IconThemeData(color: AppColors.text, size: 20),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: border(AppColors.divider),
      enabledBorder: border(AppColors.divider),
      hoverColor: Colors.transparent,
      focusedBorder: border(AppColors.accent),
      errorBorder: border(AppColors.danger),
      hintStyle: const TextStyle(color: AppColors.n500, fontSize: 14),
      prefixIconColor: AppColors.n500,
      suffixIconColor: AppColors.n500,
      prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: AppColors.accent.withValues(alpha: 0.3),
    ),
    filledButtonTheme: FilledButtonThemeData(style: primaryBtn),
    elevatedButtonTheme: ElevatedButtonThemeData(style: primaryBtn),
    outlinedButtonTheme: OutlinedButtonThemeData(style: secondaryBtn),
    textButtonTheme: TextButtonThemeData(style: ghostBtn),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(AppColors.text),
        overlayColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.pressed) ? AppColors.text.withValues(alpha: 0.14) : AppColors.hover),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md))),
        minimumSize: WidgetStateProperty.all(const Size(36, 36)),
        fixedSize: WidgetStateProperty.all(const Size(36, 36)),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: AppColors.accentTint,
      side: BorderSide(color: AppColors.divider),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.n300),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      showCheckmark: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.rail,
      indicatorColor: AppColors.accent.withValues(alpha: 0.12),
      height: 64,
      iconTheme: WidgetStateProperty.resolveWith((s) =>
          IconThemeData(color: s.contains(WidgetState.selected) ? AppColors.accent : AppColors.n500, size: 22)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: s.contains(WidgetState.selected) ? AppColors.accent : AppColors.n500,
          )),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: const BorderSide(color: AppColors.n500),
      ),
      textStyle: const TextStyle(color: AppColors.text, fontSize: 13.5),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.surface),
        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        elevation: WidgetStateProperty.all(8),
        shadowColor: WidgetStateProperty.all(Colors.black),
        padding: WidgetStateProperty.all(const EdgeInsets.all(8)),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: const BorderSide(color: AppColors.n500),
        )),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md))),
        overlayColor: WidgetStateProperty.all(AppColors.text.withValues(alpha: 0.06)),
        textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 13.5)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: const BorderSide(color: AppColors.n500),
      ),
      titleTextStyle: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w500, color: AppColors.text),
      barrierColor: AppColors.n900.withValues(alpha: 0.6),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: AppColors.surface,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.accent : AppColors.n400,
        ),
        side: WidgetStateProperty.all(BorderSide(color: AppColors.divider)),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md))),
        textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 13)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.accent : AppColors.n500),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.a800 : AppColors.n900),
      trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.accent : AppColors.divider),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: AppColors.n800,
      circularTrackColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surface,
      elevation: 6,
      width: 420,
      contentTextStyle: const TextStyle(color: AppColors.text, fontSize: 13),
      actionTextColor: AppColors.accent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: const BorderSide(color: AppColors.n700),
      ),
    ),
    dividerTheme: DividerThemeData(color: AppColors.divider, space: 1, thickness: 1),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.n400,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Radii.md))),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: AppColors.n700),
      ),
      textStyle: const TextStyle(color: AppColors.text, fontSize: 12),
      waitDuration: const Duration(milliseconds: 400),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(AppColors.n800),
      thickness: WidgetStateProperty.all(8),
      radius: const Radius.circular(4),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
    }),
  );
}

/// Lets desktop users drag horizontal rows with the mouse.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// Breakpoints shared by every screen.
extension Responsive on BuildContext {
  double get width => MediaQuery.sizeOf(this).width;
  bool get isWide => width >= 900;
  bool get isExpanded => width >= 1200;
  bool get isCompact => width < 600;

  /// Page gutter: 24 on desktop (the design's rail layout), 16 on phones.
  double get pagePadding => isWide ? 24 : 16;
  bool get hasMouse => isWide;
}
