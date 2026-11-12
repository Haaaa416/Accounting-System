import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/database.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'edit_entry_page.dart';
import 'search_page.dart';

/// 明細：每月收支、預算提醒、依日期分組的紀錄
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late DateTime _month;
  late Stream<List<EntryView>> _stream;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _setMonth(DateTime(now.year, now.month), notify: false);
  }

  void _setMonth(DateTime m, {bool notify = true}) {
    _month = m;
    _stream = db.watchEntriesInMonth(m);
    if (notify) setState(() {});
  }

  void _openEditor([EntryView? existing]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditEntryPage(existing: existing)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('記帳本'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: '搜尋',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchPage()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<List<EntryView>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('讀取失敗：${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;

          var income = 0;
          var expense = 0;
          for (final v in items) {
            if (v.isIncome) {
              income += v.entry.amount;
            } else {
              expense += v.entry.amount;
            }
          }

          // 依日期分組（已經是新到舊排序）
          final groups = <DateTime, List<EntryView>>{};
          for (final v in items) {
            final d = v.entry.date;
            groups.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(v);
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 110),
            children: [
              MonthSwitcher(month: _month, onChanged: _setMonth),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _HeroCard(month: _month, income: income, expense: expense),
              ),
              _BudgetSection(items: items, expense: expense),
              if (items.isEmpty)
                const EmptyHint('這個月還沒有紀錄，按右下角開始記帳')
              else
                for (final g in groups.entries)
                  _DayGroup(
                    day: g.key,
                    items: g.value,
                    onTap: _openEditor,
                  ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-home',
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('記一筆',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }
}

/// 最上面的大卡片：本月支出、收入、結餘
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.month,
    required this.income,
    required this.expense,
  });

  final DateTime month;
  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = isDark(context);
    final balance = income - expense;

    Widget mini(String label, Widget value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            value,
          ],
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF2B2416), Color(0xFF141922)]
              : const [Color(0xFFFFF3D6), Colors.white],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${month.month} 月支出',
              style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 1,
                  color: scheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(formatMoney(expense),
              style: moneyStyle(36, FontWeight.w800, scheme.onSurface)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: mini('收入',
                    MoneyText(income, color: incomeColor(context), fontSize: 17)),
              ),
              Expanded(
                child: mini(
                  '結餘',
                  MoneyText(balance,
                      color: balance < 0 ? expenseColor(context) : scheme.primary,
                      fontSize: 17),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 預算進度與超支提醒（沒有設定預算時不顯示）
class _BudgetSection extends StatefulWidget {
  const _BudgetSection({required this.items, required this.expense});

  final List<EntryView> items;
  final int expense;

  @override
  State<_BudgetSection> createState() => _BudgetSectionState();
}

class _BudgetSectionState extends State<_BudgetSection> {
  late final Stream<String?> _totalStream = db.watchSetting('budget_total');
  late final Stream<List<TxCategory>> _catStream = db.watchCategories();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: _totalStream,
      builder: (context, totalSnap) {
        final total = int.tryParse(totalSnap.data ?? '');
        return StreamBuilder<List<TxCategory>>(
          stream: _catStream,
          builder: (context, catSnap) {
            final cats = catSnap.data ?? const <TxCategory>[];

            // 各分類本月花費
            final spentByCat = <int, int>{};
            for (final v in widget.items.where((v) => !v.isIncome)) {
              spentByCat[v.category.id] =
                  (spentByCat[v.category.id] ?? 0) + v.entry.amount;
            }
            final over = [
              for (final c in cats)
                if (!c.isIncome &&
                    c.monthlyBudget != null &&
                    (spentByCat[c.id] ?? 0) > c.monthlyBudget!)
                  (c, (spentByCat[c.id] ?? 0) - c.monthlyBudget!),
            ];

            if (total == null && over.isEmpty) return const SizedBox(height: 4);

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  if (total != null) _totalCard(context, total),
                  for (final (c, amount) in over)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _warning(context,
                          '「${c.name}」超出預算 ${formatMoney(amount)}'),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _totalCard(BuildContext context, int total) {
    final scheme = Theme.of(context).colorScheme;
    final spent = widget.expense;
    final left = total - spent;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('本月預算',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${formatMoney(spent)} / ${formatMoney(total)}',
                    style: moneyStyle(
                        13, FontWeight.w500, scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 10),
            BudgetBar(spent: spent, budget: total),
            const SizedBox(height: 8),
            Text(
              left >= 0 ? '還可以花 ${formatMoney(left)}' : '已超出 ${formatMoney(-left)}',
              style: TextStyle(
                fontSize: 12,
                color: left >= 0 ? scheme.onSurfaceVariant : expenseColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _warning(BuildContext context, String text) {
    final c = expenseColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: c, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: c))),
        ],
      ),
    );
  }
}

/// 同一天的紀錄放在一張卡片裡
class _DayGroup extends StatelessWidget {
  const _DayGroup({required this.day, required this.items, required this.onTap});

  final DateTime day;
  final List<EntryView> items;
  final void Function(EntryView) onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final net = items.fold<int>(0, (s, v) => s + v.signed);
    final today = isSameDay(day, DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Card(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    today ? '今天' : formatDay(day),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    net >= 0 ? '+${formatMoney(net)}' : '−${formatMoney(-net)}',
                    style: moneyStyle(
                        13, FontWeight.w500, scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const Divider(),
            for (final v in items)
              Dismissible(
                key: ValueKey('entry-${v.entry.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: expenseColor(context).withValues(alpha: 0.85),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: const Icon(Icons.delete_rounded, color: Colors.white),
                ),
                confirmDismiss: (_) => confirmDialog(context, '刪除這筆紀錄？'),
                onDismissed: (_) => db.deleteEntry(v.entry.id),
                child: EntryTile(view: v, onTap: () => onTap(v)),
              ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
