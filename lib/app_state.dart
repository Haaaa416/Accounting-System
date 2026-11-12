import 'package:flutter/material.dart';

import 'data/database.dart';

/// 整個 App 共用的資料庫（在 main() 裡建立）
late final AppDatabase db;

/// 目前的主題模式，改變時整個 App 會跟著切換
final themeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);
