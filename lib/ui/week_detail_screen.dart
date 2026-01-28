import 'dart:math';
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

  bool _isWarmup(String s) => s.trim().toLowerCase() == "aufwärmung";

  bool _isMobility(String s) {
    final t = s.trim().toLowerCase();
    return t.startsWith("mobilität");
  }

  bool _isStretchStab(String s) => s.trim().toLowerCase() == "dehnung/stabilität";

  int _stableSeedForDay(DateTime weekStart, int dayIndex) {
    final base = "${_d(weekStart)}|$dayIndex|$uid";
    int hash = 0;
    for (final c in base.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return hash;
  }

  /// Regeln:
  /// 1) Aufwärmung immer zuerst
  /// 2) Mobilität ODER Dehnung/Stabilität genau 1x (zufällig)
  /// 3) Rest zufällig, aber ohne Aufwärmung / Mobilität / Dehnung
  List<String> _fourRecsForDay(int dayIndex) {
    final rng = Random(_stableSeedForDay(week.weekStart, dayIndex));
    final pool = week.recommendations;

    const warmup = "Aufwärmung";

    final mobility = pool.where(_isMobility).toList();
    final stretch = pool.where(_isStretchStab).toList();

    String? mobOrStretch;
    if (mobility.isNotEmpty && stretch.isNotEmpty) {
      mobOrStretch = rng.nextBool()
          ? mobility[rng.nextInt(mobility.length)]
          : stretch[rng.nextInt(stretch.length)];
    } else if (mobility.isNotEmpty) {
      mobOrStretch = mobility[rng.nextInt(mobility.length)];
    } else if (stretch.isNotEmpty) {
      mobOrStretch = stretch[rng.nextInt(stretch.length)];
    }

    final rest = pool.where((e) {
      if (_isWarmup(e)) return false;
      if (_isMobility(e)) return false;
      if (_isStretchStab(e)) return false;
      return true;
    }).toList();

    rest.shuffle(rng);

    final out = <String>[warmup];
    if (mobOrStretch != null) out.add(mobOrStretch);

    int i = 0;
    while (out.length < 4) {
      if (i < rest.length) {
        if (!out.contains(rest[i])) out.add(rest[i]);
        i++;
      } else {
        out.add("Training");
      }
    }

    return out.take(4).toList();
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

        final selected = trainingDays.toSet();

        Future<void> save({bool? tf, List<int>? td}) async {
          await weekRef.set(
            {
              "trainingFree": tf ?? trainingFree,
              "trainingDays": (tf ?? trainingFree) ? [] : (td ?? trainingDays),
            },
            SetOptions(merge: true),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text("KW ${week.isoWeek} • Details")),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                title: const Text("Diese Woche trainingsfrei"),
                value: trainingFree,
                onChanged: (v) => save(tf: v, td: const []),
              ),
              const Divider(),

              const Text("Trainingstage",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(7, (i) {
                  return FilterChip(
                    label: Text(_weekdayLabel(i)),
                    selected: selected.contains(i),
                    onSelected: trainingFree
                        ? null
                        : (v) {
                            final next = {...selected};
                            v ? next.add(i) : next.remove(i);
                            save(td: next.toList()..sort());
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
                  ),
                )
              else if (trainingDays.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text("Keine Trainingstage ausgewählt"),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: List.generate(7, (i) {
                      final isDay = selected.contains(i);
                      final recs = isDay ? _fourRecsForDay(i) : const <String>[];

                      return Column(
                        children: [
                          ListTile(
                            dense: true,
                            leading: SizedBox(
                              width: 40,
                              child: Center(child: Text(_weekdayLabel(i))),
                            ),
                            title: Text(_d(week.weekStart.add(Duration(days: i)))),
                            subtitle: isDay
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      for (final r in recs) Text("• $r"),
                                    ],
                                  )
                                : const Text("Kein Trainingstag"),
                          ),
                          if (i != 6) const Divider(height: 1),
                        ],
                      );
                    }),
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
