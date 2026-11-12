import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/database.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// 分類管理（支出／收入兩個分頁）
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  late final Stream<List<TxCategory>> _stream = db.watchCategories();

  void _openEditor({TxCategory? existing, bool isIncome = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditCategoryPage(existing: existing, isIncome: isIncome),
      ),
    );
  }

  Widget _list(List<TxCategory> cats) {
    if (cats.isEmpty) return const EmptyHint('沒有分類');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        Card(
          child: Column(
            children: [
              for (var i = 0; i < cats.length; i++) ...[
                if (i > 0) const Divider(indent: 72),
                ListTile(
                  leading:
                      CategoryAvatar(icon: cats[i].icon, color: cats[i].color),
                  title: Text(cats[i].name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: cats[i].monthlyBudget == null
                      ? null
                      : Text('每月預算 ${formatMoney(cats[i].monthlyBudget!)}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openEditor(existing: cats[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('分類與圖示'),
          bottom: const TabBar(tabs: [Tab(text: '支出'), Tab(text: '收入')]),
        ),
        body: StreamBuilder<List<TxCategory>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final all = snapshot.data!;
            return TabBarView(
              children: [
                _list(all.where((c) => !c.isIncome).toList()),
                _list(all.where((c) => c.isIncome).toList()),
              ],
            );
          },
        ),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
            tooltip: '新增分類',
            onPressed: () => _openEditor(
                isIncome: DefaultTabController.of(context).index == 1),
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ),
    );
  }
}

/// 新增或編輯分類：名稱、圖示、顏色、每月預算
class EditCategoryPage extends StatefulWidget {
  const EditCategoryPage({super.key, this.existing, this.isIncome = false});

  final TxCategory? existing;
  final bool isIncome;

  @override
  State<EditCategoryPage> createState() => _EditCategoryPageState();
}

class _EditCategoryPageState extends State<EditCategoryPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _budgetCtrl;
  late bool _isIncome;
  late String _icon;
  late int _color;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _budgetCtrl =
        TextEditingController(text: c?.monthlyBudget?.toString() ?? '');
    _isIncome = c?.isIncome ?? widget.isIncome;
    _icon = c?.icon ?? 'other';
    _color = c?.color ?? 0xFFE6B450;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showSnack(context, '請輸入分類名稱');
      return;
    }
    final b = int.tryParse(_budgetCtrl.text.trim());
    final budget = (_isIncome || b == null || b <= 0) ? null : b;

    final existing = widget.existing;
    if (existing == null) {
      await db.addCategory(CategoriesCompanion.insert(
        name: name,
        isIncome: Value(_isIncome),
        icon: Value(_icon),
        color: Value(_color),
        monthlyBudget: Value(budget),
      ));
    } else {
      await db.updateCategory(existing.copyWith(
        name: name,
        icon: _icon,
        color: _color,
        monthlyBudget: Value(budget),
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDialog(context, '刪除這個分類？')) return;
    final ok = await db.deleteCategoryIfUnused(widget.existing!.id);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      showSnack(context, '這個分類已經有紀錄在使用，無法刪除');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '編輯分類' : '新增分類'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: '刪除',
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(child: CategoryAvatar(icon: _icon, color: _color, size: 72)),
          const SizedBox(height: 24),
          if (!_isEditing) ...[
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('支出')),
                ButtonSegment(value: true, label: Text('收入')),
              ],
              selected: {_isIncome},
              onSelectionChanged: (s) => setState(() => _isIncome = s.first),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _nameCtrl,
            maxLength: 30,
            decoration: const InputDecoration(labelText: '分類名稱'),
          ),
          if (!_isIncome) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _budgetCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '每月預算（選填）',
                prefixText: '\$ ',
                helperText: '超過時首頁會提醒你',
              ),
            ),
          ],
          const SizedBox(height: 24),
          IconColorPicker(
            icon: _icon,
            color: _color,
            onIcon: (v) => setState(() => _icon = v),
            onColor: (v) => setState(() => _color = v),
          ),
          const SizedBox(height: 28),
          FilledButton(onPressed: _save, child: const Text('儲存')),
        ],
      ),
    );
  }
}
