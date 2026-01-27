import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import '../models/age_class.dart';
import 'date_parse.dart';

class ImportMapping {
  final int nameCol;
  final int startCol;
  final int? endCol;
  final int? isMainCol;
  final int? ageClassCol;

  ImportMapping({
    required this.nameCol,
    required this.startCol,
    this.endCol,
    this.isMainCol,
    this.ageClassCol,
  });
}

class ImportService {
  static bool _truthy(dynamic v) {
    final s = (v ?? "").toString().trim().toLowerCase();
    return s == "ja" || s == "j" || s == "true" || s == "1" || s.contains("haupt") || s.contains("main");
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

  static List<Map<String, dynamic>> parseCsv({
    required Uint8List bytes,
    required ImportMapping mapping,
    required DateTime seasonStart,
    required List<AgeClass> fallbackAgeClasses,
  }) {
    final text = String.fromCharCodes(bytes);
    final rows = const CsvToListConverter(eol: '\n').convert(text);
    if (rows.length < 2) return [];

    int idx = 0;
    return rows.skip(1).map((r) {
      idx++;
      dynamic cell(int c) => c < r.length ? r[c] : null;

      final name = (cell(mapping.nameCol) ?? "").toString().trim();
      final sd = parseDateFlexible(cell(mapping.startCol), seasonStart);
      final ed = mapping.endCol == null
          ? sd
          : parseDateFlexible(cell(mapping.endCol!), seasonStart);

      final isMain = mapping.isMainCol == null ? false : _truthy(cell(mapping.isMainCol!));
      final ages = mapping.ageClassCol == null
          ? fallbackAgeClasses
          : _parseAgeClasses(cell(mapping.ageClassCol!), fallbackAgeClasses);

      return {
        "name": name.isEmpty ? "Turnier $idx" : name,
        "startDate": sd.toIso8601String(),
        "endDate": ed.toIso8601String(),
        "isMain": isMain,
        "ageClasses": ages.map((a) => a.name).toList(),
        "updatedAt": DateTime.now().toIso8601String(),
      };
    }).toList();
  }

  static List<Map<String, dynamic>> parseXlsx({
    required Uint8List bytes,
    required String sheetName,
    required ImportMapping mapping,
    required DateTime seasonStart,
    required List<AgeClass> fallbackAgeClasses,
  }) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.sheets[sheetName];
    if (sheet == null) return [];
    if (sheet.rows.length < 2) return [];

    int idx = 0;
    return sheet.rows.skip(1).map((row) {
      idx++;
      dynamic cell(int c) => c < row.length ? row[c]?.value : null;

      final name = (cell(mapping.nameCol) ?? "").toString().trim();
      final sd = parseDateFlexible(cell(mapping.startCol), seasonStart);
      final ed = mapping.endCol == null
          ? sd
          : parseDateFlexible(cell(mapping.endCol!), seasonStart);

      final isMain = mapping.isMainCol == null ? false : _truthy(cell(mapping.isMainCol!));
      final ages = mapping.ageClassCol == null
          ? fallbackAgeClasses
          : _parseAgeClasses(cell(mapping.ageClassCol!), fallbackAgeClasses);

      return {
        "name": name.isEmpty ? "Turnier $idx" : name,
        "startDate": sd.toIso8601String(),
        "endDate": ed.toIso8601String(),
        "isMain": isMain,
        "ageClasses": ages.map((a) => a.name).toList(),
        "updatedAt": DateTime.now().toIso8601String(),
      };
    }).toList();
  }
}
