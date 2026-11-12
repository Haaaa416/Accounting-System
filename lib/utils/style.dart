import 'package:flutter/material.dart';

/// 分類和帳戶可選的圖示。用固定的 key 存進資料庫，
/// 這樣 Web 版編譯時圖示字型才能正常瘦身。
const Map<String, IconData> kIcons = {
  'food': Icons.restaurant_rounded,
  'coffee': Icons.local_cafe_rounded,
  'transport': Icons.directions_bus_rounded,
  'car': Icons.directions_car_rounded,
  'shopping': Icons.shopping_bag_rounded,
  'fun': Icons.sports_esports_rounded,
  'movie': Icons.movie_rounded,
  'home': Icons.home_rounded,
  'bill': Icons.receipt_long_rounded,
  'phone': Icons.smartphone_rounded,
  'health': Icons.local_hospital_rounded,
  'education': Icons.school_rounded,
  'travel': Icons.flight_rounded,
  'pet': Icons.pets_rounded,
  'gift': Icons.card_giftcard_rounded,
  'salary': Icons.payments_rounded,
  'invest': Icons.trending_up_rounded,
  'wallet': Icons.account_balance_wallet_rounded,
  'bank': Icons.account_balance_rounded,
  'card': Icons.credit_card_rounded,
  'savings': Icons.savings_rounded,
  'other': Icons.more_horiz_rounded,
};

IconData iconFor(String key) => kIcons[key] ?? Icons.more_horiz_rounded;

/// 可選的顏色
const List<int> kPalette = [
  0xFFE6B450, // 金
  0xFFF59E0B, // 琥珀
  0xFFF87171, // 珊瑚紅
  0xFFF472B6, // 粉
  0xFFA78BFA, // 紫
  0xFF818CF8, // 靛
  0xFF60A5FA, // 藍
  0xFF22D3EE, // 青
  0xFF34D399, // 綠
  0xFFA3E635, // 萊姆
  0xFF9CA3AF, // 灰
];
