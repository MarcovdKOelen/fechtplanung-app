import 'package:flutter/material.dart';

import '../models/week_plan.dart';

class WeekDetailScreen extends StatelessWidget {
  final WeekPlan week;
  const WeekDetailScreen({super.key, required this.week});

  // --- helpers ---
  String _d(DateTime d) => d.toIso8601String().substring(0, 10);

  DateTime get _weekEnd => week.weekStart.add(const Duration(days: 6));

  DateTime _day(int offset) => week.weekStart.add(Duration(days: offset));

  String _weekdayLabel(int offset) {
    switch (offset) {
      case 0:
        return "Mo";
      case 1:
        return "Di";
      case 2:
        return "Mi";
      case 3:
        return "Do";
      case 4:
        return "Fr";
      case 5:
        return "Sa";
      case 6:
        return "So";
      default:
        return "";
    }
  }

  Color _ampelBg(Ampel a) {
    switch (a) {
      case Ampel.gruen:
        return Colors.green.withOpacity(0.08);
      case Ampel.gelb:
        return Colors.orange.withOpacity(0.08);
      case Ampel.rot:
        return Colors.red.withOpacity(0.08);
    }
  }

  IconData _ampelIcon(Ampel a) {
    switch (a) {
      case Ampel.gruen:
        return Icons.check_circle_outline;
      case Ampel.gelb:
        return Icons.error_outline;
      case Ampel.rot:
        return Icons.warning_amber_outlined;
    }
  }

  // verteilt Empfehlungen auf die Woche (Mo, Di, Do, Fr als Default-Trainingstage)
  Map<int, String> _buildSessionPlan() {
    final result = <int, String>{};

    final recs = week.recommendations;
    final count = week.recommendedSessions;

    if (count <= 0) return result;

    // default training days: Mo, Di, Do, Fr (4)
    final slots = <int>[0, 1, 3, 4];

    // wenn weniger Einheiten: von vorne
    // wenn mehr als 4: fülle Mi (2) und Sa (5) zusätzlich
    final expandedSlots = <int>[
      ...slots,
      2,
      5,
    ];

    final useSlots = expandedSlots.take(count.clamp(0, 6)).toList();

    for (int i = 0; i < useSlots.length; i++) {
      final day = useSlots[i];
      final label = (i < recs.length) ? recs[i] : "Training";
      result[day] = label;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final sessionPlan = _buildSessionPlan();

    return Scaffold(
      appBar: AppBar(
        title: Text("KW ${week.isoWeek} • Details"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _ampelBg(week.ampel),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_ampelIcon(week.ampel)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${_d(week.weekStart)} – ${_d(_weekEnd)}",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text("Ampel: ${ampelLabel(week.ampel)}"),
                      Text("Empfohlene Einheiten: ${week.recommendedSessions}"),
                      if (week.tournamentNames.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          "Turnier: ${week.tournamentNames.join(', ')}",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Wochenübersicht (Tage)
          const Text(
            "Wochenübersicht",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: List.generate(7, (i) {
                final dayDate = _day(i);
                final hasSession = sessionPlan.containsKey(i);
                final sessionLabel = sessionPlan[i];

                return Column(
                  children: [
                    ListTile(
                      dense: true,
                      leading: Container(
                        width: 42,
                        alignment: Alignment.center,
                        child: Text(
                          _weekdayLabel(i),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      title: Text(_d(dayDate)),
                      subtitle: hasSession ? Text("Einheit: $sessionLabel") : const Text("Kein Training geplant"),
                      trailing: hasSession ? const Icon(Icons.fitness_center) : null,
                    ),
                    if (i != 6) const Divider(height: 1),
                  ],
                );
              }),
            ),
          ),

          const SizedBox(height: 16),

          // Trainingsempfehlungen
          const Text(
            "Trainingsempfehlungen",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          if (week.recommendations.isEmpty)
            const Card(
              child: ListTile(
                title: Text("Keine Empfehlungen hinterlegt."),
              ),
            )
          else
            ...week.recommendations.map(
              (e) => Card(
                child: ListTile(
                  leading: const Icon(Icons.playlist_add_check),
                  title: Text(e),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Turniere
          const Text(
            "Turniere",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          if (week.tournamentNames.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.emoji_events_outlined),
                title: Text("Keine Turniere in dieser Woche."),
              ),
            )
          else
            ...week.tournamentNames.map(
              (t) => Card(
                child: ListTile(
                  leading: const Icon(Icons.emoji_events_outlined),
                  title: Text(t),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
