import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../data/database.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// 欠款總覽：依人名分組，顯示每個人目前的淨額
class DebtsPage extends StatefulWidget {
  const DebtsPage({super.key});

  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> {
  late final Stream<List<Debt>> _stream = db.watchDebts();
  bool _showSettled = false;

  void _openEditor({Debt? existing, String? person}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditDebtPage(existing: existing, initialPerson: person),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('欠款'),
        actions: [
          IconButton(
            icon: Icon(_showSettled
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded),
            tooltip: _showSettled ? '隱藏已結清' : '顯示已結清',
            onPressed: () => setState(() => _showSettled = !_showSettled),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<List<Debt>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('讀取失敗：${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data!;

          // 總額只算未結清的
          var owedToMe = 0;
          var iOwe = 0;
          for (final d in all.where((d) => !d.settled)) {
            if (d.owedToMe) {
              owedToMe += d.amount;
            } else {
              iOwe += d.amount;
            }
          }

          final visible =
              _showSettled ? all : all.where((d) => !d.settled).toList();
          final byPerson = <String, List<Debt>>{};
          for (final d in visible) {
            byPerson.putIfAbsent(d.person, () => []).add(d);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              _DebtSummary(owedToMe: owedToMe, iOwe: iOwe),
              const SizedBox(height: 8),
              if (byPerson.isEmpty)
                const EmptyHint('沒有未結清的欠款',
                    icon: Icons.handshake_outlined)
              else
                for (final e in byPerson.entries)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _PersonCard(
                      person: e.key,
                      debts: e.value,
                      onTapDebt: (d) => _openEditor(existing: d),
                      onAdd: () => _openEditor(person: e.key),
                    ),
                  ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-debts',
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('新增欠款',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }
}

class _DebtSummary extends StatelessWidget {
  const _DebtSummary({required this.owedToMe, required this.iOwe});

  final int owedToMe;
  final int iOwe;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget cell(String label, int value, Color color) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Text(formatMoney(value),
                  style: moneyStyle(24, FontWeight.w800, color)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark(context)
              ? const [Color(0xFF2B2416), Color(0xFF141922)]
              : const [Color(0xFFFFF3D6), Colors.white],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          cell('別人欠我', owedToMe, incomeColor(context)),
          cell('我欠別人', iOwe, expenseColor(context)),
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.debts,
    required this.onTapDebt,
    required this.onAdd,
  });

  final String person;
  final List<Debt> debts;
  final void Function(Debt) onTapDebt;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // 淨額：正數 = 對方欠我，負數 = 我欠對方
    var net = 0;
    for (final d in debts.where((d) => !d.settled)) {
      net += d.owedToMe ? d.amount : -d.amount;
    }
    final (label, color) = net > 0
        ? ('欠你 ${formatMoney(net)}', incomeColor(context))
        : net < 0
            ? ('你欠 ${formatMoney(-net)}', expenseColor(context))
            : ('已結清', scheme.onSurfaceVariant);

    return Card(
      child: Theme(
        // 去掉 ExpansionTile 展開時的分隔線
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('debt-$person'),
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          leading: CircleAvatar(
            backgroundColor: scheme.primary.withValues(alpha: 0.18),
            foregroundColor: scheme.primary,
            child: Text(person.characters.first,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          title: Text(person,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(label,
              style: moneyStyle(13, FontWeight.w600, color)),
          trailing: IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: '幫 $person 新增一筆',
            onPressed: onAdd,
          ),
          children: [
            for (final d in debts)
              ListTile(
                leading: Checkbox(
                  value: d.settled,
                  onChanged: (v) => db.setDebtSettled(d.id, v ?? false),
                ),
                title: Text(
                  d.owedToMe ? '他欠我' : '我欠他',
                  style: TextStyle(
                    decoration: d.settled ? TextDecoration.lineThrough : null,
                    color: d.settled ? scheme.onSurfaceVariant : null,
                  ),
                ),
                subtitle: Text([
                  formatDate(d.date),
                  if (d.note != null) d.note!,
                ].join(' · ')),
                trailing: MoneyText(
                  d.amount,
                  color: d.settled
                      ? scheme.onSurfaceVariant
                      : (d.owedToMe
                          ? incomeColor(context)
                          : expenseColor(context)),
                ),
                onTap: () => onTapDebt(d),
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

/// 新增或編輯一筆欠款（existing 為 null 時是新增）
class EditDebtPage extends StatefulWidget {
  const EditDebtPage({super.key, this.existing, this.initialPerson});

  final Debt? existing;
  final String? initialPerson;

  @override
  State<EditDebtPage> createState() => _EditDebtPageState();
}

class _EditDebtPageState extends State<EditDebtPage> {
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
    final person = _personCtrl.text.trim();
    if (person.isEmpty) {
      showSnack(context, '請輸入名字');
      return;
    }
    final amount = int.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      showSnack(context, '請輸入大於 0 的金額');
      return;
    }
    final noteText = _noteCtrl.text.trim();
    final note = noteText.isEmpty ? null : noteText;

    final existing = widget.existing;
    if (existing == null) {
      await db.addDebt(DebtsCompanion.insert(
        person: person,
        amount: amount,
        owedToMe: _owedToMe,
        date: _date,
        note: Value(note),
      ));
    } else {
      await db.updateDebt(existing.copyWith(
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
    if (await confirmDialog(context, '刪除這筆欠款？')) {
      await db.deleteDebt(widget.existing!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _owedToMe ? incomeColor(context) : expenseColor(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '編輯欠款' : '新增欠款'),
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
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: true, label: Text('別人欠我')),
              ButtonSegment(value: false, label: Text('我欠別人')),
            ],
            selected: {_owedToMe},
            onSelectionChanged: (s) => setState(() => _owedToMe = s.first),
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
          const SizedBox(height: 16),
          TextField(
            controller: _personCtrl,
            maxLength: 30,
            decoration: const InputDecoration(
              hintText: '對象名字',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 8),
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
              hintText: '備註（選填，例如：代墊午餐）',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('儲存')),
        ],
      ),
    );
  }
}
