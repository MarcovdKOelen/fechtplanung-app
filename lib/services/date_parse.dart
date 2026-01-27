DateTime _date(int y, int m, int d) => DateTime(y, m, d);

DateTime parseDateFlexible(dynamic v, DateTime seasonStart) {
  if (v == null) return seasonStart;

  if (v is DateTime) return DateTime(v.year, v.month, v.day);

  // Excel numeric date (fallback)
  if (v is num) {
    final dt = DateTime(1899, 12, 30).add(Duration(days: v.round()));
    return DateTime(dt.year, dt.month, dt.day);
  }

  final s0 = v.toString().trim();
  if (s0.isEmpty) return seasonStart;

  // yyyy-mm-dd
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s0);
  if (iso != null) {
    return _date(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }

  // dd.mm.yyyy or dd/mm/yyyy
  final dmy = RegExp(r'^(\d{1,2})[.\-/](\d{1,2})[.\-/](\d{2,4})$').firstMatch(s0);
  if (dmy != null) {
    final d = int.parse(dmy.group(1)!);
    final m = int.parse(dmy.group(2)!);
    var y = int.parse(dmy.group(3)!);
    if (y < 100) y += 2000;
    return _date(y, m, d);
  }

  // "18.10" (no year) or "18./19.10" -> use first day, infer season year
  final noYear1 = RegExp(r'^(\d{1,2})\.(\d{1,2})$').firstMatch(s0);
  if (noYear1 != null) {
    final d = int.parse(noYear1.group(1)!);
    final m = int.parse(noYear1.group(2)!);
    final y = (m >= 8) ? seasonStart.year : (seasonStart.year + 1);
    return _date(y, m, d);
  }

  final noYear2 = RegExp(r'^(\d{1,2})\.\s*\/\s*(\d{1,2})\.(\d{1,2})$').firstMatch(s0);
  if (noYear2 != null) {
    final d = int.parse(noYear2.group(1)!);
    final m = int.parse(noYear2.group(3)!);
    final y = (m >= 8) ? seasonStart.year : (seasonStart.year + 1);
    return _date(y, m, d);
  }

  return seasonStart;
}
