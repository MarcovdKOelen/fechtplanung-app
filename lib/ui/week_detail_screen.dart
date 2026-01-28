import 'package:flutter/material.dart';
import '../models/week_plan.dart';

class WeekDetailScreen extends StatelessWidget {
  final String uid;
  final WeekPlan week;

  const WeekDetailScreen({super.key, required this.uid, required this.week});

  String _d(DateTime d) => d.toIso8601String().substring(0, 10);

  String _wd(int i) =>
      const ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"][i];

  Color _bg(Ampel a) {
    switch (a) {
      case Ampel.gruen:
        return Colors.green.withOpacity(0.08);
      case Ampel.gelb:
        return Colors.orange.withOpacity(0.08);
      case Ampel.rot:
        return Colors.red.withOpacity(0.08);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("KW ${week.isoWeek}")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _bg(week.ampel),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${_d(week.weekStart)} – ${_d(week.weekStart.add(const Duration(days: 6)))}",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text("Ampel: ${ampelLabel(week.ampel)}"),
                Text("Einheiten: ${week.recommendedSessions}"),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Text("Tagesplanung",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),

          const SizedBox(height: 8),
          Card(
            child: Column(
              children: List.generate(7, (i) {
                final rec = week.dayRecommendations[i];
                return Column(
                  children: [
                    ListTile(
                      leading: Text(_wd(i),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      title: Text(_d(week.weekStart.add(Duration(days: i)))),
                      subtitle: Text(
                        rec ?? "Kein Training",
                      ),
                      trailing:
                          rec != null ? const Icon(Icons.fitness_center) : null,
                    ),
                    if (i != 6) const Divider(height: 1),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
