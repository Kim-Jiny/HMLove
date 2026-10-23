import 'package:flutter/material.dart';

/// 소프트 파스텔 디자인 시스템.
///
/// 색은 이 파일의 토큰만 참조한다. 화면에서 `Color(0x...)` 를 직접 쓰지 말고
/// 포인트 색이 더 필요하면 아래 파스텔 팔레트(lavender/mint/peach/sky)를 쓴다.
class AppTheme {
  AppTheme._();

  static const String fontFamily = 'Pretendard';

  // Primary - 부드러운 로즈
  static const Color primaryColor = Color(0xFFEC5F8E);
  static const Color primaryLight = Color(0xFFF7A9C4);
  static const Color primaryDark = Color(0xFFC94476);
  static const Color primarySoft = Color(0xFFFFEAF1); // 칩·아이콘 배경용 틴트
  static const Color accentColor = Color(0xFFFF8FB1);

  // Pastel accents - 카테고리/아이콘 구분용
  static const Color lavender = Color(0xFF9B8CE8);
  static const Color lavenderSoft = Color(0xFFF0EDFF);
  static const Color mint = Color(0xFF4DBFA0);
  static const Color mintSoft = Color(0xFFE6F7F1);
  static const Color peach = Color(0xFFF59E6C);
  static const Color peachSoft = Color(0xFFFFEFE4);
  static const Color sky = Color(0xFF5BA8F0);
  static const Color skySoft = Color(0xFFE7F2FD);
  static const Color butter = Color(0xFFE9B93C);
  static const Color butterSoft = Color(0xFFFFF5D9);

  // Background Colors
  static const Color backgroundColor = Color(0xFFFFF8FA);
  static const Color surfaceColor = Colors.white;
  static const Color cardColor = Colors.white;
  static const Color borderColor = Color(0xFFF6E7ED);

  /// 카툰풍 윤곽선 색 (순검정 대신 부드러운 자두색).
  static const Color ink = Color(0xFF4A3B52);

  // Text Colors
  static const Color textPrimary = Color(0xFF2E2A33);
  static const Color textSecondary = Color(0xFF7A7480);
  static const Color textHint = Color(0xFFB9B3BE);

  // Status Colors
  static const Color errorColor = Color(0xFFE5484D);
  static const Color successColor = Color(0xFF4CB782);
  static const Color warningColor = Color(0xFFF5B83D);

  // Radius
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 24;

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFF58BAE), Color(0xFFEC5F8E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 카툰풍 '찍힌' 그림자: 번지지 않고 아래로 딱 떨어지는 로즈빛.
  static const List<BoxShadow> cartoonShadow = [
    BoxShadow(color: Color(0xFFF3CCD9), offset: Offset(0, 4), blurRadius: 0),
  ];

  /// 윤곽선 굵기.
  static const double outlineWidth = 1.5;

  /// 카드 아래에 깔리는 은은한 로즈빛 그림자.
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: primaryColor.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  /// 흰 카드 + 윤곽선 + 찍힌 그림자. 커스텀 컨테이너가 카드처럼 보여야 할 때.
  static BoxDecoration cardDecoration({Color color = Colors.white}) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radiusMd + 4),
        border: Border.all(color: ink, width: outlineWidth),
        boxShadow: cartoonShadow,
      );

  static ThemeData get lightTheme {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ).copyWith(
          primary: primaryColor,
          onPrimary: Colors.white,
          primaryContainer: primarySoft,
          onPrimaryContainer: primaryDark,
          secondary: accentColor,
          secondaryContainer: lavenderSoft,
          surface: surfaceColor,
          surfaceTint: Colors.transparent,
          onSurface: textPrimary,
          outline: borderColor,
          outlineVariant: borderColor,
          error: errorColor,
        );

    final roundedShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusSm + 2),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: backgroundColor,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: primarySoft,
        indicatorShape: const StadiumBorder(
          side: BorderSide(color: ink, width: outlineWidth),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? primaryColor : textHint,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: fontFamily,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? primaryColor : textHint,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd + 4),
          side: const BorderSide(color: ink, width: outlineWidth),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primaryLight.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            side: const BorderSide(color: ink, width: outlineWidth),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            side: const BorderSide(color: ink, width: outlineWidth),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: ink, width: outlineWidth),
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: roundedShape,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(
            color: ink.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(
            color: ink.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: ink, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textHint, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd + 4),
          side: const BorderSide(color: ink, width: outlineWidth),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: ink, width: outlineWidth),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          height: 1.5,
          color: textSecondary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        dragHandleColor: borderColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: ink, width: outlineWidth),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primarySoft,
        selectedColor: primaryColor,
        side: BorderSide.none,
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? primaryColor
              : const Color(0xFFE5E0E8);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: textSecondary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: primarySoft,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.4,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: textPrimary),
        bodySmall: TextStyle(fontSize: 12, height: 1.4, color: textSecondary),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
