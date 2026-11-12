import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../data/database.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// 新增或編輯一筆紀錄（existing 為 null 時是新增）
class EditEntryPage extends StatefulWidget {
  const EditEntryPage({super.key, this.existing});

  final EntryView? existing;

  @override
  State<EditEntryPage> createState() => _EditEntryPageState();
}

class _EditEntryPageState extends State<EditEntryPage> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late bool _isIncome;
  int? _categoryId;
  int? _accountId;
  bool _accountInitialized = false;
  late DateTime _date;

  late final Stream<List<TxCategory>> _catStream = db.watchCategories();
  late final Stream<List<Account>> _accStream = db.watchAccounts();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amountCtrl = TextEditingController(text: e?.entry.amount.toString() ?? '');
    _noteCtrl = TextEditingController(text: e?.entry.note ?? '');
    _isIncome = e?.isIncome ?? false;
    _categoryId = e?.entry.categoryId;
    _accountId = e?.entry.accountId;
    _accountInitialized = e != null;
    _date = e?.entry.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = DateTime(
          picked.year, picked.month, picked.day, _date.hour, _date.minute));
    }
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

    final existing = widget.existing;
    if (existing == null) {
      await db.addEntry(EntriesCompanion.insert(
        amount: amount,
        categoryId: categoryId,
        date: _date,
        note: Value(note),
        accountId: Value(_accountId),
      ));
    } else {
      await db.updateEntry(existing.entry.copyWith(
        amount: amount,
        categoryId: categoryId,
        date: _date,
        note: Value(note),
        accountId: Value(_accountId),
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (await confirmDialog(context, '刪除這筆紀錄？')) {
      await db.deleteEntry(widget.existing!.entry.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _isIncome ? incomeColor(context) : expenseColor(context);
    final label = TextStyle(
        fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '編輯紀錄' : '記一筆'),
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
                  autofocus: !_isEditing,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: moneyStyle(34, FontWeight.w700, accent),
                  decoration: InputDecoration(
                    hintText: '0',
                    prefixText: '\$ ',
                    prefixStyle: moneyStyle(22, FontWeight.w600, accent),
                  ),
                ),
                const SizedBox(height: 24),
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
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today_rounded),
                    title: Text(formatDate(_date)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _noteCtrl,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    hintText: '備註（選填）',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _save, child: const Text('儲存')),
              ],
            );
          },
        ),
      ),
    );
  }
}
