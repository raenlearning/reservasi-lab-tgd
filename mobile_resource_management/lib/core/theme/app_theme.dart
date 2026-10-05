import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema aplikasi (Material 3).
///
/// Prinsip yang dipakai:
/// * Satu warna aksen utama, sisanya netral — supaya informasi (status jadwal)
///   yang berwarna tetap menonjol.
/// * Radius konsisten 14 untuk kartu, 12 untuk input/tombol.
/// * Tinggi minimum area sentuh 48dp (aksesibilitas di layar kecil).
class AppTheme {
  const AppTheme._();

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double touchTarget = 48;

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  /// Jarak aman dari tepi layar untuk konten.
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: 20);

  // ---------------------------------------------------------------------------
  // Light
  // ---------------------------------------------------------------------------

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      surface: AppColors.surfaceCard,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
      outlineVariant: AppColors.border,
    );

    return _base(
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.surface,
      cardColor: AppColors.surfaceCard,
      borderColor: AppColors.border,
      textPrimary: AppColors.textPrimary,
      textSecondary: AppColors.textSecondary,
    );
  }

  // ---------------------------------------------------------------------------
  // Dark
  // ---------------------------------------------------------------------------

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryLight,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF8FB6E6),
      onPrimary: const Color(0xFF06203C),
      secondary: const Color(0xFF6FD3C6),
      onSecondary: const Color(0xFF00201C),
      surface: AppColors.surfaceCardDark,
      onSurface: AppColors.textPrimaryDark,
      error: const Color(0xFFFFB4AB),
      outlineVariant: AppColors.borderDark,
    );

    return _base(
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.surfaceDark,
      cardColor: AppColors.surfaceCardDark,
      borderColor: AppColors.borderDark,
      textPrimary: AppColors.textPrimaryDark,
      textSecondary: AppColors.textSecondaryDark,
    );
  }

  // ---------------------------------------------------------------------------
  // Builder bersama
  // ---------------------------------------------------------------------------

  static ThemeData _base({
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color cardColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final textTheme = _textTheme(textPrimary, textSecondary);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,

      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        toolbarHeight: 60,
      ),

      cardTheme: CardThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: borderColor),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: textSecondary.withValues(alpha: 0.7),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        border: _inputBorder(borderColor),
        enabledBorder: _inputBorder(borderColor),
        disabledBorder: _inputBorder(borderColor.withValues(alpha: 0.6)),
        focusedBorder: _inputBorder(colorScheme.primary, width: 1.6),
        errorBorder: _inputBorder(colorScheme.error),
        focusedErrorBorder: _inputBorder(colorScheme.error, width: 1.6),
        errorStyle: textTheme.bodySmall?.copyWith(color: colorScheme.error),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(touchTarget),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: borderColor,
          disabledForegroundColor: textSecondary,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm + 2),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(touchTarget),
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: borderColor),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm + 2),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(0, 40),
        ),
      ),

      iconTheme: IconThemeData(color: textSecondary, size: 22),

      chipTheme: ChipThemeData(
        backgroundColor: cardColor,
        side: BorderSide(color: borderColor),
        labelStyle: textTheme.bodySmall?.copyWith(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: cardColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusLg),
          ),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: borderColor,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: textSecondary,
        indicatorColor: colorScheme.primary,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
        dividerColor: borderColor,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm + 2),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 32,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: primary,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: primary,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.5,
        color: secondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12.5,
        height: 1.45,
        color: secondary,
      ),
      labelLarge: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: secondary,
      ),
      labelSmall: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: secondary,
      ),
    );
  }
}
