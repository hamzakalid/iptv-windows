import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const appName = 'Nova TV';

/// Nocturne: a quiet, compact dark system. A near-neutral blue-grey ground,
/// Inter at medium weight, 8px radii and one blurple accent that is used as
/// a line and a glow, never as a flood. Contrast comes from the tonal ramps,
/// not from saturation. Take every colour from here.
abstract final class AppColors {
  static const bg = Color(0xFF161826);
  static const surface = Color(0xFF232532);
  static const text = Color(0xFFE9E9ED);
  static const accent = Color(0xFF9184D9);

  /// Hairlines, input borders and unselected outlines (text at 16%).
  static const divider = Color(0x29E9E9ED);

  /// Secondary copy (text at 55%).
  static const textMuted = Color(0x8CE9E9ED);

  /// Navigation rail: neutral-900 mixed 55% into the ground.
  static const rail = Color(0xFF20222C);

  /// The player's ground, darker than the page so letterboxing disappears.
  static const ink = Color(0xFF0B0C13);

  /// Saturated deep indigo for the one full-bleed "presence" field (the
  /// sign-in backdrop). Never an interface colour.
  static const section = Color(0xFF262A60);

  // Tonal ramps, generated on one shared perceptual lightness scale so the
  // same step of each role carries the same visual weight. On this ground:
  // 700–900 for tinted fills and quiet borders, 500 as the base, 100–300 for
  // text on tints and pressed states.
  static const neutral100 = Color(0xFFF3F5FE);
  static const neutral200 = Color(0xFFE4E7F5);
  static const neutral300 = Color(0xFFCFD3E5);
  static const neutral400 = Color(0xFFB2B6CA);
  static const neutral500 = Color(0xFF9397AB);
  static const neutral600 = Color(0xFF75798C);
  static const neutral700 = Color(0xFF595D6C);
  static const neutral800 = Color(0xFF3F424D);
  static const neutral900 = Color(0xFF292B31);

  static const accent100 = Color(0xFFF5F4FF);
  static const accent200 = Color(0xFFE7E5FE);
  static const accent300 = Color(0xFFD2CEFD);
  static const accent400 = Color(0xFFB5ABFC);
  static const accent500 = Color(0xFF968AE0);
  static const accent600 = Color(0xFF796CBF);
  static const accent700 = Color(0xFF5D5294);
  static const accent800 = Color(0xFF423A6A);
  static const accent900 = Color(0xFF2B2741);

  // Status colours sit outside the mono palette. Keep them to errors and
  // playlist health, at the ramps' muted chroma.
  static const danger = Color(0xFFE5838A);
  static const success = Color(0xFF86C9A4);
  static const warning = Color(0xFFDDBB78);

  /// Neutral hover/pressed wash over any surface (text at [alpha]).
  static Color wash(double alpha) => text.withValues(alpha: alpha);

  /// Accent tint for selected rows and outlined hovers.
  static Color tint(double alpha) => accent.withValues(alpha: alpha);
}

abstract final class Radii {
  static const sm = 4.0;
  static const md = 8.0;
  static const lg = 14.0;
}

/// Elevation is an edge plus ambient darkness, never a stack of soft shadows.
abstract final class Shadows {
  static const sm = [BoxShadow(color: AppColors.neutral800, spreadRadius: 1)];
  static const md = [
    BoxShadow(color: Color(0x8C000000), blurRadius: 15, offset: Offset(0, 6)),
    BoxShadow(color: AppColors.neutral700, spreadRadius: 1),
  ];
  static const lg = [
    BoxShadow(color: Color(0xA6000000), blurRadius: 34, offset: Offset(0, 16)),
    BoxShadow(color: AppColors.neutral500, spreadRadius: 1),
  ];

  /// Hover and keyboard-focus state for cards and tiles.
  static const ring = [
    BoxShadow(color: Color(0x8C000000), blurRadius: 15, offset: Offset(0, 6)),
    BoxShadow(color: AppColors.accent, spreadRadius: 1),
  ];

  /// Accent hairline alone, for flat surface cards.
  static const ringFlat = [BoxShadow(color: AppColors.accent, spreadRadius: 1)];
}

/// The type scale. Headings stay at 500 — hierarchy is size and space.
abstract final class AppText {
  static const h1 = TextStyle(fontSize: 42, fontWeight: FontWeight.w500, height: 1.12, letterSpacing: -0.63);
  static const h2 = TextStyle(fontSize: 32, fontWeight: FontWeight.w500, height: 1.12, letterSpacing: -0.48);
  static const h3 = TextStyle(fontSize: 25, fontWeight: FontWeight.w500, height: 1.12, letterSpacing: -0.38);
  static const h4 = TextStyle(fontSize: 20, fontWeight: FontWeight.w500, height: 1.12, letterSpacing: -0.3);
  static const h5 = TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.12, letterSpacing: -0.24);

  /// Card and row titles.
  static const title = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500);

  /// Secondary lines under titles.
  static const meta = TextStyle(fontSize: 12, color: AppColors.textMuted);

  /// Small uppercase section label; pass upper-cased text (see [Eyebrow]).
  static const eyebrow = TextStyle(fontSize: 11, letterSpacing: 0.88, color: AppColors.textMuted);

  /// Accent line above a title ("MOVIE").
  static const kicker = TextStyle(fontSize: 10, letterSpacing: 1, color: AppColors.accent);

  /// Clock times, channel numbers and counters.
  static const tabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
}

ButtonStyle _button({
  required Color fg,
  required Color hover,
  required Color pressed,
  BorderSide side = BorderSide.none,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 12),
}) =>
    ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? fg.withValues(alpha: 0.45) : fg),
      iconColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? fg.withValues(alpha: 0.45) : fg),
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.pressed)) return pressed;
        if (s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)) return hover;
        return null;
      }),
      side: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.focused)) return const BorderSide(color: AppColors.accent, width: 2);
        if (s.contains(WidgetState.disabled) && side != BorderSide.none) {
          return side.copyWith(color: side.color.withValues(alpha: side.color.a * 0.45));
        }
        return side;
      }),
      shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Radii.md)))),
      padding: WidgetStatePropertyAll(padding),
      minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
      iconSize: const WidgetStatePropertyAll(16),
      textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.2)),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
    );

/// Primary action: an accent outline, never a fill.
final primaryButton = _button(
  fg: AppColors.accent,
  side: const BorderSide(color: AppColors.accent),
  hover: AppColors.tint(0.12),
  pressed: AppColors.tint(0.22),
);

/// Secondary action: a divider-weight outline in the text colour.
final secondaryButton = _button(
  fg: AppColors.text,
  side: const BorderSide(color: AppColors.divider),
  hover: AppColors.wash(0.07),
  pressed: AppColors.wash(0.14),
);

/// Ghost action: accent text with no edge.
final ghostButton = _button(
  fg: AppColors.accent,
  hover: AppColors.tint(0.10),
  pressed: AppColors.tint(0.18),
  padding: const EdgeInsets.symmetric(horizontal: 8),
);

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: AppColors.bg,
    primaryContainer: AppColors.accent800,
    onPrimaryContainer: AppColors.accent100,
    secondary: AppColors.accent,
    onSecondary: AppColors.bg,
    secondaryContainer: AppColors.accent800,
    onSecondaryContainer: AppColors.accent100,
    tertiary: AppColors.accent300,
    onTertiary: AppColors.bg,
    surface: AppColors.bg,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.neutral400,
    surfaceContainerLowest: AppColors.bg,
    surfaceContainerLow: AppColors.rail,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surface,
    surfaceContainerHighest: AppColors.neutral900,
    outline: AppColors.divider,
    outlineVariant: AppColors.neutral800,
    error: AppColors.danger,
    onError: AppColors.bg,
    inverseSurface: AppColors.text,
    onInverseSurface: AppColors.bg,
    shadow: Colors.black,
    surfaceTint: Colors.transparent,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: GoogleFonts.inter().fontFamily,
  );
  final inter = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: AppColors.text,
    displayColor: AppColors.text,
  );
  TextStyle? heading(TextStyle? s, TextStyle to) => s?.merge(to);
  final text = inter.copyWith(
    displayLarge: heading(inter.displayLarge, AppText.h1),
    displayMedium: heading(inter.displayMedium, AppText.h2),
    displaySmall: heading(inter.displaySmall, AppText.h3),
    headlineLarge: heading(inter.headlineLarge, AppText.h3),
    headlineMedium: heading(inter.headlineMedium, AppText.h4),
    headlineSmall: heading(inter.headlineSmall, AppText.h4),
    titleLarge: heading(inter.titleLarge, AppText.h4),
    titleMedium: heading(inter.titleMedium, AppText.h5),
    titleSmall: inter.titleSmall?.merge(AppText.title),
    bodyLarge: inter.bodyLarge?.copyWith(fontSize: 15),
    bodyMedium: inter.bodyMedium?.copyWith(fontSize: 14),
    bodySmall: inter.bodySmall?.copyWith(fontSize: 12),
    labelLarge: inter.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
    labelMedium: inter.labelMedium?.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500),
    labelSmall: inter.labelSmall?.copyWith(fontSize: 11, letterSpacing: 0.22),
  );

  OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(color: c),
      );

  final menuShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Radii.lg),
    side: const BorderSide(color: AppColors.neutral700),
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    textTheme: text,
    primaryTextTheme: text,
    hoverColor: AppColors.wash(0.06),
    focusColor: AppColors.tint(0.14),
    highlightColor: AppColors.wash(0.10),
    splashColor: Colors.transparent,
    splashFactory: NoSplash.splashFactory,
    iconTheme: const IconThemeData(color: AppColors.text, size: 20),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hoverColor: Colors.transparent,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      border: WidgetStateInputBorder.resolveWith((s) {
        if (s.contains(WidgetState.error)) return border(AppColors.danger);
        if (s.contains(WidgetState.focused)) return border(AppColors.accent);
        if (s.contains(WidgetState.hovered)) return border(AppColors.wash(0.45));
        return border(AppColors.divider);
      }),
      hintStyle: const TextStyle(color: AppColors.neutral500, fontSize: 14),
      labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      floatingLabelStyle: const TextStyle(color: AppColors.accent),
      helperStyle: AppText.meta,
      errorStyle: const TextStyle(color: AppColors.danger, fontSize: 12),
      prefixIconColor: AppColors.neutral500,
      suffixIconColor: AppColors.neutral500,
      prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    ),
    filledButtonTheme: FilledButtonThemeData(style: primaryButton),
    elevatedButtonTheme: ElevatedButtonThemeData(style: secondaryButton),
    outlinedButtonTheme: OutlinedButtonThemeData(style: secondaryButton),
    textButtonTheme: TextButtonThemeData(style: ghostButton),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? AppColors.wash(0.45) : AppColors.text),
        overlayColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.pressed)) return AppColors.wash(0.14);
          if (s.contains(WidgetState.hovered)) return AppColors.wash(0.07);
          if (s.contains(WidgetState.focused)) return AppColors.tint(0.14);
          return null;
        }),
        shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Radii.md)))),
        minimumSize: const WidgetStatePropertyAll(Size(36, 36)),
        fixedSize: const WidgetStatePropertyAll(Size(36, 36)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        iconSize: const WidgetStatePropertyAll(20),
        splashFactory: NoSplash.splashFactory,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: AppColors.tint(0.10),
      side: const BorderSide(color: AppColors.divider),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.neutral300),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      showCheckmark: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.rail,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.tint(0.12),
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      height: 64,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            size: 22,
            color: s.contains(WidgetState.selected) ? AppColors.accent : AppColors.neutral500,
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: s.contains(WidgetState.selected) ? AppColors.accent : AppColors.neutral500,
          )),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shadowColor: Colors.black,
      shape: menuShape,
      textStyle: const TextStyle(color: AppColors.text, fontSize: 13.5),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(10),
        shadowColor: const WidgetStatePropertyAll(Colors.black),
        shape: WidgetStatePropertyAll(menuShape),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(AppColors.text),
        iconColor: const WidgetStatePropertyAll(AppColors.neutral400),
        overlayColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.hovered) || s.contains(WidgetState.focused) ? AppColors.wash(0.06) : null),
        shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Radii.md)))),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
        minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
        iconSize: const WidgetStatePropertyAll(18),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 13.5)),
        splashFactory: NoSplash.splashFactory,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shadowColor: Colors.black,
      barrierColor: AppColors.neutral900.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: const BorderSide(color: AppColors.neutral500),
      ),
      titleTextStyle: text.titleLarge,
      contentTextStyle: TextStyle(fontSize: 14, color: AppColors.wash(0.85), height: 1.5),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surface,
      elevation: 8,
      contentTextStyle: const TextStyle(color: AppColors.text, fontSize: 13),
      actionTextColor: AppColors.accent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: const BorderSide(color: AppColors.neutral700),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1, space: 1),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: AppColors.neutral900,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: AppColors.neutral800),
      ),
      textStyle: const TextStyle(color: AppColors.neutral200, fontSize: 12),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: AppColors.neutral800,
      circularTrackColor: Colors.transparent,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: const WidgetStatePropertyAll(AppColors.neutral800),
      radius: const Radius.circular(4),
      thickness: const WidgetStatePropertyAll(8),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: AppColors.tint(0.30),
      selectionHandleColor: AppColors.accent,
    ),
    badgeTheme: const BadgeThemeData(backgroundColor: AppColors.accent, textColor: AppColors.bg),
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
  double get pagePadding => isWide ? 24 : 16;
  bool get hasMouse => isWide;
}
