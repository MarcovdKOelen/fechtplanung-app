import '../models/age_class.dart';
import '../models/week_plan.dart';

class PlanEngine {
  static DateTime toMonday(DateTime d) {
    final diff = (d.weekday + 6) % 7;
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: diff));
  }

  static int isoWeekNum(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final firstThursday = DateTime(thursday.year, 1, 4);
    return 1 + (thursday.difference(firstThursday).inDays ~/ 7);
  }

  static int _sessionsFor(Ampel a, Map<String, dynamic> settings) {
    switch (a) {
      case Ampel.gruen:
        return settings["sessions_green"] ?? 4;
      case Ampel.gelb:
        return settings["sessions_yellow"] ?? 3;
      case Ampel.rot:
        return settings["sessions_red"] ?? 2;
    }
  }

  static const Map<Ampel, List<String>> _baseRecs = {
    Ampel.gruen: [
      "Athletik Basis",
      "Beinarbeit",
      "Technik/Taktik",
      "Gefechte intensiv"
    ],
    Ampel.gelb: [
      "Technik/Taktik",
      "Gefechte kurz",
      "Athletik kurz"
    ],
    Ampel.rot: [
      "Aktivierung",
      "Locker Technik"
    ],
  };

  static List<WeekPlan> buildWeeks({
    required AgeClass ageClass,
    required DateTime seasonStart,
    required int numberOfWeeks,
    required List<Map<String, dynamic>> tournaments,
    required Map<String, dynamic> settings,
  }) {
    final startMon = toMonday(seasonStart);
    final weeks = <WeekPlan>[];

    final trainingDays =
        (settings["trainingDays"] as List?)?.cast<int>() ?? [0, 1, 3, 4];

    for (int i = 0; i < numberOfWeeks; i++) {
      final ws = startMon.add(Duration(days: i * 7));
      final we = ws.add(const Duration(days: 6));

      final relevant = tournaments.where((t) {
        final sd = DateTime.parse(t["startDate"]);
        final ed = DateTime.parse(t["endDate"]);
        return !(ed.isBefore(ws) || sd.isAfter(we));
      }).toList();

      final hasMain = relevant.any((t) => t["isMain"] == true);
      final hasAny = relevant.isNotEmpty;

      final ampel =
          hasMain ? Ampel.rot : (hasAny ? Ampel.gelb : Ampel.gruen);

      final sessions = _sessionsFor(ampel, settings);
      final base = _baseRecs[ampel] ?? [];

      final dayRecs = List<String?>.filled(7, null);

      for (int k = 0; k < sessions && k < trainingDays.length; k++) {
        final day = trainingDays[k];
        dayRecs[day] = base.length > k ? base[k] : "Training";
      }

      weeks.add(
        WeekPlan(
          ageClass: ageClass,
          weekStart: ws,
          isoWeek: isoWeekNum(ws),
          ampel: ampel,
          recommendedSessions: sessions,
          dayRecommendations: dayRecs,
          tournamentNames:
              relevant.map((t) => t["name"].toString()).toList(),
        ),
      );
    }

    return weeks;
  }
}
