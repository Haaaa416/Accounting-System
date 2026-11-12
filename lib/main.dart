import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'data/database.dart';
import 'pages/shell_page.dart';
import 'theme.dart';

const _zhTW =
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  db = AppDatabase();

  try {
    themeMode.value = switch (await db.getSetting('theme')) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    // 補記到期的固定收支
    await db.runRecurring();
  } catch (e, st) {
    debugPrint('啟動時發生錯誤：$e\n$st');
  }

  runApp(const LedgerApp());
}

class LedgerApp extends StatelessWidget {
  const LedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (context, mode, child) => MaterialApp(
        title: '記帳本',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: mode,
        locale: _zhTW,
        supportedLocales: const [_zhTW, Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const ShellPage(),
      ),
    );
  }
}
