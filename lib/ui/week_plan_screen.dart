import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/age_class.dart';
import '../models/week_plan.dart';
import '../services/plan_engine.dart';
import 'week_detail_screen.dart';

class WeekPlanScreen extends StatefulWidget {
  final String uid;
  const WeekPlanScreen({super.key, required this.uid});

  @override
  State<WeekPlanScreen> createState() => _WeekPlanScreenState();
}

class _WeekPlanScreenState extends State<WeekPlanScreen> {
  AgeClass _age = AgeClass.u15;

  DateTime _defaultSeasonStart() {
    final now = DateTime.now();
    final y = now.month >= 10 ? now.year : now.year - 1;
    return DateTime(y, 10, 1);
  }

  Color _ampelBackground(Ampel a) {
    switch (a) {
      case Ampel.gruen:
        return Colors.green.withOpacity(0.08);
      case Ampel.gelb:
        return Colors.orange.withOpacity(0.08);
      case Ampel.rot:
        return Colors.red.withOpacity(0.08);
    }
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isCurrentWeek(WeekPlan w, DateTime now) {
    final start = _dateOnly(w.weekStart);
    final end = start.add(const Duration(days: 6));
    final n = _dateOnly(now);
    return !n.isBefore(start) && !n.isAfter(end);
  }

  bool _isPastWeek(WeekPlan w, DateTime now) {
    final nMon = PlanEngine.toMonday(_dateOnly(now));
    return _dateOnly(w.weekStart).isBefore(nMon);
  }

  bool _isOlderThanOneYear(WeekPlan w, DateTime now) {
    final cutoff = DateTime(now.year - 1, now.month, now.day);
    return _dateOnly(w.weekStart).isBefore(_dateOnly(cutoff));
  }

  void _openArchive(List<WeekPlan> pastWeeks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Text(
                        "Archiv (letzte 12 Monate)",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text("${pastWeeks.length} Wochen", style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: pastWeeks.isEmpty
                      ? const Center(child: Text("Keine Wochen im Archiv (letzte 12 Monate)."))
                      : ListView.separated(
                          itemCount: pastWeeks.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final w = pastWeeks[i];
                            return Container(
                              color: _ampelBackground(w.ampel),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: ListTile(
                                title: Text("KW ${w.isoWeek} • ${w.weekStart.toIso8601String().substring(0, 10)}"),
                                subtitle: Text(
                                  "${ampelLabel(w.ampel)} • ${w.recommendedSessions} Einheiten\n"
                                  "Empfehlung: ${w.recommendations.join(' • ')}"
                                  "${w.tournamentNames.isNotEmpty ? "\nTurnier: ${w.tournamentNames.join(', ')}" : ""}",
                                ),
                                trailing: Text(ampelLabel(w.ampel)),
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => WeekDetailScreen(uid: widget.uid, week: w),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: settingsRef.snapshots(),
      builder: (context, settingsSnap) {
        DateTime seasonStart = _defaultSeasonStart();
        if (settingsSnap.hasData && settingsSnap.data!.exists) {
          final s = settingsSnap.data!.data()?["seasonStart"]?.toString();
          if (s != null && s.isNotEmpty) {
            seasonStart = DateTime.parse(s);
          }
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: tournamentsRef.snapshots(),
          builder: (context, tSnap) {
            if (tSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final tournaments = (tSnap.data?.docs ?? []).map((d) => d.data()).toList();

            final weeks = PlanEngine.buildWeeks(
              ageClass: _age,
              seasonStart: seasonStart,
              numberOfWeeks: 52,
              tournaments: tournaments,
            );

            final now = DateTime.now();

            final past = <WeekPlan>[];
            final future = <WeekPlan>[];
            WeekPlan? current;

            for (final w in weeks) {
              if (_isCurrentWeek(w, now)) {
                current = w;
              } else if (_isPastWeek(w, now)) {
                if (!_isOlderThanOneYear(w, now)) past.add(w);
              } else {
                future.add(w);
              }
            }

            past.sort((a, b) => b.weekStart.compareTo(a.weekStart));
            future.sort((a, b) => a.weekStart.compareTo(b.weekStart));

            final visible = <WeekPlan>[
              if (current != null) current!,
              ...future,
            ];

            return Scaffold(
              appBar: AppBar(
                title: const Text("Wochenplan"),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.archive_outlined),
                    onPressed: () => _openArchive(past),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () => FirebaseAuth.instance.signOut(),
                  ),
                ],
              ),
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        DropdownButton<AgeClass>(
                          value: _age,
                          items: AgeClass.values
                              .map(
                                (a) => DropdownMenuItem(
                                  value: a,
                                  child: Text(ageClassLabel(a)),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _age = v);
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
                    child: visible.isEmpty
                        ? const Center(child: Text("Keine Wochen verfügbar."))
                        : ListView.separated(
                            itemCount: visible.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final w = visible[i];
                              return Container(
                                color: _ampelBackground(w.ampel),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: ListTile(
                                  title: Text(
                                    "KW ${w.isoWeek} • ${w.weekStart.toIso8601String().substring(0, 10)}",
                                  ),
                                  subtitle: Text(
                                    "${ampelLabel(w.ampel)} • ${w.recommendedSessions} Einheiten\n"
                                    "Empfehlung: ${w.recommendations.join(' • ')}"
                                    "${w.tournamentNames.isNotEmpty ? "\nTurnier: ${w.tournamentNames.join(', ')}" : ""}",
                                  ),
                                  trailing: Text(ampelLabel(w.ampel)),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => WeekDetailScreen(uid: widget.uid, week: w),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
