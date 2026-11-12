import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/database.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// 統計：分類圓餅圖 + 近六個月收支趨勢
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  late DateTime _month;
  bool _income = false;
  late Stream<List<EntryView>> _monthStream;
  late Stream<List<EntryView>> _trendStream;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _setMonth(DateTime(now.year, now.month), notify: false);
  }

  void _setMonth(DateTime m, {bool notify = true}) {
    _month = m;
    _monthStream = db.watchEntriesInMonth(m);
    _trendStream = db.watchEntriesBetween(
        DateTime(m.year, m.month - 5), DateTime(m.year, m.month + 1));
    if (notify) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('統計')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          MonthSwitcher(month: _month, onChanged: _setMonth),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('支出')),
                ButtonSegment(value: true, label: Text('收入')),
              ],
              selected: {_income},
              onSelectionChanged: (s) => setState(() => _income = s.first),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StreamBuilder<List<EntryView>>(
              stream: _monthStream,
              builder: (context, snap) => _BreakdownCard(
                income: _income,
                items: (snap.data ?? const <EntryView>[])
                    .where((v) => v.isIncome == _income)
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StreamBuilder<List<EntryView>>(
              stream: _trendStream,
              builder: (context, snap) => _TrendCard(
                month: _month,
                items: snap.data ?? const <EntryView>[],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 分類佔比
class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.income, required this.items});

  final bool income;
  final List<EntryView> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final totals = <int, (TxCategory, int)>{};
    for (final v in items) {
      final cur = totals[v.category.id];
      totals[v.category.id] = (v.category, (cur?.$2 ?? 0) + v.entry.amount);
    }
    final list = totals.values.toList()..sort((a, b) => b.$2.compareTo(a.$2));
    final sum = list.fold<int>(0, (s, e) => s + e.$2);

    if (sum == 0) {
      return const Card(
        child: EmptyHint('這個月沒有資料', icon: Icons.pie_chart_outline_rounded),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(
              height: 210,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 72,
                      startDegreeOffset: -90,
                      sections: [
                        for (final (c, amount) in list)
                          PieChartSectionData(
                            value: amount.toDouble(),
                            color: Color(c.color),
                            radius: 22,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(income ? '總收入' : '總支出',
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(formatMoney(sum),
                          style:
                              moneyStyle(24, FontWeight.w800, scheme.onSurface)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            for (final (c, amount) in list)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    CategoryAvatar(icon: c.icon, color: c.color, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(c.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ),
                              MoneyText(amount, fontSize: 14),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: amount / sum,
                              minHeight: 6,
                              color: Color(c.color),
                              backgroundColor: scheme.surfaceContainerHigh,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${(amount * 100 / sum).toStringAsFixed(1)}%',
                        textAlign: TextAlign.end,
                        style: moneyStyle(
                            12, FontWeight.w500, scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 近六個月收入／支出長條圖
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.month, required this.items});

  final DateTime month;
  final List<EntryView> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inc = incomeColor(context);
    final exp = expenseColor(context);

    final months = [
      for (var i = 5; i >= 0; i--) DateTime(month.year, month.month - i),
    ];
    final incomes = List<int>.filled(6, 0);
    final expenses = List<int>.filled(6, 0);
    for (final v in items) {
      final d = v.entry.date;
      final i = months.indexWhere((m) => m.year == d.year && m.month == d.month);
      if (i < 0) continue;
      if (v.isIncome) {
        incomes[i] += v.entry.amount;
      } else {
        expenses[i] += v.entry.amount;
      }
    }
    final maxValue =
        [...incomes, ...expenses].fold<int>(0, (a, b) => math.max(a, b));
    final maxY = maxValue == 0 ? 1.0 : maxValue * 1.15;

    final avgExpense = expenses.fold<int>(0, (a, b) => a + b) ~/ 6;

    Widget legend(Color c, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: c, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 6),
            Text(text,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('近六個月',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                legend(inc, '收入'),
                const SizedBox(width: 14),
                legend(exp, '支出'),
              ],
            ),
            const SizedBox(height: 4),
            Text('平均每月支出 ${formatMoney(avgExpense)}',
                style: moneyStyle(12, FontWeight.w500, scheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  alignment: BarChartAlignment.spaceAround,
                  barTouchData: BarTouchData(enabled: false),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= months.length) {
                            return const SizedBox.shrink();
                          }
                          final current = i == months.length - 1;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${months[i].month}月',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    current ? FontWeight.w700 : FontWeight.w400,
                                color: current
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < 6; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 4,
                        barRods: [
                          BarChartRodData(
                            toY: incomes[i].toDouble(),
                            color: inc,
                            width: 10,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                          BarChartRodData(
                            toY: expenses[i].toDouble(),
                            color: exp,
                            width: 10,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
