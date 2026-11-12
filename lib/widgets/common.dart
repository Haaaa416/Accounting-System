import 'package:flutter/material.dart';

import '../data/database.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/style.dart';

/// 圓角方形的分類／帳戶圖示
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  final String icon;
  final int color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Color(color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(iconFor(icon), color: c, size: size * 0.52),
    );
  }
}

/// 金額文字。isIncome 為 null 時不加正負號、用一般文字顏色。
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    super.key,
    this.isIncome,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w600,
    this.color,
  });

  final int amount;
  final bool? isIncome;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final income = isIncome;
    final c = color ??
        (income == null
            ? Theme.of(context).colorScheme.onSurface
            : income
                ? incomeColor(context)
                : expenseColor(context));
    final sign = income == null ? '' : (income ? '+' : '−');
    return Text(
      '$sign${formatMoney(amount)}',
      style: moneyStyle(fontSize, fontWeight, c),
    );
  }
}

/// 「‹ 2026 年 11 月 ›」月份切換，點中間回到本月
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key, required this.month, required this.onChanged});

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrent = month.year == now.year && month.month == now.month;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
          ),
          TextButton(
            onPressed: isCurrent
                ? null
                : () => onChanged(DateTime(now.year, now.month)),
            child: Text(
              '${month.year} 年 ${month.month} 月',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => onChanged(DateTime(month.year, month.month + 1)),
          ),
        ],
      ),
    );
  }
}

/// 區塊標題
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 沒有資料時的提示
class EmptyHint extends StatelessWidget {
  const EmptyHint(this.text, {super.key, this.icon = Icons.inbox_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 44, color: c.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: c)),
        ],
      ),
    );
  }
}

/// 進度條（預算用）
class BudgetBar extends StatelessWidget {
  const BudgetBar({super.key, required this.spent, required this.budget});

  final int spent;
  final int budget;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final double ratio = budget > 0 ? spent / budget : 0;
    final color = ratio > 1
        ? expenseColor(context)
        : ratio > 0.8
            ? const Color(0xFFF59E0B)
            : scheme.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: ratio.clamp(0, 1).toDouble(),
        minHeight: 8,
        backgroundColor: scheme.surfaceContainerHigh,
        color: color,
      ),
    );
  }
}

/// 一筆收支紀錄
class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.view,
    this.onTap,
    this.showDate = false,
  });

  final EntryView view;
  final VoidCallback? onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final e = view.entry;
    final account = view.account;
    final note = e.note;
    final sub = [
      if (showDate) formatDate(e.date),
      if (account != null) account.name,
      if (note != null) note,
    ].join(' · ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CategoryAvatar(icon: view.category.icon, color: view.category.color),
      title: Text(view.category.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: sub.isEmpty
          ? null
          : Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: MoneyText(e.amount, isIncome: view.isIncome),
      onTap: onTap,
    );
  }
}

/// 分類選擇（一排可點的標籤）
class CategoryPicker extends StatelessWidget {
  const CategoryPicker({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<TxCategory> categories;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in categories)
          ChoiceChip(
            avatar: Icon(iconFor(c.icon), color: Color(c.color), size: 18),
            label: Text(c.name),
            selected: c.id == selectedId,
            showCheckmark: false,
            selectedColor: Color(c.color).withValues(alpha: 0.22),
            side: BorderSide(
              color: c.id == selectedId ? Color(c.color) : scheme.outlineVariant,
            ),
            onSelected: (_) => onSelected(c.id),
          ),
      ],
    );
  }
}

/// 帳戶選擇
class AccountPicker extends StatelessWidget {
  const AccountPicker({
    super.key,
    required this.accounts,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Account> accounts;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in accounts)
          ChoiceChip(
            avatar: Icon(iconFor(a.icon), color: Color(a.color), size: 18),
            label: Text(a.name),
            selected: a.id == selectedId,
            showCheckmark: false,
            selectedColor: Color(a.color).withValues(alpha: 0.22),
            side: BorderSide(
              color: a.id == selectedId ? Color(a.color) : scheme.outlineVariant,
            ),
            onSelected: (_) => onSelected(a.id),
          ),
      ],
    );
  }
}

/// 選圖示和顏色
class IconColorPicker extends StatelessWidget {
  const IconColorPicker({
    super.key,
    required this.icon,
    required this.color,
    required this.onIcon,
    required this.onColor,
  });

  final String icon;
  final int color;
  final ValueChanged<String> onIcon;
  final ValueChanged<int> onColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = TextStyle(
        fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('顏色', style: label),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in kPalette)
              GestureDetector(
                onTap: () => onColor(c),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c == color ? scheme.onSurface : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: c == color
                      ? const Icon(Icons.check_rounded,
                          size: 18, color: Colors.black87)
                      : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text('圖示', style: label),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in kIcons.entries)
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onIcon(e.key),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: e.key == icon
                        ? Color(color).withValues(alpha: 0.22)
                        : scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: e.key == icon ? Color(color) : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    e.value,
                    color: e.key == icon ? Color(color) : scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// 確認對話框，按「確定」回傳 true
Future<bool> confirmDialog(
  BuildContext context,
  String title, {
  String? message,
  String confirmText = '刪除',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(80, 44)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// 輸入金額的對話框。回傳 null 代表取消；回傳 (value: null) 代表清除。
Future<({int? value})?> amountDialog(
  BuildContext context,
  String title, {
  int? initial,
  bool allowClear = true,
}) {
  final ctrl = TextEditingController(text: initial?.toString() ?? '');
  return showDialog<({int? value})>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(prefixText: '\$ ', hintText: '金額'),
      ),
      actions: [
        if (allowClear)
          TextButton(
            onPressed: () => Navigator.pop(ctx, (value: null)),
            child: const Text('清除'),
          ),
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(80, 44)),
          onPressed: () {
            final v = int.tryParse(ctrl.text.trim());
            Navigator.pop(ctx, (value: (v == null || v <= 0) ? null : v));
          },
          child: const Text('儲存'),
        ),
      ],
    ),
  );
}

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
