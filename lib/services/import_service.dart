import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import '../models/age_class.dart';
import 'date_parse.dart';

class ImportMapping {
  final int nameCol;
  final int startCol;
  final int? endCol;       // optional separate end column
  final int? isMainCol;
  final int? ageClassCol;
  final int? dateRangeCol; // NEW: optional single column containing "18./19.10" etc.

  final int headerRow;     // for xlsx (0-based)

  ImportMapping({
    required this.nameCol,
    required this.startCol,
    this.endCol,
    this.isMainCol,
    this.ageClassCol,
    this.dateRangeCol,
    this.headerRow = 0,
  });
}

class ImportResult {
  final List<Map<String, dynamic>> items;
  final List<String> warnings;
  ImportResult({required this.items, required this.warnings});
}

class ImportService {
  static bool _truthy(dynamic v) {
    final s = (v ?? "").toString().trim().toLowerCase();
    return s == "ja" ||
        s == "j" ||
        s == "true" ||
        s == "1" ||
        s.contains("haupt") ||
        s.contains("main");
  }

  static List<AgeClass> _parseAgeClasses(dynamic v, List<AgeClass> fallback) {
    final s = (v ?? "").toString().toUpperCase();
    final found = <AgeClass>{};
    for (final a in AgeClass.values) {
      if (s.contains(ageClassLabel(a).toUpperCase())) found.add(a);
    }
    if (found.isEmpty) return fallback;
    return found.toList();
  }

  static dynamic _unwrapExcel(dynamic v) {
    if (v == null) return null;
    if (v is TextCellValue) return v.value;
    if (v is IntCellValue) return v.value;
    if (v is DoubleCellValue) return v.value;
    if (v is BoolCellValue) return v.value;
    if (v is DateCellValue) return v.asDateTimeLocal();
    return v;
  }

  static bool _rowIsEmptyXlsx(List<Data?> row) {
    for (final c in row) {
      final v = _unwrapExcel(c?.value);
      if (v != null && v.toString().trim().isNotEmpty) return false;
    }
    return true;
  }

  static int _findHeaderRowXlsx(Sheet sheet) {
    for (int r = 0; r < sheet.rows.length; r++) {
      if (!_rowIsEmptyXlsx(sheet.rows[r])) return r;
    }
    return 0;
  }

  static ImportResult parseCsv({
    required Uint8List bytes,
    required ImportMapping mapping,
    required DateTime seasonStart,
    required List<AgeClass> fallbackAgeClasses,
  }) {
    final text = String.fromCharCodes(bytes);
    final firstLine = text.split(RegExp(r'\r?\n')).firstWhere((l) => l.trim().isNotEmpty, orElse: () => "");
    final delim = (firstLine.contains(';') && !firstLine.contains(',')) ? ';' : ',';

    final rows = CsvToListConverter(eol: '\n', fieldDelimiter: delim).convert(text);
    if (rows.length < 2) return ImportResult(items: const [], warnings: const ["CSV: keine Datenzeilen gefunden."]);

    final out = <Map<String, dynamic>>[];
    final warns = <String>[];

    int idx = 0;
    for (final r in rows.skip(1)) {
      if (r.isEmpty) continue;
      idx++;

      dynamic cell(int c) => c < r.length ? r[c] : null;

      final name = (cell(mapping.nameCol) ?? "").toString().trim();

      ParsedDateRange dr;
      if (mapping.dateRangeCol != null) {
        dr = parseDateRangeFlexible(cell(mapping.dateRangeCol!), seasonStart);
      } else {
        final sd = parseDateFlexible(cell(mapping.startCol), seasonStart);
        final ed = mapping.endCol == null ? sd : parseDateFlexible(cell(mapping.endCol!), seasonStart);
        dr = ParsedDateRange(sd, ed);
      }

      // A2: importieren + warnen (nicht abbrechen)
      final rawStart = (mapping.dateRangeCol != null) ? cell(mapping.dateRangeCol!) : cell(mapping.startCol);
      if (rawStart == null || rawStart.toString().trim().isEmpty) {
        warns.add("Zeile $idx: Startdatum fehlt -> übersprungen");
        continue;
      }

      final isMain = mapping.isMainCol == null ? false : _truthy(cell(mapping.isMainCol!));
      final ages = mapping.ageClassCol == null
          ? fallbackAgeClasses
          : _parseAgeClasses(cell(mapping.ageClassCol!), fallbackAgeClasses);

      out.add({
        "name": name.isEmpty ? "Turnier $idx" : name,
        "startDate": dr.start.toIso8601String(),
        "endDate": dr.end.toIso8601String(),
        "isMain": isMain,
        "ageClasses": ages.map((a) => a.name).toList(),
        "updatedAt": DateTime.now().toIso8601String(),
      });
    }

    return ImportResult(items: out, warnings: warns);
  }

  static ImportResult parseXlsx({
    required Uint8List bytes,
    required String sheetName,
    required ImportMapping mapping,
    required DateTime seasonStart,
    required List<AgeClass> fallbackAgeClasses,
  }) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.sheets[sheetName];
    if (sheet == null || sheet.rows.isEmpty) {
      return ImportResult(items: const [], warnings: const ["XLSX: Sheet leer/fehlt."]);
    }

    final headerRow = (mapping.headerRow >= 0 && mapping.headerRow < sheet.rows.length)
        ? mapping.headerRow
        : _findHeaderRowXlsx(sheet);

    final out = <Map<String, dynamic>>[];
    final warns = <String>[];

    int idx = 0;
    for (int r = headerRow + 1; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      if (_rowIsEmptyXlsx(row)) continue;
      idx++;

      dynamic cell(int c) => c < row.length ? _unwrapExcel(row[c]?.value) : null;

      final name = (cell(mapping.nameCol) ?? "").toString().trim();

      ParsedDateRange dr;
      if (mapping.dateRangeCol != null) {
        dr = parseDateRangeFlexible(cell(mapping.dateRangeCol!), seasonStart);
      } else {
        final sd = parseDateFlexible(cell(mapping.startCol), seasonStart);
        final ed = mapping.endCol == null ? sd : parseDateFlexible(cell(mapping.endCol!), seasonStart);
        dr = ParsedDateRange(sd, ed);
      }

      final rawStart = (mapping.dateRangeCol != null) ? cell(mapping.dateRangeCol!) : cell(mapping.startCol);
      if (rawStart == null || rawStart.toString().trim().isEmpty) {
        warns.add("Zeile ${r + 1}: Startdatum fehlt -> übersprungen");
        continue;
      }

      final isMain = mapping.isMainCol == null ? false : _truthy(cell(mapping.isMainCol!));
      final ages = mapping.ageClassCol == null
          ? fallbackAgeClasses
          : _parseAgeClasses(cell(mapping.ageClassCol!), fallbackAgeClasses);

      out.add({
        "name": name.isEmpty ? "Turnier $idx" : name,
        "startDate": dr.start.toIso8601String(),
        "endDate": dr.end.toIso8601String(),
        "isMain": isMain,
        "ageClasses": ages.map((a) => a.name).toList(),
        "updatedAt": DateTime.now().toIso8601String(),
      });
    }

    return ImportResult(items: out, warnings: warns);
  }
}
