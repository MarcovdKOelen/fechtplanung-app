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

  /// Anzahl empfohlener Trainingstage
  final int recommendedSessions;

  /// Tagesempfehlungen Mo–So (null = kein Training)
  final List<String?> dayRecommendations;

  final List<String> tournamentNames;

  const WeekPlan({
    required this.ageClass,
    required this.weekStart,
    required this.isoWeek,
    required this.ampel,
    required this.recommendedSessions,
    required this.dayRecommendations,
    required this.tournamentNames,
  }) : assert(dayRecommendations.length == 7);
}
