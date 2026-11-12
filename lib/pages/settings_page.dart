import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/backup.dart';
import '../utils/download.dart';
import '../utils/format.dart';
import '../utils/pick_file.dart';
import '../widgets/common.dart';
import 'budget_page.dart';
import 'categories_page.dart';
import 'recurring_page.dart';

/// 設定：外觀、管理、資料備份
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  BackupService get _backup => BackupService(db);

  Future<void> _run(BuildContext context, Future<String?> Function() job) async {
    try {
      final msg = await job();
      if (msg != null && context.mounted) showSnack(context, msg);
    } catch (e) {
      if (context.mounted) showSnack(context, '失敗：$e');
    }
  }

  Future<void> _exportCsv(BuildContext context) => _run(context, () async {
        final csv = await _backup.exportCsv();
        final ok = await saveTextFile(
            'ledger_${formatCompactDate(DateTime.now())}.csv', csv,
            mime: 'text/csv');
        return ok ? '已匯出 CSV' : null;
      });

  Future<void> _importCsv(BuildContext context) => _run(context, () async {
        final text = await pickTextFile(['csv']);
        if (text == null) return null;
        final n = await _backup.importCsv(text);
        return '已匯入 $n 筆紀錄';
      });

  Future<void> _exportJson(BuildContext context) => _run(context, () async {
        final json = await _backup.exportJson();
        final ok = await saveTextFile(
            'ledger_backup_${formatCompactDate(DateTime.now())}.json', json,
            mime: 'application/json');
        return ok ? '已下載完整備份' : null;
      });

  Future<void> _importJson(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      '從備份還原？',
      message: '目前所有的資料都會被備份檔的內容取代，這個動作無法復原。',
      confirmText: '還原',
    );
    if (!ok || !context.mounted) return;
    await _run(context, () async {
      final text = await pickTextFile(['json']);
      if (text == null) return null;
      await _backup.importJson(text);
      return '已從備份還原';
    });
  }

  void _push(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget tile(IconData icon, String title, VoidCallback onTap,
            {String? subtitle, bool chevron = true}) =>
        ListTile(
          leading: Icon(icon),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: chevron ? const Icon(Icons.chevron_right_rounded) : null,
          onTap: onTap,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const SectionHeader('外觀'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ValueListenableBuilder<ThemeMode>(
                valueListenable: themeMode,
                builder: (context, mode, child) => SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_rounded),
                        label: Text('深色')),
                    ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_rounded),
                        label: Text('淺色')),
                    ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_rounded),
                        label: Text('跟隨系統')),
                  ],
                  selected: {mode},
                  onSelectionChanged: (s) {
                    themeMode.value = s.first;
                    db.setSetting('theme', s.first.name);
                  },
                ),
              ),
            ),
          ),
          const SectionHeader('管理'),
          Card(
            child: Column(
              children: [
                tile(Icons.category_rounded, '分類與圖示',
                    () => _push(context, const CategoriesPage())),
                const Divider(indent: 56),
                tile(Icons.savings_rounded, '預算',
                    () => _push(context, const BudgetPage())),
                const Divider(indent: 56),
                tile(Icons.event_repeat_rounded, '固定收支',
                    () => _push(context, const RecurringPage())),
              ],
            ),
          ),
          const SectionHeader('資料備份'),
          Card(
            child: Column(
              children: [
                tile(Icons.file_download_rounded, '匯出 CSV',
                    () => _exportCsv(context),
                    subtitle: '記帳紀錄，可以用 Excel 開啟', chevron: false),
                const Divider(indent: 56),
                tile(Icons.file_upload_rounded, '匯入 CSV',
                    () => _importCsv(context),
                    subtitle: '格式同匯出檔，會加在現有資料後面', chevron: false),
                const Divider(indent: 56),
                tile(Icons.backup_rounded, '完整備份',
                    () => _exportJson(context),
                    subtitle: '帳戶、分類、預算、欠款、固定收支全部存成一個檔案',
                    chevron: false),
                const Divider(indent: 56),
                tile(Icons.restore_rounded, '從備份還原',
                    () => _importJson(context),
                    subtitle: '會覆蓋目前所有資料', chevron: false),
              ],
            ),
          ),
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
              child: Text(
                '網頁版的資料存在這個瀏覽器裡。換瀏覽器、換電腦或清除網站資料前，記得先做完整備份。',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}
