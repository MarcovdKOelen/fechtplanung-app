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
        bool trainingFree = data["trainingFree"] == true;
        final days = (data["trainingDays"] as List? ?? [])
            .map((e) => int.tryParse(e.toString()) ?? -1)
            .where((i) => i >= 0 && i <= 6)
            .toSet();

        Future<void> save() async {
          await weekRef.set(
            {
              "trainingFree": trainingFree,
              "trainingDays": trainingFree ? [] : days.toList()..sort(),
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
                  trainingFree = v;
                  if (v) days.clear();
                  await save();
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
                  final selected = days.contains(i);
                  return FilterChip(
                    label: Text(_weekdayLabel(i)),
                    selected: selected,
                    onSelected: trainingFree
                        ? null
                        : (v) async {
                            if (v) {
                              days.add(i);
                            } else {
                              days.remove(i);
                            }
                            await save();
                          },
                  );
                }),
              ),

              const SizedBox(height: 24),
              Text(
                trainingFree
                    ? "Diese Woche ist vollständig trainingsfrei."
                    : "Ausgewählte Trainingstage: ${days.map(_weekdayLabel).join(", ")}",
              ),
            ],
          ),
        );
      },
    );
  }
}
