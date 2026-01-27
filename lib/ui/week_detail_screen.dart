import 'package:flutter/material.dart';

import '../models/week_plan.dart';
import '../models/age_class.dart';

class WeekDetailScreen extends StatelessWidget {
  final String scopeLabel;
  final AgeClass ageClass;
  final WeekPlan week;

  const WeekDetailScreen({
    super.key,
    required this.scopeLabel,
    required this.ageClass,
    required this.week,
  });

  String _d(DateTime d) => d.toIso8601String().substring(0, 10);

  @override
  Widget build(BuildContext context) {
    final start = week.weekStart;
    final end = week.weekStart.add(const Duration(days: 6));

    return Scaffold(
      appBar: AppBar(
        title: Text("KW ${week.isoWeek} • ${ageClassLabel(ageClass)} • $scopeLabel"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Zeitraum: ${_d(start)} – ${_d(end)}",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text("Ampel: ${ampelLabel(week.ampel)}"),
                  Text("Empfohlene Einheiten: ${week.recommendedSessions}"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Empfehlungen", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  if (week.recommendations.isEmpty)
                    const Text("Keine Empfehlungen hinterlegt.")
                  else
                    ...week.recommendations.map((r) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.fitness_center),
                          title: Text(r),
                        )),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Turniere in dieser Woche", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  if (week.tournamentNames.isEmpty)
                    const Text("Keine Turniere in dieser Woche.")
                  else
                    ...week.tournamentNames.map((t) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.emoji_events),
                          title: Text(t),
                        )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
