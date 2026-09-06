import 'package:flutter/material.dart';

/// Trend Reel Studio — 심야의 크리에이터 룸
/// 네온 그라디언트 × 글래스모피즘 디자인 시스템
class AppColors {
  AppColors._();

  // 배경 계층
  static const Color bg = Color(0xFF121016);
  static const Color bgElevated = Color(0xFF1A1720);
  static const Color surface = Color(0xFF211D2B);
  static const Color surfaceHigh = Color(0xFF2A2536);

  // 네온 액센트
  static const Color neonMagenta = Color(0xFFFF2E9A);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonPurple = Color(0xFF9B5CFF);
  static const Color neonLime = Color(0xFF7CFF6B);
  static const Color neonAmber = Color(0xFFFFB020);
  static const Color neonRed = Color(0xFFFF4757);

  // 텍스트
  static const Color textHigh = Color(0xFFF5F3F8);
  static const Color textMid = Color(0xFFA9A3B8);
  static const Color textLow = Color(0xFF6E6880);

  // 경계
  static const Color border = Color(0x22FFFFFF);
  static const Color borderStrong = Color(0x33FFFFFF);

  // 그라디언트
  static const LinearGradient brandGradient = LinearGradient(
    colors: [neonMagenta, neonCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [neonPurple, neonMagenta],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [neonCyan, neonPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x18FFFFFF), Color(0x08FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 카테고리별 색상
  static Color categoryColor(String category) {
    switch (category) {
      case '정치':
        return neonRed;
      case '경제':
        return neonLime;
      case 'IT/테크':
        return neonCyan;
      case '스포츠':
        return neonAmber;
      case '연예':
        return neonMagenta;
      case '사회':
        return neonPurple;
      default:
        return textMid;
    }
  }

  /// 트렌드 점수 → 색상 (열기)
  static Color heatColor(int score) {
    if (score >= 90) return neonMagenta;
    if (score >= 75) return neonAmber;
    if (score >= 60) return neonCyan;
    return textLow;
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.neonMagenta,
        secondary: AppColors.neonCyan,
        surface: AppColors.surface,
        onSurface: AppColors.textHigh,
        error: AppColors.neonRed,
      ),
      textTheme: base.textTheme
          .apply(
            bodyColor: AppColors.textHigh,
            displayColor: AppColors.textHigh,
          )
          .copyWith(
            displayLarge: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
              color: AppColors.textHigh,
            ),
            headlineMedium: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: AppColors.textHigh,
            ),
            titleLarge: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: AppColors.textHigh,
            ),
            titleMedium: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textHigh,
            ),
            bodyMedium: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: AppColors.textMid,
            ),
            bodySmall: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textLow,
            ),
            labelSmall: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppColors.textMid,
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textHigh),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textMid,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.neonMagenta,
        linearTrackColor: AppColors.surfaceHigh,
        circularTrackColor: AppColors.surfaceHigh,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: const TextStyle(
          color: AppColors.textHigh,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.neonMagenta
              : AppColors.textLow,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.neonMagenta.withValues(alpha: 0.3)
              : AppColors.surfaceHigh,
        ),
        trackOutlineColor:
            WidgetStateProperty.all(AppColors.border),
      ),
    );
  }
}

/// 네온 글로우 그림자 헬퍼
class AppShadows {
  AppShadows._();

  static List<BoxShadow> glow(Color color, {double blur = 24, double opacity = 0.45}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: blur,
        spreadRadius: -4,
      ),
    ];
  }

  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];
}
