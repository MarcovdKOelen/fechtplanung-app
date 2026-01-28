import '../models/age_class.dart';
import '../models/week_plan.dart';

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

  static int _readInt(Map<String, dynamic> settings, String key, int fallback) {
    final v = settings[key];
    if (v == null) return fallback;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? fallback;
  }

  static int sessionsFor(Ampel a, Map<String, dynamic> settings) {
    // Trainer kann setzen:
    // sessions_green, sessions_yellow, sessions_red
    switch (a) {
      case Ampel.gruen:
        return _readInt(settings, "sessions_green", 4);
      case Ampel.gelb:
        return _readInt(settings, "sessions_yellow", 3);
      case Ampel.rot:
        return _readInt(settings, "sessions_red", 2);
    }
  }

  // tournaments: Map enthält mindestens:
  // name, startDate, endDate, isMain, ageClasses (Liste z.B. ["u15"])
  static List<WeekPlan> buildWeeks({
    required AgeClass ageClass,
    required DateTime seasonStart,
    required int numberOfWeeks,
    required List<Map<String, dynamic>> tournaments,
    Map<String, dynamic> settings = const {},
  }) {
    final startMon = toMonday(seasonStart);
    final weeks = <WeekPlan>[];

    for (int i = 0; i < numberOfWeeks; i++) {
      final ws = startMon.add(Duration(days: i * 7));
      final we = ws.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

      final relevant = tournaments.where((t) {
        final ages = (t["ageClasses"] as List? ?? const []).map((x) => x.toString()).toList();
        if (!ages.contains(ageClass.name)) return false;

        final sd = DateTime.parse(t["startDate"].toString());
        final ed = DateTime.parse(t["endDate"].toString());
        return !(ed.isBefore(ws) || sd.isAfter(we));
      }).toList();

      final hasT = relevant.isNotEmpty;
      final hasMain = relevant.any((t) => (t["isMain"] ?? false) == true);

      final ampel = hasMain ? Ampel.rot : (hasT ? Ampel.gelb : Ampel.gruen);
      final sessions = sessionsFor(ampel, settings);

      final recs = (defaultRecs[ampel] ?? const <String>[]).take(sessions).toList();

      weeks.add(
        WeekPlan(
          ageClass: ageClass,
          weekStart: ws,
          isoWeek: isoWeekNum(ws),
          ampel: ampel,
          recommendedSessions: sessions,
          recommendations: recs,
          tournamentNames: relevant
              .map((t) => (t["name"] ?? "").toString())
              .where((s) => s.isNotEmpty)
              .toList(),
        ),
      );
    }

    return weeks;
  }
}
