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

  Color _weekBackground(Ampel a, bool trainingFree) {
    if (trainingFree) return Colors.grey.withOpacity(0.15);
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

  Future<void> _pickSeasonStart(DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2035, 12, 31),
    );
    if (picked == null) return;

    final ref = FirebaseFirestore.instance
        .collection("users")
        .doc(widget.uid)
        .collection("settings")
        .doc("main");

    await ref.set(
      {
        "seasonStart": DateTime(picked.year, picked.month, picked.day).toIso8601String(),
        "updatedAt": DateTime.now().toIso8601String(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _addTournamentDialog() async {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();

    DateTime? startDate;
    DateTime? endDate;
    bool multiDay = false;

    // 0=regulär(gelb), 1=wichtig(rot)
    int type = 0;

    Future<void> pickStart() async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: startDate ?? now,
        firstDate: DateTime(2020, 1, 1),
        lastDate: DateTime(2035, 12, 31),
      );
      if (picked == null) return;
      startDate = DateTime(picked.year, picked.month, picked.day);
      if (!multiDay) endDate = startDate;
    }

    Future<void> pickEnd() async {
      if (startDate == null) return;
      final picked = await showDatePicker(
        context: context,
        initialDate: endDate ?? startDate!,
        firstDate: startDate!,
        lastDate: DateTime(2035, 12, 31),
      );
      if (picked == null) return;
      endDate = DateTime(picked.year, picked.month, picked.day);
    }

    String fmt(DateTime? d) => d == null ? "—" : d.toIso8601String().substring(0, 10);

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return AlertDialog(
              title: const Text("Turnier hinzufügen"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: "Turniername",
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: locationCtrl,
                      decoration: const InputDecoration(
                        labelText: "Ort",
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Expanded(child: Text("Datum (Start)")),
                        Text(fmt(startDate)),
                        IconButton(
                          icon: const Icon(Icons.date_range_outlined),
                          onPressed: () async {
                            await pickStart();
                            setS(() {});
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("Mehrtägig"),
                            value: multiDay,
                            onChanged: (v) {
                              multiDay = v;
                              if (!multiDay) {
                                endDate = startDate;
                              } else {
                                endDate ??= startDate;
                              }
                              setS(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    if (multiDay)
                      Row(
                        children: [
                          const Expanded(child: Text("Datum (Ende)")),
                          Text(fmt(endDate)),
                          IconButton(
                            icon: const Icon(Icons.event_outlined),
                            onPressed: startDate == null
                                ? null
                                : () async {
                                    await pickEnd();
                                    setS(() {});
                                  },
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: type,
                      decoration: const InputDecoration(labelText: "Turnier-Typ"),
                      items: const [
                        DropdownMenuItem(
                          value: 0,
                          child: Text("Reguläres Turnier (Ampel Gelb)"),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Text("Wichtiges Turnier / Saisonhöhepunkt (Ampel Rot)"),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        type = v;
                        setS(() {});
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Abbrechen"),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final loc = locationCtrl.text.trim();
                    if (name.isEmpty || loc.isEmpty || startDate == null) return;
                    if (multiDay && endDate == null) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text("Speichern"),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    final tournamentsRef = FirebaseFirestore.instance
        .collection("users")
        .doc(widget.uid)
        .collection("tournaments");

    final s = DateTime(startDate!.year, startDate!.month, startDate!.day);
    final e = DateTime((endDate ?? startDate!)!.year, (endDate ?? startDate!)!.month, (endDate ?? startDate!)!.day);

    await tournamentsRef.add({
      "name": nameCtrl.text.trim(),
      "location": locationCtrl.text.trim(),
      "startDate": s.toIso8601String(),
      "endDate": e.toIso8601String(),
      "isMain": type == 1, // wichtig => rot
      "ageClasses": [_age.name],
      "createdAt": DateTime.now().toIso8601String(),
    });

    nameCtrl.dispose();
    locationCtrl.dispose();
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
                            final weekId = w.weekStart.toIso8601String().substring(0, 10);

                            final weekDocStream = FirebaseFirestore.instance
                                .collection("users")
                                .doc(widget.uid)
                                .collection("weeks")
                                .doc(weekId)
                                .snapshots();

                            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                              stream: weekDocStream,
                              builder: (context, snap) {
                                final trainingFree = snap.data?.data()?["trainingFree"] == true;

                                return Container(
                                  color: _weekBackground(w.ampel, trainingFree),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: ListTile(
                                    title: Text("KW ${w.isoWeek} • $weekId"),
                                    subtitle: Text(
                                      trainingFree
                                          ? "Trainingsfrei"
                                          : "${ampelLabel(w.ampel)} • ${w.recommendedSessions} Einheiten"
                                            "${w.tournamentNames.isNotEmpty ? "\nTurnier: ${w.tournamentNames.join(', ')}" : ""}",
                                    ),
                                    trailing: trainingFree
                                        ? const Icon(Icons.hotel_outlined)
                                        : Text(ampelLabel(w.ampel)),
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
        final settings = settingsSnap.data?.data() ?? <String, dynamic>{};

        DateTime seasonStart = _defaultSeasonStart();
        final s = settings["seasonStart"]?.toString();
        if (s != null && s.isNotEmpty) {
          seasonStart = DateTime.parse(s);
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: tournamentsRef.snapshots(),
          builder: (context, tSnap) {
            if (tSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final tournaments = (tSnap.data?.docs ?? []).map((d) {
              final m = d.data();
              // Für Anzeige: Name + Ort, ohne PlanEngine zu stören
              final name = (m["name"] ?? "").toString();
              final loc = (m["location"] ?? "").toString();
              if (loc.isNotEmpty) m["name"] = "$name ($loc)";
              return m;
            }).toList();

            final weeks = PlanEngine.buildWeeks(
              ageClass: _age,
              seasonStart: seasonStart,
              numberOfWeeks: 52,
              tournaments: tournaments,
              settings: settings,
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
                    icon: const Icon(Icons.add),
                    onPressed: _addTournamentDialog,
                  ),
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
                        InkWell(
                          onTap: () => _pickSeasonStart(seasonStart),
                          child: Row(
                            children: [
                              Text(
                                "Saisonstart: ${seasonStart.toIso8601String().substring(0, 10)}",
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.edit_calendar_outlined, size: 18),
                            ],
                          ),
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
                              final weekId = w.weekStart.toIso8601String().substring(0, 10);

                              final weekDocStream = FirebaseFirestore.instance
                                  .collection("users")
                                  .doc(widget.uid)
                                  .collection("weeks")
                                  .doc(weekId)
                                  .snapshots();

                              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                stream: weekDocStream,
                                builder: (context, snap) {
                                  final trainingFree = snap.data?.data()?["trainingFree"] == true;

                                  return Container(
                                    color: _weekBackground(w.ampel, trainingFree),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: ListTile(
                                      title: Text("KW ${w.isoWeek} • $weekId"),
                                      subtitle: Text(
                                        trainingFree
                                            ? "Trainingsfrei"
                                            : "${ampelLabel(w.ampel)} • ${w.recommendedSessions} Einheiten"
                                              "${w.tournamentNames.isNotEmpty ? "\nTurnier: ${w.tournamentNames.join(', ')}" : ""}",
                                      ),
                                      trailing: trainingFree
                                          ? const Icon(Icons.hotel_outlined)
                                          : Text(ampelLabel(w.ampel)),
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
