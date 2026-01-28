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
    // akzeptiert: "Mobilität", "Mobilitätstraining", etc.
    return t.startsWith("mobilität");
  }

  bool _isStretchStab(String s) => s.trim().toLowerCase() == "dehnung/stabilität";

  int _stableSeedForDay({
    required DateTime weekStart,
    required int weekdayIndex,
  }) {
    // deterministisch: Woche + Tag + uid (damit sich Trainer nicht gegenseitig beeinflussen)
    final base = "${_d(weekStart)}|$weekdayIndex|$uid";
    int hash = 0;
    for (final code in base.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return hash;
  }

  /// Liefert GENAU 4 Empfehlungen nach deinen Regeln:
  /// 1) Aufwärmung immer zuerst
  /// 2) Mobilität ODER Dehnung/Stabilität genau 1x (zufällig, stabil)
  /// 3) Rest zufällig aus Pool, ohne Aufwärmung/Mobilität/Dehnung-Stabi
  List<String> _fourRecsForDay({
    required int dayIndex,
    required List<String> pool,
  }) {
    final rng = Random(_stableSeedForDay(weekStart: week.weekStart, weekdayIndex: dayIndex));

    // 1) warmup
    const warmup = "Aufwärmung";

    // mobility candidates: alles was mit "Mobilität" anfängt
    final mobilityCandidates = pool.where(_isMobility).toList();

    // stretch/stab candidates: exakt Dehnung/Stabilität
    final stretchCandidates = pool.where(_isStretchStab).toList();

    String? chosenMobOrStretch;

    // 2) wähle zufällig: Mobilität oder Dehnung/Stabilität (wenn möglich)
    final hasMob = mobilityCandidates.isNotEmpty;
    final hasStretch = stretchCandidates.isNotEmpty;

    if (hasMob && hasStretch) {
      chosenMobOrStretch = rng.nextBool()
          ? mobilityCandidates[rng.nextInt(mobilityCandidates.length)]
          : stretchCandidates[rng.nextInt(stretchCandidates.length)];
    } else if (hasMob) {
      chosenMobOrStretch = mobilityCandidates[rng.nextInt(mobilityCandidates.length)];
    } else if (hasStretch) {
      chosenMobOrStretch = stretchCandidates[rng.nextInt(stretchCandidates.length)];
    } else {
      chosenMobOrStretch = null; // falls beides nicht existiert
    }

    // 3) restliche Kandidaten (ohne warmup/mobility/stretch)
    final restPool = pool.where((e) {
      if (_isWarmup(e)) return false;
      if (_isMobility(e)) return false;
      if (_isStretchStab(e)) return false;
      return true;
    }).toList();

    // Shuffle (stabil)
    for (int i = restPool.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = restPool[i];
      restPool[i] = restPool[j];
      restPool[j] = tmp;
    }

    final out = <String>[];
    out.add(warmup);
    if (chosenMobOrStretch != null) out.add(chosenMobOrStretch);

    // auffüllen bis 4
    int idx = 0;
    while (out.length < 4) {
      if (idx < restPool.length) {
        final candidate = restPool[idx++];
        // Duplikate vermeiden
        if (!out.contains(candidate)) out.add(candidate);
      } else {
        // Fallback wenn zu wenig Pool: generisches Training
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

                      final recs = isTrainingDay
                          ? _fourRecsForDay(dayIndex: i, pool: week.recommendations)
                          : const <String>[];

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
            ],
          ),
        );
      },
    );
  }
}
