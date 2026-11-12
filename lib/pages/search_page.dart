import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/database.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'edit_entry_page.dart';

/// 搜尋與篩選所有紀錄
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  String _query = '';
  bool? _income; // null = 全部
  int? _catId;
  int? _accId;

  late final Stream<List<EntryView>> _entries = db.watchAllEntries();
  late final Stream<List<TxCategory>> _cats = db.watchCategories();
  late final Stream<List<Account>> _accs = db.watchAccounts();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool _match(EntryView v) {
    if (_income != null && v.isIncome != _income) return false;
    if (_catId != null && v.category.id != _catId) return false;
    if (_accId != null && v.entry.accountId != _accId) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (int.tryParse(q) == v.entry.amount) return true;
    return (v.entry.note ?? '').toLowerCase().contains(q) ||
        v.category.name.toLowerCase().contains(q) ||
        (v.account?.name ?? '').toLowerCase().contains(q);
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => onTap(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(
            hintText: '搜尋備註、分類、帳戶或金額',
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() {
                _ctrl.clear();
                _query = '';
              }),
            ),
        ],
      ),
      body: Column(
        children: [
          // 篩選列
          StreamBuilder<List<TxCategory>>(
            stream: _cats,
            builder: (context, catSnap) => StreamBuilder<List<Account>>(
              stream: _accs,
              builder: (context, accSnap) {
                final cats = (catSnap.data ?? const <TxCategory>[])
                    .where((c) => _income == null || c.isIncome == _income)
                    .toList();
                final accs = accSnap.data ?? const <Account>[];
                Widget row(List<Widget> children) => SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: children,
                      ),
                    );
                return Column(
                  children: [
                    row([
                      _chip('全部', _income == null, () => setState(() {
                            _income = null;
                          })),
                      _chip('支出', _income == false, () => setState(() {
                            _income = false;
                            _catId = null;
                          })),
                      _chip('收入', _income == true, () => setState(() {
                            _income = true;
                            _catId = null;
                          })),
                      const SizedBox(width: 8),
                      for (final a in accs)
                        _chip(a.name, _accId == a.id, () => setState(() {
                              _accId = _accId == a.id ? null : a.id;
                            })),
                    ]),
                    row([
                      for (final c in cats)
                        _chip(c.name, _catId == c.id, () => setState(() {
                              _catId = _catId == c.id ? null : c.id;
                            })),
                    ]),
                  ],
                );
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<List<EntryView>>(
              stream: _entries,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final results = snapshot.data!.where(_match).toList();
                if (results.isEmpty) {
                  return const EmptyHint('找不到符合的紀錄',
                      icon: Icons.search_off_rounded);
                }
                var income = 0;
                var expense = 0;
                for (final v in results) {
                  if (v.isIncome) {
                    income += v.entry.amount;
                  } else {
                    expense += v.entry.amount;
                  }
                }
                return ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Text(
                        '共 ${results.length} 筆　收入 ${formatMoney(income)}　支出 ${formatMoney(expense)}',
                        style: moneyStyle(
                            13, FontWeight.w500, scheme.onSurfaceVariant),
                      ),
                    ),
                    for (final v in results)
                      EntryTile(
                        view: v,
                        showDate: true,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => EditEntryPage(existing: v)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
