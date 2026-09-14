import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppTheme {
  // 核心主色调：墨海蓝 (Ocean Navy) + 财利金 (Amber Gold) + 翡翠绿 (Profit Green)
  static const Color primary = Color(0xFF0F172A); // 深邃黑蓝
  static const Color accent = Color(0xFF0EA5E9); // 洞察湛蓝 (Sky)
  static const Color gold = Color(0xFFF59E0B); // 琥珀金
  static const Color profit = Color(0xFF10B981); // 纯利润翡翠绿
  static const Color loss = Color(0xFFEF4444); // 亏损/支出警示红
  static const Color cardBg = Colors.white;
  static const Color pageBg = Color(0xFFF8FAFC); // 极清浅灰蓝底色

  static final currencyFormat = NumberFormat.currency(
    symbol: '¥',
    decimalDigits: 2,
  );

  static final compactCurrencyFormat = NumberFormat.currency(
    symbol: '¥',
    decimalDigits: 0,
  );

  static String formatMoney(double amount) => currencyFormat.format(amount);
  static String formatPercent(double percent) => '${percent.toStringAsFixed(1)}%';

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: pageBg,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        primary: primary,
        secondary: gold,
        surface: cardBg,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: primary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: primary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
    );
  }
}
