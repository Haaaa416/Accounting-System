import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../data/database.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// 固定收支列表
class RecurringPage extends StatefulWidget {
  const RecurringPage({super.key});

  @override
  State<RecurringPage> createState() => _RecurringPageState();
}

class _RecurringPageState extends State<RecurringPage> {
  late final Stream<List<RecurringView>> _stream = db.watchRecurrings();

  void _openEditor([RecurringView? existing]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditRecurringPage(existing: existing)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('固定收支')),
      body: StreamBuilder<List<RecurringView>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data!;
          var monthlyIn = 0;
          var monthlyOut = 0;
          for (final v in list.where((v) => v.recurring.active)) {
            if (v.category.isIncome) {
              monthlyIn += v.recurring.amount;
            } else {
              monthlyOut += v.recurring.amount;
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('每月固定收入',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant)),
                            const SizedBox(height: 4),
                            MoneyText(monthlyIn,
                                color: incomeColor(context), fontSize: 18),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('每月固定支出',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant)),
                            const SizedBox(height: 4),
                            MoneyText(monthlyOut,
                                color: expenseColor(context), fontSize: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                const EmptyHint('還沒有固定收支\n例如房租、訂閱、薪水',
                    icon: Icons.event_repeat_rounded)
              else
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0) const Divider(indent: 72),
                        _tile(list[i]),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                '每次開啟 App 時，到期的項目會自動記成一筆紀錄。',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '新增固定收支',
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _tile(RecurringView v) {
    final r = v.recurring;
    final account = v.account;
    final note = r.note;
    return Opacity(
      opacity: r.active ? 1 : 0.45,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CategoryAvatar(icon: v.category.icon, color: v.category.color),
        title: Text(note ?? v.category.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([
          '每月 ${r.dayOfMonth} 日',
          if (note != null) v.category.name,
          if (account != null) account.name,
          if (!r.active) '已暫停',
        ].join(' · ')),
        trailing: MoneyText(r.amount, isIncome: v.category.isIncome),
        onTap: () => _openEditor(v),
      ),
    );
  }
}

/// 新增或編輯固定收支
class EditRecurringPage extends StatefulWidget {
  const EditRecurringPage({super.key, this.existing});

  final RecurringView? existing;

  @override
  State<EditRecurringPage> createState() => _EditRecurringPageState();
}

class _EditRecurringPageState extends State<EditRecurringPage> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late bool _isIncome;
  int? _categoryId;
  int? _accountId;
  bool _accountInitialized = false;
  late int _day;
  late DateTime _startDate;
  late bool _active;

  late final Stream<List<TxCategory>> _catStream = db.watchCategories();
  late final Stream<List<Account>> _accStream = db.watchAccounts();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final v = widget.existing;
    final r = v?.recurring;
    _amountCtrl = TextEditingController(text: r?.amount.toString() ?? '');
    _noteCtrl = TextEditingController(text: r?.note ?? '');
    _isIncome = v?.category.isIncome ?? false;
    _categoryId = r?.categoryId;
    _accountId = r?.accountId;
    _accountInitialized = v != null;
    final now = DateTime.now();
    _day = r?.dayOfMonth ?? (now.day > 28 ? 28 : now.day);
    _startDate = r?.startDate ?? DateTime(now.year, now.month, now.day);
    _active = r?.active ?? true;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      showSnack(context, '請輸入大於 0 的金額');
      return;
    }
    final categoryId = _categoryId;
    if (categoryId == null) {
      showSnack(context, '請選擇分類');
      return;
    }
    final noteText = _noteCtrl.text.trim();
    final note = noteText.isEmpty ? null : noteText;

    final existing = widget.existing?.recurring;
    if (existing == null) {
      await db.addRecurring(RecurringsCompanion.insert(
        amount: amount,
        categoryId: categoryId,
        accountId: Value(_accountId),
        dayOfMonth: _day,
        note: Value(note),
        startDate: _startDate,
      ));
    } else {
      // 已經自動記過的月份不會重記（lastRun 保持不變）
      await db.updateRecurring(existing.copyWith(
        amount: amount,
        categoryId: categoryId,
        accountId: Value(_accountId),
        dayOfMonth: _day,
        note: Value(note),
        startDate: _startDate,
        active: _active,
      ));
    }
    final created = await db.runRecurring();
    if (!mounted) return;
    if (created > 0) showSnack(context, '已自動補記 $created 筆紀錄');
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDialog(context, '刪除這個固定收支？',
        message: '已經自動記下的紀錄會保留。')) {
      return;
    }
    await db.deleteRecurring(widget.existing!.recurring.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _isIncome ? incomeColor(context) : expenseColor(context);
    final label = TextStyle(
        fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '編輯固定收支' : '新增固定收支'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: '刪除',
              onPressed: _delete,
            ),
        ],
      ),
      body: StreamBuilder<List<TxCategory>>(
        stream: _catStream,
        builder: (context, catSnap) => StreamBuilder<List<Account>>(
          stream: _accStream,
          builder: (context, accSnap) {
            if (!catSnap.hasData || !accSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final cats =
                catSnap.data!.where((c) => c.isIncome == _isIncome).toList();
            final accounts = accSnap.data!;
            if (!_accountInitialized) {
              _accountId = accounts.isEmpty ? null : accounts.first.id;
              _accountInitialized = true;
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('支出')),
                    ButtonSegment(value: true, label: Text('收入')),
                  ],
                  selected: {_isIncome},
                  onSelectionChanged: (s) => setState(() {
                    _isIncome = s.first;
                    _categoryId = null;
                  }),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: moneyStyle(30, FontWeight.w700, accent),
                  decoration: InputDecoration(
                    hintText: '0',
                    prefixText: '\$ ',
                    prefixStyle: moneyStyle(20, FontWeight.w600, accent),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _noteCtrl,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    hintText: '名稱（例如：房租、Netflix）',
                    prefixIcon: Icon(Icons.label_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Text('分類', style: label),
                const SizedBox(height: 10),
                CategoryPicker(
                  categories: cats,
                  selectedId: _categoryId,
                  onSelected: (id) => setState(() => _categoryId = id),
                ),
                if (accounts.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('帳戶', style: label),
                  const SizedBox(height: 10),
                  AccountPicker(
                    accounts: accounts,
                    selectedId: _accountId,
                    onSelected: (id) => setState(() => _accountId = id),
                  ),
                ],
                const SizedBox(height: 24),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.event_rounded),
                        title: const Text('每月幾號'),
                        trailing: DropdownButton<int>(
                          value: _day,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (var d = 1; d <= 28; d++)
                              DropdownMenuItem(value: d, child: Text('$d 日')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _day = v);
                          },
                        ),
                      ),
                      const Divider(indent: 56),
                      ListTile(
                        leading: const Icon(Icons.play_circle_outline_rounded),
                        title: const Text('開始日期'),
                        subtitle: const Text('之前已經到期的月份會自動補記'),
                        trailing: Text(formatDate(_startDate)),
                        onTap: _pickStartDate,
                      ),
                      if (_isEditing) ...[
                        const Divider(indent: 56),
                        SwitchListTile(
                          secondary: const Icon(Icons.pause_circle_outline_rounded),
                          title: const Text('啟用'),
                          value: _active,
                          onChanged: (v) => setState(() => _active = v),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: _save, child: const Text('儲存')),
              ],
            );
          },
        ),
      ),
    );
  }
}
