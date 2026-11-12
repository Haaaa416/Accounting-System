import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/database.dart';
import '../utils/format.dart';

/// 新增或編輯一筆欠款（existing 為 null 時是新增）
class EditDebtPage extends StatefulWidget {
  const EditDebtPage({
    super.key,
    required this.db,
    this.existing,
    this.initialPerson,
  });

  final AppDatabase db;
  final Debt? existing;
  final String? initialPerson;

  @override
  State<EditDebtPage> createState() => _EditDebtPageState();
}

class _EditDebtPageState extends State<EditDebtPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _personCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late bool _owedToMe;
  late DateTime _date;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final d = widget.existing;
    _personCtrl =
        TextEditingController(text: d?.person ?? widget.initialPerson ?? '');
    _amountCtrl = TextEditingController(text: d?.amount.toString() ?? '');
    _noteCtrl = TextEditingController(text: d?.note ?? '');
    _owedToMe = d?.owedToMe ?? true;
    _date = d?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _personCtrl.dispose();
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
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final person = _personCtrl.text.trim();
    final amount = int.parse(_amountCtrl.text.trim());
    final noteText = _noteCtrl.text.trim();
    final note = noteText.isEmpty ? null : noteText;

    final existing = widget.existing;
    if (existing == null) {
      await widget.db.addDebt(DebtsCompanion.insert(
        person: person,
        amount: amount,
        owedToMe: _owedToMe,
        date: _date,
        note: Value(note),
      ));
    } else {
      await widget.db.updateDebt(existing.copyWith(
        person: person,
        amount: amount,
        owedToMe: _owedToMe,
        date: _date,
        note: Value(note),
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除這筆欠款？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('刪除')),
        ],
      ),
    );
    if (ok == true) {
      await widget.db.deleteDebt(widget.existing!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '編輯欠款' : '新增欠款'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '刪除',
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('別人欠我')),
                ButtonSegment(value: false, label: Text('我欠別人')),
              ],
              selected: {_owedToMe},
              onSelectionChanged: (s) => setState(() => _owedToMe = s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _personCtrl,
              autofocus: !_isEditing && widget.initialPerson == null,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: '對象名字',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '請輸入名字' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                labelText: '金額',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null || n <= 0) return '請輸入大於 0 的金額';
                return null;
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(formatDate(_date)),
              trailing: const Text('更改日期'),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: '備註（選填，例如：代墊午餐）',
                border: OutlineInputBorder(),
              ),
              maxLength: 100,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('儲存'),
            ),
          ],
        ),
      ),
    );
  }
}
