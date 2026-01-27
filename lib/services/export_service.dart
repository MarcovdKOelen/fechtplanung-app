import 'dart:typed_data';
import 'package:excel/excel.dart';

import '../models/week_plan.dart';
import '../models/tournament.dart';
import '../models/age_class.dart';

class ExportService {
  static String _fmt(DateTime d) => d.toIso8601String().substring(0, 10);

  static Uint8List tournamentsCsv(List<Tournament> t) {
    final sb = StringBuffer();
    sb.writeln("name,start_date,end_date,is_main,age_classes");
    for (final x in t) {
      sb.writeln([
        _csv(x.name),
        _csv(_fmt(x.startDate)),
        _csv(_fmt(x.endDate)),
        _csv(x.isMain ? "true" : "false"),
        _csv(x.ageClasses.map((a) => a.name).join("|")),
      ].join(","));
    }
    return Uint8List.fromList(sb.toString().codeUnits);
  }

  static Uint8List weekplanCsv(List<WeekPlan> w) {
    final sb = StringBuffer();
    sb.writeln("age_class,kw,week_start,ampel,sessions,tournaments,recommendations");
    for (final x in w) {
      sb.writeln([
        _csv(x.ageClass.name),
        _csv(x.isoWeek.toString()),
        _csv(_fmt(x.weekStart)),
        _csv(x.ampel.name),
        _csv(x.recommendedSessions.toString()),
        _csv(x.tournamentNames.join("|")),
        _csv(x.recommendations.join("|")),
      ].join(","));
    }
    return Uint8List.fromList(sb.toString().codeUnits);
  }

  static Uint8List toXlsx({
    required List<Tournament> tournaments,
    required List<WeekPlan> weeks,
  }) {
    final excel = Excel.createExcel();

    final s1 = excel["Turniere"];
    s1.appendRow([
      TextCellValue("Name"),
      TextCellValue("Start"),
      TextCellValue("Ende"),
      TextCellValue("Hauptturnier"),
      TextCellValue("Altersklassen"),
    ]);
    for (final t in tournaments) {
      s1.appendRow([
        TextCellValue(t.name),
        TextCellValue(_fmt(t.startDate)),
        TextCellValue(_fmt(t.endDate)),
        TextCellValue(t.isMain ? "Ja" : "Nein"),
        TextCellValue(t.ageClasses.map(ageClassLabel).join(", ")),
      ]);
    }

    final s2 = excel["Wochenplan"];
    s2.appendRow([
      TextCellValue("Altersklasse"),
      TextCellValue("KW"),
      TextCellValue("Wochenstart"),
      TextCellValue("Ampel"),
      TextCellValue("Einheiten"),
      TextCellValue("Turniere"),
      TextCellValue("Empfehlungen"),
    ]);
    for (final w in weeks) {
      s2.appendRow([
        TextCellValue(ageClassLabel(w.ageClass)),
        TextCellValue(w.isoWeek.toString()),
        TextCellValue(_fmt(w.weekStart)),
        TextCellValue(ampelLabel(w.ampel)),
        TextCellValue(w.recommendedSessions.toString()),
        TextCellValue(w.tournamentNames.join(", ")),
        TextCellValue(w.recommendations.join(" • ")),
      ]);
    }

    excel.setDefaultSheet("Turniere");
    final bytes = excel.encode();
    return Uint8List.fromList(bytes ?? []);
  }

  static String _csv(String s) {
    final needs = s.contains(",") || s.contains("\n") || s.contains('"');
    var out = s.replaceAll('"', '""');
    if (needs) out = '"$out"';
    return out;
  }
}
