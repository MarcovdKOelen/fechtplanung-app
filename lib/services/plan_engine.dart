import 'package:intl/intl.dart';

import '../models/age_class.dart';
import '../models/week_plan.dart';

class PlanEngine {
  static const Map<Ampel, List<String>> defaultRecs = {
    Ampel.gruen: [
      "Athletik Basis",
      "Beinarbeit Volumen",
      "Gefechte intensiv",
      "Koordination / Spiel"
    ],
    Ampel.gelb: ["Technik + Taktik", "Gefechte kurz", "Athletik kurz"],
    Ampel.rot: ["Aktivierung + Technik", "Locker Technik"],
  };

  static int sessionsFor(Ampel a) {
    switch (a) {
      case Ampel.rot:
        return 2;
      case Ampel.gelb:
        return 3;
      case Ampel.gruen:
        return 4;
    }
  }

  static DateTime toMonday(DateTime d) {
    final diff = (d.weekday + 6) % 7; // Mon=1..Sun=7 -> diff 0..6
    final dd = DateTime(d.year, d.month, d.day);
    return dd.subtract(Duration(days: diff));
  }

  static int isoWeekNum(DateTime d) {
    // Thursday-based ISO week number
    final wday = d.weekday; // 1..7
    final thursday = d.add(Duration(days: 4 - wday));
    final thursdayDayOfYear = int.parse(DateFormat("D").format(thursday));
    return ((thursdayDayOfYear - 1) ~/ 7) + 1;
  }

  static List<WeekPlan> buildWeeks({
    required AgeClass ageClass,
    required DateTime seasonStart,
    required int numberOfWeeks,
    required List<Map<String, dynamic>> tournaments, // simplified for now
  }) {
    final startMon = toMonday(seasonStart);
    final weeks = <WeekPlan>[];

    for (int i = 0; i < numberOfWeeks; i++) {
      final ws = startMon.add(Duration(days: i * 7));
      final we = ws.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

      // tournaments maps contain: name, startDate, endDate, isMain, ageClasses(List<String>)
      final relevant = tournaments.where((t) {
        final ages = (t["ageClasses"] as List).map((x) => x.toString()).toList();
        if (!ages.contains(ageClass.name)) return false;

        final sd = DateTime.parse(t["startDate"]);
        final ed = DateTime.parse(t["endDate"]);
        final overlaps = !(ed.isBefore(ws) || sd.isAfter(we));
        return overlaps;
      }).toList();

      final hasT = relevant.isNotEmpty;
      final hasMain = relevant.any((t) => (t["isMain"] ?? false) == true);

      final ampel = hasMain ? Ampel.rot : (hasT ? Ampel.gelb : Ampel.gruen);
      final sessions = sessionsFor(ampel);
      final recs = (defaultRecs[ampel] ?? const <String>[]).take(sessions).toList();

      weeks.add(WeekPlan(
        ageClass: ageClass,
        weekStart: ws,
        isoWeek: isoWeekNum(ws),
        ampel: ampel,
        recommendedSessions: sessions,
        recommendations: recs,
        tournamentNames: relevant.map((t) => t["name"].toString()).toList(),
      ));
    }

    return weeks;
  }
}
