import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/week_plan.dart';

class WeekDetailScreen extends StatelessWidget {
  final String uid;
  final WeekPlan week;

  const WeekDetailScreen({
    super.key,
    required this.uid,
    required this.week,
  });

  String _d(DateTime d) => d.toIso8601String().substring(0, 10);

  String _weekdayLabel(int i) {
    const days = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"];
    return days[i];
  }

  Map<int, String> _buildDayRecommendationMap({
    required List<int> trainingDaysSorted,
    required bool trainingFree,
  }) {
    if (trainingFree) return {};

    final result = <int, String>{};
    if (trainingDaysSorted.isEmpty) return result;

    final maxSessions = week.recommendedSessions.clamp(0, 7);
    final count = maxSessions.clamp(0, trainingDaysSorted.length);

    for (int i = 0; i < count; i++) {
      final dayIndex = trainingDaysSorted[i];
      final label = (i < week.recommendations.length) ? week.recommendations[i] : "Training";
      result[dayIndex] = label;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final weekId = _d(week.weekStart);

    final weekRef = FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("weeks")
        .doc(weekId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: weekRef.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final trainingFree = data["trainingFree"] == true;

        final trainingDays = (data["trainingDays"] as List? ?? [])
            .map((e) => int.tryParse(e.toString()) ?? -1)
            .where((i) => i >= 0 && i <= 6)
            .toSet()
            .toList()
          ..sort();

        final selectedSet = trainingDays.toSet();

        Future<void> save({
          bool? trainingFreeNew,
          List<int>? trainingDaysNew,
        }) async {
          final tf = trainingFreeNew ?? trainingFree;
          final td = (trainingDaysNew ?? trainingDays)..sort();

          await weekRef.set(
            {
              "trainingFree": tf,
              "trainingDays": tf ? [] : td,
            },
            SetOptions(merge: true),
          );
        }

        final dayRecMap = _buildDayRecommendationMap(
          trainingDaysSorted: trainingDays,
          trainingFree: trainingFree,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text("KW ${week.isoWeek} • Details"),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Trainingsfrei
              SwitchListTile(
                title: const Text("Diese Woche trainingsfrei"),
                value: trainingFree,
                onChanged: (v) async {
                  if (v) {
                    await save(trainingFreeNew: true, trainingDaysNew: const []);
                  } else {
                    await save(trainingFreeNew: false);
                  }
                },
              ),
              const Divider(),

              // Trainingstage auswählen
              const Text(
                "Trainingstage",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (i) {
                  final selected = selectedSet.contains(i);
                  return FilterChip(
                    label: Text(_weekdayLabel(i)),
                    selected: selected,
                    onSelected: trainingFree
                        ? null
                        : (v) async {
                            final next = selectedSet.toSet();
                            if (v) {
                              next.add(i);
                            } else {
                              next.remove(i);
                            }
                            final nextList = next.toList()..sort();
                            await save(trainingDaysNew: nextList);
                          },
                  );
                }),
              ),

              const SizedBox(height: 16),

              // Tages-Empfehlungen anzeigen (nach Auswahl)
              const Text(
                "Empfohlene Einheiten pro Tag",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              if (trainingFree)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.hotel_outlined),
                    title: Text("Trainingsfrei"),
                    subtitle: Text("In dieser Woche werden keine Einheiten empfohlen."),
                  ),
                )
              else if (trainingDays.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text("Keine Trainingstage ausgewählt"),
                    subtitle: Text("Wähle oben Trainingstage aus, dann erscheinen hier die Empfehlungen pro Tag."),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: List.generate(7, (i) {
                      final isTrainingDay = selectedSet.contains(i);
                      final rec = dayRecMap[i];

                      String subtitle;
                      IconData? trailingIcon;

                      if (!isTrainingDay) {
                        subtitle = "Kein Trainingstag";
                        trailingIcon = null;
                      } else if (rec == null) {
                        subtitle = "Training (ohne Empfehlung)";
                        trailingIcon = Icons.fitness_center;
                      } else {
                        subtitle = rec;
                        trailingIcon = Icons.fitness_center;
                      }

                      return Column(
                        children: [
                          ListTile(
                            dense: true,
                            leading: SizedBox(
                              width: 44,
                              child: Center(
                                child: Text(
                                  _weekdayLabel(i),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            title: Text(_d(week.weekStart.add(Duration(days: i)))),
                            subtitle: Text(subtitle),
                            trailing: trailingIcon == null ? null : Icon(trailingIcon),
                          ),
                          if (i != 6) const Divider(height: 1),
                        ],
                      );
                    }),
                  ),
                ),

              const SizedBox(height: 16),

              // Optional: Wochen-Empfehlungs-Liste (wie bisher) – bleibt als Referenz drin
              const Text(
                "Empfehlungen (Woche)",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (week.recommendations.isEmpty)
                const Card(child: ListTile(title: Text("Keine Empfehlungen hinterlegt.")))
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
      },
    );
  }
}
