import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../utils/format.dart';
import 'database.dart';

/// CSV 匯出／匯入（記帳紀錄）與 JSON 完整備份／還原
class BackupService {
  BackupService(this.db);

  final AppDatabase db;

  static const _csvHeader = ['日期', '類型', '金額', '分類', '帳戶', '備註'];

  // ───────── CSV ─────────

  /// 匯出所有記帳紀錄。開頭加 BOM，Excel 開啟中文才不會亂碼。
  Future<String> exportCsv() async {
    final views = await db.getAllEntries();
    final lines = <String>[
      _csvLine(_csvHeader),
      for (final v in views.reversed)
        _csvLine([
          formatIsoDate(v.entry.date),
          v.isIncome ? '收入' : '支出',
          v.entry.amount.toString(),
          v.category.name,
          v.account?.name ?? '',
          v.entry.note ?? '',
        ]),
    ];
    return '﻿${lines.join('\r\n')}\r\n';
  }

  /// 匯入 CSV（格式同匯出），找不到的分類和帳戶會自動建立。
  /// 回傳成功匯入的筆數。不會檢查重複，同一個檔案匯入兩次就會有兩份。
  Future<int> importCsv(String text) async {
    var rows = parseCsv(text);
    if (rows.isEmpty) return 0;
    if (rows.first.isNotEmpty && rows.first.first.trim() == '日期') {
      rows = rows.sublist(1);
    }

    final cats = await db.select(db.categories).get();
    final accs = await db.select(db.accounts).get();
    final catIds = {for (final c in cats) '${c.isIncome}|${c.name}': c.id};
    final accIds = {for (final a in accs) a.name: a.id};

    var count = 0;
    await db.transaction(() async {
      for (final r in rows) {
        if (r.length < 4) continue;
        final date = parseLooseDate(r[0]);
        final isIncome = r[1].trim() == '收入';
        final amount = int.tryParse(r[2].trim().replaceAll(',', ''));
        final catName = _clip(r[3].trim());
        if (date == null || amount == null || amount <= 0 || catName.isEmpty) {
          continue;
        }

        final catKey = '$isIncome|$catName';
        var catId = catIds[catKey];
        if (catId == null) {
          catId = await db.into(db.categories).insert(CategoriesCompanion.insert(
              name: catName, isIncome: Value(isIncome)));
          catIds[catKey] = catId;
        }

        int? accId;
        final accName = r.length > 4 ? _clip(r[4].trim()) : '';
        if (accName.isNotEmpty) {
          accId = accIds[accName];
          if (accId == null) {
            accId = await db
                .into(db.accounts)
                .insert(AccountsCompanion.insert(name: accName));
            accIds[accName] = accId;
          }
        }

        final noteText = r.length > 5 ? r[5].trim() : '';
        await db.into(db.entries).insert(EntriesCompanion.insert(
              amount: amount,
              categoryId: catId,
              date: date,
              accountId: Value(accId),
              note: Value(noteText.isEmpty ? null : noteText),
            ));
        count++;
      }
    });
    return count;
  }

  // ───────── JSON 完整備份 ─────────

  Future<String> exportJson() async {
    final data = <String, Object?>{
      'app': 'ledger',
      'schemaVersion': db.schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'accounts': [
        for (final x in await db.select(db.accounts).get()) x.toJson()
      ],
      'categories': [
        for (final x in await db.select(db.categories).get()) x.toJson()
      ],
      'entries': [for (final x in await db.select(db.entries).get()) x.toJson()],
      'debts': [for (final x in await db.select(db.debts).get()) x.toJson()],
      'recurrings': [
        for (final x in await db.select(db.recurrings).get()) x.toJson()
      ],
      'settings': [
        for (final x in await db.select(db.settings).get()) x.toJson()
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// 用備份檔覆蓋目前所有資料
  Future<void> importJson(String text) async {
    final data = jsonDecode(text);
    if (data is! Map<String, dynamic> || data['app'] != 'ledger') {
      throw const FormatException('這不是記帳本的備份檔');
    }
    List<Map<String, dynamic>> list(String key) =>
        ((data[key] as List?) ?? const []).cast<Map<String, dynamic>>();

    await db.transaction(() async {
      // 先刪有外鍵的，再刪被參照的
      await db.delete(db.entries).go();
      await db.delete(db.recurrings).go();
      await db.delete(db.debts).go();
      await db.delete(db.categories).go();
      await db.delete(db.accounts).go();
      await db.delete(db.settings).go();

      await db.batch((b) {
        b.insertAll(db.accounts, list('accounts').map(Account.fromJson));
        b.insertAll(db.categories, list('categories').map(TxCategory.fromJson));
        b.insertAll(db.entries, list('entries').map(Entry.fromJson));
        b.insertAll(db.debts, list('debts').map(Debt.fromJson));
        b.insertAll(db.recurrings, list('recurrings').map(Recurring.fromJson));
        b.insertAll(db.settings, list('settings').map(Setting.fromJson));
      });
    });
  }

  // ───────── 工具 ─────────

  static String _clip(String s) => s.length > 30 ? s.substring(0, 30) : s;

  static String _csvLine(List<String> fields) => fields.map((f) {
        if (f.contains(',') ||
            f.contains('"') ||
            f.contains('\n') ||
            f.contains('\r')) {
          return '"${f.replaceAll('"', '""')}"';
        }
        return f;
      }).join(',');
}

/// 簡單的 CSV 解析器，支援雙引號欄位和欄位內換行
List<List<String>> parseCsv(String input) {
  var text = input;
  if (text.startsWith('﻿')) text = text.substring(1);

  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(ch);
      }
    } else if (ch == '"') {
      inQuotes = true;
    } else if (ch == ',') {
      row.add(field.toString());
      field.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(ch);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows
      .where((r) => !(r.length == 1 && r.first.trim().isEmpty))
      .toList();
}

/// 接受 2026-11-12、2026/11/12、2026.11.12（可以帶時間）
DateTime? parseLooseDate(String s) {
  final parts = s.trim().split(RegExp(r'[-/.]'));
  if (parts.length < 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2].trim().split(RegExp(r'[ T]')).first);
  if (y == null || m == null || d == null) return null;
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  return DateTime(y, m, d, 12);
}
