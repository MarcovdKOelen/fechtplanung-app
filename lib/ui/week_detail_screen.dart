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

  /// Liefert GENAU 4 Empfehlungen für einen Trainingstag.
  /// Nutzt week.recommendations als Pool und rotiert, damit sich die Tage unterscheiden.
  List<String> _fourRecsForDay(int dayOrderIndex) {
    final pool = week.recommendations;
    if (pool.isEmpty) return const ["Training", "Training", "Training", "Training"];

    final out = <String>[];
    for (int k = 0; k < 4; k++) {
      final idx = (dayOrderIndex * 4 + k) % pool.length;
      out.add(pool[idx]);
    }
    return out;
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

        return Scaffold(
          appBar: AppBar(
            title: Text("KW ${week.isoWeek} • Details"),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
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

              const Text(
                "Empfohlene Einheiten pro Tag (je 4)",
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
                      final dateStr = _d(week.weekStart.add(Duration(days: i)));

                      // dayOrderIndex = Position innerhalb der ausgewählten Trainingstage (0..)
                      final dayOrderIndex = trainingDays.indexOf(i);
                      final recs = isTrainingDay ? _fourRecsForDay(dayOrderIndex) : const <String>[];

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
                            title: Text(dateStr),
                            subtitle: isTrainingDay
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      for (final r in recs) Text("• $r"),
                                    ],
                                  )
                                : const Text("Kein Trainingstag"),
                            trailing: isTrainingDay ? const Icon(Icons.fitness_center) : null,
                          ),
                          if (i != 6) const Divider(height: 1),
                        ],
                      );
                    }),
                  ),
                ),

              const SizedBox(height: 16),

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
