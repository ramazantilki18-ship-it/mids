import 'package:flutter/material.dart';

class AppColors {
  // Metro İstanbul Resmi Kurumsal Renkleri
  static const Color primary = Color(0xFF002B5B); // Kurumsal Lacivert (Metro Blue)
  static const Color primaryLight = Color(0xFF1A4675);
  static const Color accentRed = Color(0xFFD32F2F); // Kurumsal Kırmızı (Metro Red)
  static const Color background = Color(0xFFF4F7FA);
  
  static const Color white = Colors.white;
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textGrey = Color(0xFF757575);
  
  // Denetim Durum Renkleri
  static const Color accentGreen = Color(0xFF2E7D32);
  static const Color accentOrange = Color(0xFFF57C00);
  static const Color accentPurple = Color(0xFF7B1FA2);
  
  // Hat Renkleri (Simgesel)
  static const Color lineT1 = Color(0xFFD32F2F); // T1 Kırmızı
  static const Color lineT4 = Color(0xFFFFA000); // T4 Turuncu/Amber
  static const Color lineT5 = Color(0xFF388E3C); // T5 Yeşil

  // Buton ve Kart Gölgeleri
  static List<BoxShadow> shadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}
