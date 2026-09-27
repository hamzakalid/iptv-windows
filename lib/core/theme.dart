import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const appName = 'Nova TV';

/// Design tokens: a deep, cinematic dark theme with a violet→pink accent.
abstract final class AppColors {
  static const bg = Color(0xFF09090F);
  static const surface = Color(0xFF12121C);
  static const surfaceHigh = Color(0xFF1B1B29);
  static const outline = Color(0xFF2A2A3C);
  static const primary = Color(0xFF8B5CF6);
  static const accent = Color(0xFFEC4899);
  static const text = Color(0xFFF4F4F8);
  static const textMuted = Color(0xFF9A9AB0);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const live = Color(0xFFFF3B5C);

  static const brandGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.primary,
    secondary: AppColors.accent,
    surface: AppColors.surface,
    surfaceContainerHighest: AppColors.surfaceHigh,
    outline: AppColors.outline,
    error: AppColors.danger,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark);
  final text = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: AppColors.text,
    displayColor: AppColors.text,
  );
  final display = GoogleFonts.outfitTextTheme(text);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: text.copyWith(
      displayLarge: display.displayLarge?.copyWith(fontWeight: FontWeight.w800),
      displayMedium: display.displayMedium?.copyWith(fontWeight: FontWeight.w800),
      displaySmall: display.displaySmall?.copyWith(fontWeight: FontWeight.w700),
      headlineLarge: display.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium: display.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      headlineSmall: display.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: display.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.textMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        side: const BorderSide(color: AppColors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceHigh,
      selectedColor: AppColors.primary,
      side: const BorderSide(color: AppColors.outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w500),
      showCheckmark: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primary.withValues(alpha: 0.22),
      height: 68,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: const TextStyle(color: AppColors.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.outline, space: 1),
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
  bool get isCompact => width < 600;
  double get pagePadding => isWide ? 32 : 16;
}
