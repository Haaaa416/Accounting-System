import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../data/database.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// 帳戶總覽：每個帳戶的目前餘額與總資產
class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  late final Stream<List<AccountWithBalance>> _stream =
      db.watchAccountBalances();

  void _openEditor([Account? existing]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditAccountPage(existing: existing)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('帳戶')),
      body: StreamBuilder<List<AccountWithBalance>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('讀取失敗：${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data!;
          final total = list.fold<int>(0, (s, a) => s + a.balance);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              Container(
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
                  border:
                      Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('淨資產',
                        style: TextStyle(
                            fontSize: 13,
                            letterSpacing: 1,
                            color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Text(formatMoney(total),
                        style: moneyStyle(
                            34,
                            FontWeight.w800,
                            total < 0
                                ? expenseColor(context)
                                : scheme.onSurface)),
                  ],
                ),
              ),
              const SectionHeader('我的帳戶'),
              if (list.isEmpty) const EmptyHint('還沒有帳戶'),
              for (final ab in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: CategoryAvatar(
                          icon: ab.account.icon,
                          color: ab.account.color,
                          size: 44),
                      title: Text(ab.account.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      subtitle: Text(
                          '初始金額 ${formatMoney(ab.account.initialBalance)}'),
                      trailing: MoneyText(
                        ab.balance,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: ab.balance < 0
                            ? expenseColor(context)
                            : scheme.onSurface,
                      ),
                      onTap: () => _openEditor(ab.account),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-accounts',
        onPressed: () => _openEditor(),
        tooltip: '新增帳戶',
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

/// 新增或編輯帳戶
class EditAccountPage extends StatefulWidget {
  const EditAccountPage({super.key, this.existing});

  final Account? existing;

  @override
  State<EditAccountPage> createState() => _EditAccountPageState();
}

class _EditAccountPageState extends State<EditAccountPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _balanceCtrl;
  late String _icon;
  late int _color;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _nameCtrl = TextEditingController(text: a?.name ?? '');
    _balanceCtrl =
        TextEditingController(text: (a?.initialBalance ?? 0).toString());
    _icon = a?.icon ?? 'wallet';
    _color = a?.color ?? 0xFFE6B450;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showSnack(context, '請輸入帳戶名稱');
      return;
    }
    final text = _balanceCtrl.text.trim();
    final balance = text.isEmpty || text == '-' ? 0 : int.tryParse(text);
    if (balance == null) {
      showSnack(context, '初始金額格式不正確');
      return;
    }

    final existing = widget.existing;
    if (existing == null) {
      await db.addAccount(AccountsCompanion.insert(
        name: name,
        icon: Value(_icon),
        color: Value(_color),
        initialBalance: Value(balance),
      ));
    } else {
      await db.updateAccount(existing.copyWith(
        name: name,
        icon: _icon,
        color: _color,
        initialBalance: balance,
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDialog(context, '刪除這個帳戶？')) return;
    final ok = await db.deleteAccountIfUnused(widget.existing!.id);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      showSnack(context, '這個帳戶已經有紀錄在使用，無法刪除');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '編輯帳戶' : '新增帳戶'),
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
          TextField(
            controller: _nameCtrl,
            maxLength: 30,
            decoration: const InputDecoration(labelText: '帳戶名稱'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _balanceCtrl,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
            ],
            decoration: const InputDecoration(
              labelText: '初始金額',
              prefixText: '\$ ',
              helperText: '開始記帳前帳戶裡原本有多少錢；信用卡欠款可以填負數',
            ),
          ),
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
