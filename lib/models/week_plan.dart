import 'age_class.dart';

enum Ampel { gruen, gelb, rot }

String ampelLabel(Ampel a) {
  switch (a) {
    case Ampel.gruen:
      return "Grün";
    case Ampel.gelb:
      return "Gelb";
    case Ampel.rot:
      return "Rot";
  }
}

class WeekPlan {
  final AgeClass ageClass;
  final DateTime weekStart; // Montag
  final int isoWeek;
  final Ampel ampel;
  final int recommendedSessions;
  final List<String> recommendations;
  final List<String> tournamentNames;

  WeekPlan({
    required this.ageClass,
    required this.weekStart,
    required this.isoWeek,
    required this.ampel,
    required this.recommendedSessions,
    required this.recommendations,
    required this.tournamentNames,
  });
}
