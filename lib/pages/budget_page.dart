import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/database.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// 預算設定：每月總預算 + 各分類預算，顯示本月進度
class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  late final Stream<String?> _totalStream = db.watchSetting('budget_total');
  late final Stream<List<TxCategory>> _catStream = db.watchCategories();
  late final Stream<List<EntryView>> _entryStream = db.watchEntriesInMonth(
      DateTime(DateTime.now().year, DateTime.now().month));

  Future<void> _editTotal(int? current) async {
    final r = await amountDialog(context, '每月總預算', initial: current);
    if (r == null) return;
    await db.setSetting('budget_total', r.value?.toString());
  }

  Future<void> _editCategory(TxCategory c) async {
    final r = await amountDialog(context, '「${c.name}」每月預算',
        initial: c.monthlyBudget);
    if (r == null) return;
    await db.updateCategory(c.copyWith(monthlyBudget: Value(r.value)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('預算')),
      body: StreamBuilder<String?>(
        stream: _totalStream,
        builder: (context, totalSnap) => StreamBuilder<List<TxCategory>>(
          stream: _catStream,
          builder: (context, catSnap) => StreamBuilder<List<EntryView>>(
            stream: _entryStream,
            builder: (context, entrySnap) {
              if (!catSnap.hasData || !entrySnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final total = int.tryParse(totalSnap.data ?? '');
              final cats = catSnap.data!.where((c) => !c.isIncome).toList();
              final spentByCat = <int, int>{};
              var spentAll = 0;
              for (final v in entrySnap.data!.where((v) => !v.isIncome)) {
                spentByCat[v.category.id] =
                    (spentByCat[v.category.id] ?? 0) + v.entry.amount;
                spentAll += v.entry.amount;
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Card(
                    child: InkWell(
                      onTap: () => _editTotal(total),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text('每月總預算',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16)),
                                ),
                                Icon(Icons.edit_rounded,
                                    size: 18, color: scheme.onSurfaceVariant),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (total == null)
                              Text('尚未設定，點這裡設定',
                                  style:
                                      TextStyle(color: scheme.onSurfaceVariant))
                            else ...[
                              Text(
                                '${formatMoney(spentAll)} / ${formatMoney(total)}',
                                style: moneyStyle(
                                    22, FontWeight.w800, scheme.onSurface),
                              ),
                              const SizedBox(height: 10),
                              BudgetBar(spent: spentAll, budget: total),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SectionHeader('分類預算'),
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < cats.length; i++) ...[
                          if (i > 0) const Divider(indent: 72),
                          _CategoryBudgetTile(
                            category: cats[i],
                            spent: spentByCat[cats[i].id] ?? 0,
                            onTap: () => _editCategory(cats[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '點任一項目設定預算。超過分類預算時，明細頁最上方會出現提醒。',
                    style:
                        TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CategoryBudgetTile extends StatelessWidget {
  const _CategoryBudgetTile({
    required this.category,
    required this.spent,
    required this.onTap,
  });

  final TxCategory category;
  final int spent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final budget = category.monthlyBudget;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CategoryAvatar(icon: category.icon, color: category.color),
      title: Row(
        children: [
          Expanded(
            child: Text(category.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text(
            budget == null
                ? '未設定'
                : '${formatMoney(spent)} / ${formatMoney(budget)}',
            style: moneyStyle(13, FontWeight.w500,
                budget != null && spent > budget
                    ? expenseColor(context)
                    : scheme.onSurfaceVariant),
          ),
        ],
      ),
      subtitle: budget == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 8),
              child: BudgetBar(spent: spent, budget: budget),
            ),
      onTap: onTap,
    );
  }
}
