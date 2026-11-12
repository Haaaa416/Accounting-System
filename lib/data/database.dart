import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

// ───────────────────────── 資料表 ─────────────────────────

/// 帳戶（現金、銀行、信用卡…）
@DataClassName('Account')
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  TextColumn get icon => text().withDefault(const Constant('wallet'))();
  IntColumn get color => integer().withDefault(const Constant(0xFFE6B450))();
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();
}

/// 分類。資料類別不叫 Category，因為 Flutter 本身已經有一個同名類別。
@DataClassName('TxCategory')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  BoolColumn get isIncome => boolean().withDefault(const Constant(false))();
  TextColumn get icon => text().withDefault(const Constant('other'))();
  IntColumn get color => integer().withDefault(const Constant(0xFF9CA3AF))();
  IntColumn get monthlyBudget => integer().nullable()(); // 只有支出分類會用到
}

/// 每一筆收支紀錄。金額以整數（元）儲存，避免浮點誤差。
@DataClassName('Entry')
class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get amount => integer()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
}

/// 欠款：別人欠我 / 我欠別人
@DataClassName('Debt')
class Debts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get person => text().withLength(min: 1, max: 30)();
  IntColumn get amount => integer()();
  BoolColumn get owedToMe => boolean()(); // true：別人欠我；false：我欠別人
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  BoolColumn get settled => boolean().withDefault(const Constant(false))();
}

/// 固定收支（房租、訂閱、薪水…），每月指定日期自動記一筆
@DataClassName('Recurring')
class Recurrings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get amount => integer()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
  IntColumn get dayOfMonth => integer()(); // 1–28
  TextColumn get note => text().nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get lastRun => dateTime().nullable()(); // 最後一次自動記帳的日期
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

/// 簡單的設定值（主題、總預算…）
@DataClassName('Setting')
class Settings extends Table {
  TextColumn get settingKey => text()();
  TextColumn get settingValue => text()();

  @override
  Set<Column> get primaryKey => {settingKey};
}

// ───────────────────────── 顯示用的組合類別 ─────────────────────────

class EntryView {
  const EntryView(this.entry, this.category, this.account);
  final Entry entry;
  final TxCategory category;
  final Account? account;

  bool get isIncome => category.isIncome;

  /// 收入為正、支出為負
  int get signed => isIncome ? entry.amount : -entry.amount;
}

class AccountWithBalance {
  const AccountWithBalance(this.account, this.balance);
  final Account account;
  final int balance;
}

class RecurringView {
  const RecurringView(this.recurring, this.category, this.account);
  final Recurring recurring;
  final TxCategory category;
  final Account? account;
}

// ───────────────────────── 預設資料 ─────────────────────────

const _defaultExpense = [
  ('餐飲', 'food', 0xFFF59E0B),
  ('交通', 'transport', 0xFF60A5FA),
  ('購物', 'shopping', 0xFFF472B6),
  ('娛樂', 'fun', 0xFFA78BFA),
  ('居住', 'home', 0xFF34D399),
  ('醫療', 'health', 0xFFF87171),
  ('其他', 'other', 0xFF9CA3AF),
];

const _defaultIncome = [
  ('薪水', 'salary', 0xFF34D399),
  ('獎金', 'gift', 0xFFE6B450),
  ('其他收入', 'other', 0xFF9CA3AF),
];

// ───────────────────────── 資料庫 ─────────────────────────

@DriftDatabase(
    tables: [Accounts, Categories, Entries, Debts, Recurrings, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  // v1：分類、紀錄
  // v2：欠款
  // v3：帳戶、分類圖示／顏色／預算、固定收支、設定
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedAccounts();
          await batch((b) {
            b.insertAll(categories, [
              for (final (name, icon, color) in _defaultExpense)
                CategoriesCompanion.insert(
                    name: name, icon: Value(icon), color: Value(color)),
              for (final (name, icon, color) in _defaultIncome)
                CategoriesCompanion.insert(
                  name: name,
                  isIncome: const Value(true),
                  icon: Value(icon),
                  color: Value(color),
                ),
            ]);
          });
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(debts);
          }
          if (from < 3) {
            await m.createTable(accounts);
            await m.createTable(recurrings);
            await m.createTable(settings);
            await m.addColumn(categories, categories.icon);
            await m.addColumn(categories, categories.color);
            await m.addColumn(categories, categories.monthlyBudget);
            await m.addColumn(entries, entries.accountId);
            await _seedAccounts();
            // 舊紀錄全部歸到第一個帳戶「現金」
            await customStatement('UPDATE entries SET account_id = 1');
            // 預設分類套上圖示和顏色
            for (final (name, icon, color) in [
              ..._defaultExpense,
              ..._defaultIncome
            ]) {
              await (update(categories)..where((c) => c.name.equals(name)))
                  .write(CategoriesCompanion(
                      icon: Value(icon), color: Value(color)));
            }
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _seedAccounts() => batch((b) {
        b.insertAll(accounts, [
          AccountsCompanion.insert(
              name: '現金',
              icon: const Value('wallet'),
              color: const Value(0xFFE6B450)),
          AccountsCompanion.insert(
              name: '銀行',
              icon: const Value('bank'),
              color: const Value(0xFF60A5FA)),
          AccountsCompanion.insert(
              name: '信用卡',
              icon: const Value('card'),
              color: const Value(0xFFF472B6)),
        ]);
      });

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'ledger',
      // Web 版需要把這兩個檔案放進 web/ 資料夾（見 README）
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }

  // ───────── 設定 ─────────

  Stream<String?> watchSetting(String key) =>
      (select(settings)..where((s) => s.settingKey.equals(key)))
          .watchSingleOrNull()
          .map((s) => s?.settingValue);

  Future<String?> getSetting(String key) async =>
      (await (select(settings)..where((s) => s.settingKey.equals(key)))
              .getSingleOrNull())
          ?.settingValue;

  Future<void> setSetting(String key, String? value) async {
    if (value == null) {
      await (delete(settings)..where((s) => s.settingKey.equals(key))).go();
    } else {
      await into(settings).insertOnConflictUpdate(
          SettingsCompanion.insert(settingKey: key, settingValue: value));
    }
  }

  // ───────── 帳戶 ─────────

  Stream<List<Account>> watchAccounts() =>
      (select(accounts)..orderBy([(a) => OrderingTerm(expression: a.id)]))
          .watch();

  /// 每個帳戶的目前餘額 = 初始金額 + 收入 − 支出
  Stream<List<AccountWithBalance>> watchAccountBalances() {
    return customSelect(
      'SELECT a.id, a.name, a.icon, a.color, a.initial_balance, '
      'a.initial_balance + COALESCE(SUM(CASE WHEN c.is_income = 1 '
      'THEN e.amount ELSE -e.amount END), 0) AS balance '
      'FROM accounts a '
      'LEFT JOIN entries e ON e.account_id = a.id '
      'LEFT JOIN categories c ON c.id = e.category_id '
      'GROUP BY a.id ORDER BY a.id',
      readsFrom: {accounts, entries, categories},
    ).watch().map((rows) => rows
        .map((r) => AccountWithBalance(
              Account(
                id: r.read<int>('id'),
                name: r.read<String>('name'),
                icon: r.read<String>('icon'),
                color: r.read<int>('color'),
                initialBalance: r.read<int>('initial_balance'),
              ),
              r.read<int>('balance'),
            ))
        .toList());
  }

  Future<int> addAccount(AccountsCompanion a) => into(accounts).insert(a);

  Future<bool> updateAccount(Account a) => update(accounts).replace(a);

  /// 沒有任何紀錄或固定收支使用的帳戶才能刪除
  Future<bool> deleteAccountIfUnused(int id) async {
    final usedByEntry = await (select(entries)
          ..where((e) => e.accountId.equals(id))
          ..limit(1))
        .getSingleOrNull();
    final usedByRecurring = await (select(recurrings)
          ..where((r) => r.accountId.equals(id))
          ..limit(1))
        .getSingleOrNull();
    if (usedByEntry != null || usedByRecurring != null) return false;
    await (delete(accounts)..where((a) => a.id.equals(id))).go();
    return true;
  }

  // ───────── 分類 ─────────

  Stream<List<TxCategory>> watchCategories() =>
      (select(categories)..orderBy([(c) => OrderingTerm(expression: c.id)]))
          .watch();

  Future<int> addCategory(CategoriesCompanion c) => into(categories).insert(c);

  Future<bool> updateCategory(TxCategory c) => update(categories).replace(c);

  /// 沒有任何紀錄或固定收支使用的分類才能刪除
  Future<bool> deleteCategoryIfUnused(int id) async {
    final usedByEntry = await (select(entries)
          ..where((e) => e.categoryId.equals(id))
          ..limit(1))
        .getSingleOrNull();
    final usedByRecurring = await (select(recurrings)
          ..where((r) => r.categoryId.equals(id))
          ..limit(1))
        .getSingleOrNull();
    if (usedByEntry != null || usedByRecurring != null) return false;
    await (delete(categories)..where((c) => c.id.equals(id))).go();
    return true;
  }

  // ───────── 紀錄 ─────────

  JoinedSelectStatement<HasResultSet, dynamic> _entryQuery() {
    return select(entries).join([
      innerJoin(categories, categories.id.equalsExp(entries.categoryId)),
      leftOuterJoin(accounts, accounts.id.equalsExp(entries.accountId)),
    ])
      ..orderBy([OrderingTerm.desc(entries.date), OrderingTerm.desc(entries.id)]);
  }

  List<EntryView> _toViews(List<TypedResult> rows) => rows
      .map((r) => EntryView(
            r.readTable(entries),
            r.readTable(categories),
            r.readTableOrNull(accounts),
          ))
      .toList();

  Stream<List<EntryView>> watchEntriesBetween(DateTime start, DateTime end) {
    final q = _entryQuery()
      ..where(entries.date.isBiggerOrEqualValue(start) &
          entries.date.isSmallerThanValue(end));
    return q.watch().map(_toViews);
  }

  Stream<List<EntryView>> watchEntriesInMonth(DateTime month) =>
      watchEntriesBetween(DateTime(month.year, month.month),
          DateTime(month.year, month.month + 1));

  Stream<List<EntryView>> watchAllEntries() =>
      _entryQuery().watch().map(_toViews);

  Future<List<EntryView>> getAllEntries() async =>
      _toViews(await _entryQuery().get());

  Future<int> addEntry(EntriesCompanion e) => into(entries).insert(e);

  Future<bool> updateEntry(Entry e) => update(entries).replace(e);

  Future<int> deleteEntry(int id) =>
      (delete(entries)..where((e) => e.id.equals(id))).go();

  // ───────── 欠款 ─────────

  /// 全部欠款，未結清的排前面，同一組內新的在前
  Stream<List<Debt>> watchDebts() => (select(debts)
        ..orderBy([
          (d) => OrderingTerm(expression: d.settled),
          (d) => OrderingTerm.desc(d.date),
          (d) => OrderingTerm.desc(d.id),
        ]))
      .watch();

  Future<int> addDebt(DebtsCompanion d) => into(debts).insert(d);

  Future<bool> updateDebt(Debt d) => update(debts).replace(d);

  Future<int> deleteDebt(int id) =>
      (delete(debts)..where((d) => d.id.equals(id))).go();

  Future<int> setDebtSettled(int id, bool settled) =>
      (update(debts)..where((d) => d.id.equals(id)))
          .write(DebtsCompanion(settled: Value(settled)));

  // ───────── 固定收支 ─────────

  Stream<List<RecurringView>> watchRecurrings() {
    final q = select(recurrings).join([
      innerJoin(categories, categories.id.equalsExp(recurrings.categoryId)),
      leftOuterJoin(accounts, accounts.id.equalsExp(recurrings.accountId)),
    ])
      ..orderBy([OrderingTerm(expression: recurrings.dayOfMonth)]);
    return q.watch().map((rows) => rows
        .map((r) => RecurringView(
              r.readTable(recurrings),
              r.readTable(categories),
              r.readTableOrNull(accounts),
            ))
        .toList());
  }

  Future<int> addRecurring(RecurringsCompanion r) =>
      into(recurrings).insert(r);

  Future<bool> updateRecurring(Recurring r) => update(recurrings).replace(r);

  Future<int> deleteRecurring(int id) =>
      (delete(recurrings)..where((r) => r.id.equals(id))).go();

  /// 把到期的固定收支補記成紀錄，回傳新增的筆數。
  /// App 啟動時、以及新增／修改固定收支後會呼叫。
  Future<int> runRecurring({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final list =
        await (select(recurrings)..where((r) => r.active.equals(true))).get();
    var created = 0;
    await transaction(() async {
      for (final r in list) {
        var due = _nextDue(r);
        DateTime? last;
        while (!due.isAfter(today)) {
          await into(entries).insert(EntriesCompanion.insert(
            amount: r.amount,
            categoryId: r.categoryId,
            date: due,
            accountId: Value(r.accountId),
            note: Value(r.note),
          ));
          last = due;
          created++;
          due = DateTime(due.year, due.month + 1, r.dayOfMonth, 12);
        }
        if (last != null) {
          await (update(recurrings)..where((x) => x.id.equals(r.id)))
              .write(RecurringsCompanion(lastRun: Value(last)));
        }
      }
    });
    return created;
  }

  DateTime _nextDue(Recurring r) {
    final last = r.lastRun;
    if (last != null) {
      return DateTime(last.year, last.month + 1, r.dayOfMonth, 12);
    }
    final s = r.startDate;
    final first = DateTime(s.year, s.month, r.dayOfMonth, 12);
    // 開始日當月的扣款日已經過了，就從下個月開始
    return r.dayOfMonth < s.day
        ? DateTime(s.year, s.month + 1, r.dayOfMonth, 12)
        : first;
  }
}
