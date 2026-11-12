/// 1234567 -> "1,234,567"；負數 -> "-1,234"
String formatMoney(int v) {
  final s = v.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$buf';
}

const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

/// "11月12日 週四"
String formatDay(DateTime d) =>
    '${d.month}月${d.day}日 週${_weekdays[d.weekday - 1]}';

/// "2026/11/12"
String formatDate(DateTime d) => '${d.year}/${d.month}/${d.day}';

String _two(int n) => n.toString().padLeft(2, '0');

/// "2026-11-12"（CSV 用）
String formatIsoDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// "20261112"（檔名用）
String formatCompactDate(DateTime d) =>
    '${d.year}${_two(d.month)}${_two(d.day)}';

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
