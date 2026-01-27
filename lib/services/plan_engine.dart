import '../models/age_class.dart';
import '../models/week_plan.dart';
import '../models/tournament.dart';

class PlanEngine {
  static DateTime toMonday(DateTime d) {
    final diff = (d.weekday + 6) % 7;
    final dd = DateTime(d.year, d.month, d.day);
    return dd.subtract(Duration(days: diff));
  }

  static int isoWeekNum(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final dayOfWeek = d.weekday;
    final thursday = d.add(Duration(days: 4 - dayOfWeek));

    final firstThursday = DateTime(thursday.year, 1, 4);
    final firstThursdayDayOfWeek = firstThursday.weekday;
    final firstWeekThursday = firstThursday.add(Duration(days: 4 - firstThursdayDayOfWeek));

    final diffDays = thursday.difference(firstWeekThursday).inDays;
    return 1 + (diffDays ~/ 7);
  }

  static const Map<Ampel, List<String>> defaultRecs = {
    Ampel.gruen: ["Athletik Basis", "Beinarbeit Volumen", "Technik/Taktik", "Gefechte intensiv"],
    Ampel.gelb: ["Technik/Taktik", "Gefechte kurz", "Athletik kurz"],
    Ampel.rot: ["Aktivierung + Technik", "Locker Technik"],
  };

  static List<WeekPlan> buildWeeks({
    required AgeClass ageClass,
    required DateTime seasonStart,
    required int numberOfWeeks,
    required List<Tournament> tournaments,
    required Map<String, dynamic> settings,
  }) {
    final startMon = toMonday(seasonStart);

    Map<String, dynamic> sessionsCfgFor(AgeClass a) {
      final all = settings["sessions"] as Map<String, dynamic>? ?? {};
      return (all[a.name] as Map<String, dynamic>?) ??
          {"gruen": 4, "gelb": 3, "rot": 2};
    }

    final cfg = sessionsCfgFor(ageClass);
    int sessionsFor(Ampel ampel) {
      final key = ampel.name;
      final v = cfg[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return ampel == Ampel.rot ? 2 : (ampel == Ampel.gelb ? 3 : 4);
    }

    List<String> recsFor(Ampel ampel, int count) {
      final custom = settings["recommendations"] as Map<String, dynamic>? ?? {};
      final list = (custom[ampel.name] as List?)?.map((e) => e.toString()).toList();
      final base = list ?? (defaultRecs[ampel] ?? const <String>[]);
      if (base.isEmpty) return const [];
      return base.take(count).toList();
    }

    final weeks = <WeekPlan>[];
    for (int i = 0; i < numberOfWeeks; i++) {
      final ws = startMon.add(Duration(days: i * 7));
      final we = ws.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

      final relevant = tournaments.where((t) {
        final ageOk = t.ageClasses.contains(ageClass);
        if (!ageOk) return false;
        final overlaps = !(t.endDate.isBefore(ws) || t.startDate.isAfter(we));
        return overlaps;
      }).toList();

      final hasT = relevant.isNotEmpty;
      final hasMain = relevant.any((t) => t.isMain);

      final ampel = hasMain ? Ampel.rot : (hasT ? Ampel.gelb : Ampel.gruen);
      final sessions = sessionsFor(ampel);
      final recs = recsFor(ampel, sessions);

      weeks.add(WeekPlan(
        ageClass: ageClass,
        weekStart: ws,
        isoWeek: isoWeekNum(ws),
        ampel: ampel,
        recommendedSessions: sessions,
        recommendations: recs,
        tournamentNames: relevant.map((t) => t.name).toList(),
      ));
    }

    return weeks;
  }
}
