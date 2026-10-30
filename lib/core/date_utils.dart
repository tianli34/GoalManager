import 'dart:math' as math;

String _two(int v) => v < 10 ? '0$v' : '$v';

/// 2026-10-30
String fmtDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// 10月30日
String fmtDateCn(DateTime d) => '${d.month}月${d.day}日';

/// 2026-10-30 09:05
String fmtDateTime(DateTime d) =>
    '${fmtDate(d)} ${_two(d.hour)}:${_two(d.minute)}';

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime endOfDay(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

/// 两个日期之间相差的自然日数（按“日”取整，b - a）。
int daysBetween(DateTime a, DateTime b) =>
    startOfDay(b).difference(startOfDay(a)).inDays;

/// 一个时间窗口：复盘与承诺共用（周 / 季度只是窗口参数，不是目标层级）。
class DateWindow {
  const DateWindow({required this.start, required this.end, required this.label});

  final DateTime start;
  final DateTime end;
  final String label;

  bool contains(DateTime t) => !t.isBefore(start) && !t.isAfter(end);

  DateWindow shiftedBy(int days) => DateWindow(
        start: start.add(Duration(days: days)),
        end: end.add(Duration(days: days)),
        label: label,
      );

  @override
  String toString() => '$label ${fmtDate(start)} ~ ${fmtDate(end)}';
}

/// 本周（周一为一周起点）。
DateWindow currentWeek([DateTime? now]) {
  final DateTime n = startOfDay(now ?? DateTime.now());
  final int offset = n.weekday - DateTime.monday;
  final DateTime monday = n.subtract(Duration(days: offset));
  return DateWindow(
    start: monday,
    end: endOfDay(monday.add(const Duration(days: 6))),
    label: '本周',
  );
}

DateWindow lastWeek([DateTime? now]) => currentWeek(now).shiftedBy(-7);

DateWindow nextWeek([DateTime? now]) => currentWeek(now).shiftedBy(7);

/// 本季度。
DateWindow currentQuarter([DateTime? now]) {
  final DateTime n = now ?? DateTime.now();
  final int q = quarterOf(n);
  final int startMonth = (q - 1) * 3 + 1;
  final DateTime start = DateTime(n.year, startMonth, 1);
  final DateTime end = endOfDay(DateTime(n.year, startMonth + 3, 0));
  return DateWindow(start: start, end: end, label: '${n.year}年 Q$q');
}

DateWindow lastQuarter([DateTime? now]) {
  final DateTime n = now ?? DateTime.now();
  final DateTime prevMonth = DateTime(n.year, n.month - 3, 1);
  return currentQuarter(prevMonth);
}

int quarterOf(DateTime d) => ((d.month - 1) ~/ 3) + 1;

/// 把 [ratio] 显示为百分比，不做 0~100 的截断（负值 / 超额要如实展示）。
String fmtPercent(double v, {int digits = 0}) =>
    '${v.toStringAsFixed(digits)}%';

/// 展示数值：整数不带小数点。
String fmtNum(double v) {
  if (v == v.roundToDouble() && v.abs() < 1e15) {
    return v.toStringAsFixed(0);
  }
  final double rounded = (v * 100).roundToDouble() / 100;
  return rounded.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}

/// 带单位的原始量展示，例如 "350 / 500 页"。
String fmtQuantity(double v, String unit) =>
    unit.isEmpty ? fmtNum(v) : '${fmtNum(v)} $unit';

double clamp(double v, double lo, double hi) => math.min(hi, math.max(lo, v));
