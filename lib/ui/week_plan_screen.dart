import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/age_class.dart';
import '../models/week_plan.dart';
import '../services/plan_engine.dart';

class WeekPlanScreen extends StatefulWidget {
  final String uid;
  const WeekPlanScreen({super.key, required this.uid});

  @override
  State<WeekPlanScreen> createState() => _WeekPlanScreenState();
}

class _WeekPlanScreenState extends State<WeekPlanScreen> {
  AgeClass _selectedAge = AgeClass.u15;

  DateTime _defaultSeasonStart() {
    final now = DateTime.now();
    final y = now.month >= 10 ? now.year : now.year - 1;
    return DateTime(y, 10, 1);
  }

  @override
  Widget build(BuildContext context) {
    final settingsRef = FirebaseFirestore.instance
        .collection("users")
        .doc(widget.uid)
        .collection("settings")
        .doc("main");

    final tournamentsRef = FirebaseFirestore.instance
        .collection("users")
        .doc(widget.uid)
        .collection("tournaments");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Wochenplan"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: settingsRef.snapshots(),
        builder: (context, settingsSnap) {
          DateTime seasonStart = _defaultSeasonStart();
          if (settingsSnap.hasData && settingsSnap.data!.exists) {
            final s = settingsSnap.data!.data()?["seasonStart"]?.toString();
            if (s != null) seasonStart = DateTime.parse(s);
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: tournamentsRef.snapshots(),
            builder: (context, tourSnap) {
              if (tourSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final tournaments = (tourSnap.data?.docs ?? []).map((d) => d.data()).toList();

              final weeks = PlanEngine.buildWeeks(
                ageClass: _selectedAge,
                seasonStart: seasonStart,
                numberOfWeeks: 52,
                tournaments: tournaments,
              );

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        DropdownButton<AgeClass>(
                          value: _selectedAge,
                          items: AgeClass.values
                              .map((a) => DropdownMenuItem(
                                    value: a,
                                    child: Text(ageClassLabel(a)),
                                  ))
                              .toList(),
                          onChanged: (a) {
                            if (a != null) setState(() => _selectedAge = a);
                          },
                        ),
                        const Spacer(),
                        Text(
                          "Saisonstart: ${seasonStart.toIso8601String().substring(0, 10)}",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      itemCount: weeks.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final w = weeks[i];
                        return ListTile(
                          title: Text("KW ${w.isoWeek} • ${w.weekStart.toIso8601String().substring(0, 10)}"),
                          subtitle: Text(
                            "${ampelLabel(w.ampel)} • ${w.recommendedSessions} Einheiten\n"
                            "Empfehlung: ${w.recommendations.join(' • ')}"
                            "${w.tournamentNames.isNotEmpty ? "\nTurnier: ${w.tournamentNames.join(', ')}" : ""}",
                          ),
                          trailing: Text(ampelLabel(w.ampel)),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
