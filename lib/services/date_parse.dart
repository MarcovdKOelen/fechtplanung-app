class ParsedDateRange {
  final DateTime start;
  final DateTime end;
  const ParsedDateRange(this.start, this.end);
}

DateTime _date(int y, int m, int d) => DateTime(y, m, d);

DateTime _inferYear(DateTime seasonStart, int month) {
  // Saison: ab Oktober -> Monate >=8 (Aug–Dez) => seasonStart.year, sonst seasonStart.year+1
  final y = (month >= 8) ? seasonStart.year : (seasonStart.year + 1);
  return DateTime(y, 1, 1);
}

DateTime parseDateFlexible(dynamic v, DateTime seasonStart) {
  if (v == null) return seasonStart;

  if (v is DateTime) return DateTime(v.year, v.month, v.day);

  // Excel numeric date (days since 1899-12-30)
  if (v is num) {
    final dt = DateTime(1899, 12, 30).add(Duration(days: v.round()));
    return DateTime(dt.year, dt.month, dt.day);
  }

  final s0 = v.toString().trim();
  if (s0.isEmpty) return seasonStart;

  final s = s0.replaceAll(" ", "");

  // yyyy-mm-dd
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
  if (iso != null) {
    return _date(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }

  // dd.mm.yyyy / dd/mm/yyyy / dd-mm-yyyy
  final dmy = RegExp(r'^(\d{1,2})[.\-/](\d{1,2})[.\-/](\d{2,4})$').firstMatch(s);
  if (dmy != null) {
    final d = int.parse(dmy.group(1)!);
    final m = int.parse(dmy.group(2)!);
    var y = int.parse(dmy.group(3)!);
    if (y < 100) y += 2000;
    return _date(y, m, d);
  }

  // dd.mm (no year)
  final noYear = RegExp(r'^(\d{1,2})\.(\d{1,2})$').firstMatch(s);
  if (noYear != null) {
    final d = int.parse(noYear.group(1)!);
    final m = int.parse(noYear.group(2)!);
    final y = _inferYear(seasonStart, m).year;
    return _date(y, m, d);
  }

  return seasonStart;
}

ParsedDateRange parseDateRangeFlexible(dynamic v, DateTime seasonStart) {
  if (v == null) {
    final d = seasonStart;
    return ParsedDateRange(d, d);
  }

  // If already a DateTime / num -> single day
  if (v is DateTime || v is num) {
    final d = parseDateFlexible(v, seasonStart);
    return ParsedDateRange(d, d);
  }

  final raw = v.toString().trim();
  if (raw.isEmpty) {
    final d = seasonStart;
    return ParsedDateRange(d, d);
  }

  // Normalize
  final s = raw.replaceAll(" ", "");

  // Patterns:
  // 18./19.10
  final r1 = RegExp(r'^(\d{1,2})\.\s*\/\s*(\d{1,2})\.(\d{1,2})$').firstMatch(raw);
  if (r1 != null) {
    final d1 = int.parse(r1.group(1)!);
    final d2 = int.parse(r1.group(2)!);
    final m = int.parse(r1.group(3)!);
    final y = _inferYear(seasonStart, m).year;
    return ParsedDateRange(_date(y, m, d1), _date(y, m, d2));
  }

  // 18.10/19.10
  final r2 = RegExp(r'^(\d{1,2})\.(\d{1,2})\/(\d{1,2})\.(\d{1,2})$').firstMatch(s);
  if (r2 != null) {
    final d1 = int.parse(r2.group(1)!);
    final m1 = int.parse(r2.group(2)!);
    final d2 = int.parse(r2.group(3)!);
    final m2 = int.parse(r2.group(4)!);
    final y1 = _inferYear(seasonStart, m1).year;
    final y2 = _inferYear(seasonStart, m2).year;
    return ParsedDateRange(_date(y1, m1, d1), _date(y2, m2, d2));
  }

  // 18.-19.10.2025  OR 18.–19.10.2025
  final r3 = RegExp(r'^(\d{1,2})\.(?:-|–)(\d{1,2})\.(\d{1,2})\.(\d{2,4})$').firstMatch(s);
  if (r3 != null) {
    final d1 = int.parse(r3.group(1)!);
    final d2 = int.parse(r3.group(2)!);
    final m = int.parse(r3.group(3)!);
    var y = int.parse(r3.group(4)!);
    if (y < 100) y += 2000;
    return ParsedDateRange(_date(y, m, d1), _date(y, m, d2));
  }

  // Default: single date parse
  final d = parseDateFlexible(raw, seasonStart);
  return ParsedDateRange(d, d);
}
