import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

abstract final class AppTheme {
  static const green = Color(0xFF193F35),
      orange = Color(0xFFD5693C),
      paper = Color(0xFFF7F8F2),
      ink = Color(0xFF203A32);
  static double get cardRadius => 20.r.clamp(18.0, 24.0);
  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: green,
      brightness: brightness,
      primary: dark ? const Color(0xFF9DD5BE) : green,
      secondary: orange,
      surface: dark ? const Color(0xFF15251F) : Colors.white,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: dark ? const Color(0xFF101C17) : paper,
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineLarge: base.textTheme.headlineLarge!.copyWith(
          fontSize: 32.sp,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
        ),
        headlineMedium: base.textTheme.headlineMedium!.copyWith(
          fontSize: 26.sp,
          fontWeight: FontWeight.w800,
          letterSpacing: -.8,
        ),
        titleLarge: base.textTheme.titleLarge!.copyWith(
          fontSize: 20.sp,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: base.textTheme.titleMedium!.copyWith(
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: base.textTheme.bodyMedium!.copyWith(
          fontSize: 14.sp,
          height: 1.5,
        ),
        bodyLarge: base.textTheme.bodyLarge!.copyWith(
          fontSize: 16.sp,
          height: 1.45,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF101C17) : paper,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge!.copyWith(
          color: scheme.onSurface,
          fontSize: 19.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: base.textTheme.labelLarge!.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .65)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: dark ? green : const Color(0xFFE3EDE2),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: .7),
        space: 32,
      ),
    );
  }
}
