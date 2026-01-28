// lib/ui/week_detail_screen.dart

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

  List<String> _baseFourRecsForDay(int dayIndex) {
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

  List<String> _allowedOptionsForSlot(int slotIndex) {
    final pool = week.recommendations;

    if (slotIndex == 0) return const ["Aufwärmung"];

    if (slotIndex == 1) {
      final opts = <String>[];
      opts.addAll(pool.where(_isMobility));
      opts.addAll(pool.where(_isStretchStab));
      final dedup = opts.toSet().toList()..sort();
      return dedup;
    }

    final opts = pool.where((e) {
      if (_isWarmup(e)) return false;
      if (_isMobility(e)) return false;
      if (_isStretchStab(e)) return false;
      return true;
    }).toSet().toList()
      ..sort();

    return opts;
  }

  List<String> _applyOverrideIfAny({
    required int dayIndex,
    required Map<String, dynamic> dayOverrides,
    required List<String> base,
  }) {
    final raw = dayOverrides[dayIndex.toString()];
    if (raw is! List) return base;

    final overridden = raw.map((e) => e.toString()).toList();
    if (overridden.length != 4) return base;

    if (overridden[0] != "Aufwärmung") return base;

    for (int i = 0; i < 4; i++) {
      final allowed = _allowedOptionsForSlot(i);
      if (allowed.isEmpty) continue;
      if (!allowed.contains(overridden[i])) return base;
    }

    return overridden;
  }

  Future<void> _pickReplacement({
    required BuildContext context,
    required DocumentReference<Map<String, dynamic>> weekRef,
    required int dayIndex,
    required int slotIndex,
    required List<String> currentDayList,
    required Map<String, dynamic> dayOverrides,
  }) async {
    if (slotIndex == 0) return;

    final options = _allowedOptionsForSlot(slotIndex);
    if (options.isEmpty) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Auswahl: ${_weekdayLabel(dayIndex)} • Slot ${slotIndex + 1}",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      itemCount: options.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final opt = options[i];
                        return ListTile(
                          title: Text(opt),
                          onTap: () => Navigator.pop(context, opt),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected == null) return;

    final nextDay = List<String>.from(currentDayList);
    nextDay[slotIndex] = selected;

    final nextOverrides = Map<String, dynamic>.from(dayOverrides);
    nextOverrides[dayIndex.toString()] = nextDay;

    await weekRef.set(
      {"dayOverrides": nextOverrides},
      SetOptions(merge: true),
    );
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

        final dayOverrides = (data["dayOverrides"] is Map)
            ? Map<String, dynamic>.from(data["dayOverrides"] as Map)
            : <String, dynamic>{};

        Future<void> _setTrainingFree(bool v) async {
          if (v) {
            // trainingsfrei AN: Trainingstage + Overrides leeren
            await weekRef.set(
              {
                "trainingFree": true,
                "trainingDays": [],
                "dayOverrides": {},
              },
              SetOptions(merge: true),
            );
          } else {
            // trainingsfrei AUS: nur Flag setzen (Trainingstage bleiben wie sie sind)
            await weekRef.set(
              {"trainingFree": false},
              SetOptions(merge: true),
            );
          }
        }

        Future<void> _setTrainingDays(Set<int> next) async {
          final list = next.toList()..sort();
          await weekRef.set(
            {
              "trainingFree": false, // sobald Tage gesetzt werden, ist nicht trainingsfrei
              "trainingDays": list,
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
                onChanged: (v) async => _setTrainingFree(v),
              ),
              const Divider(),

              const Text(
                "Trainingstage",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
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
                            _setTrainingDays(next);
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
                    children: List.generate(7, (dayIndex) {
                      final isDay = selected.contains(dayIndex);
                      final dateStr = _d(week.weekStart.add(Duration(days: dayIndex)));

                      final base = _baseFourRecsForDay(dayIndex);
                      final recs = _applyOverrideIfAny(
                        dayIndex: dayIndex,
                        dayOverrides: dayOverrides,
                        base: base,
                      );

                      return Column(
                        children: [
                          ListTile(
                            dense: true,
                            leading: SizedBox(
                              width: 40,
                              child: Center(
                                child: Text(
                                  _weekdayLabel(dayIndex),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            title: Text(dateStr),
                            subtitle: !isDay
                                ? const Text("Kein Trainingstag")
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      for (int s = 0; s < 4; s++)
                                        InkWell(
                                          onTap: () => _pickReplacement(
                                            context: context,
                                            weekRef: weekRef,
                                            dayIndex: dayIndex,
                                            slotIndex: s,
                                            currentDayList: recs,
                                            dayOverrides: dayOverrides,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            child: Text(
                                              "• ${recs[s]}",
                                              style: TextStyle(
                                                decoration: (s == 0)
                                                    ? TextDecoration.none
                                                    : TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                          if (dayIndex != 6) const Divider(height: 1),
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
