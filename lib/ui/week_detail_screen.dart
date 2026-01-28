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

  List<int> _defaultTrainingDays() => const [0, 1, 3, 4]; // fallback (Mo, Di, Do, Fr)

  List<int> _sanitizeDays(dynamic v) {
    final list = (v is List) ? v : const [];
    final days = list.map((e) => int.tryParse(e.toString()) ?? -1).where((x) => x >= 0 && x <= 6).toSet().toList();
    days.sort();
    return days;
  }

  Map<int, String> _buildDayPlan({
    required List<int> trainingDays,
  }) {
    final result = <int, String>{};

    if (trainingDays.isEmpty) return result;

    final sessions = week.recommendedSessions;
    final recs = week.recommendations;

    final count = sessions.clamp(0, trainingDays.length);
    for (int i = 0; i < count; i++) {
      final dayIndex = trainingDays[i];
      final label = (i < recs.length) ? recs[i] : "Training";
      result[dayIndex] = label;
    }

    return result;
  }

  Future<void> _openTrainingDaysEditor(BuildContext context, List<int> current) async {
    final selected = current.toSet();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(Icons.calendar_month_outlined),
                    SizedBox(width: 8),
                    Text(
                      "Trainingstage festlegen",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (i) {
                    final label = _weekdayLabel(i);
                    final isOn = selected.contains(i);
                    return FilterChip(
                      label: Text(label),
                      selected: isOn,
                      onSelected: (val) {
                        if (val) {
                          selected.add(i);
                        } else {
                          selected.remove(i);
                        }
                        // ignore: invalid_use_of_protected_member
                        (context as Element).markNeedsBuild();
                      },
                    );
                  }),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text("Speichern"),
                    onPressed: () async {
                      final days = selected.toList()..sort();
                      final ref = FirebaseFirestore.instance
                          .collection("users")
                          .doc(uid)
                          .collection("settings")
                          .doc("main");

                      await ref.set(
                        {
                          "trainingDays": days,
                          "updatedAt": DateTime.now().toIso8601String(),
                        },
                        SetOptions(merge: true),
                      );

                      if (context.mounted) Navigator.pop(context);
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
        .doc(uid)
        .collection("settings")
        .doc("main");

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: settingsRef.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final trainingDays = _sanitizeDays(data["trainingDays"]);
        final effectiveDays = trainingDays.isEmpty ? _defaultTrainingDays() : trainingDays;

        final dayPlan = _buildDayPlan(trainingDays: effectiveDays);

        return Scaffold(
          appBar: AppBar(
            title: Text("KW ${week.isoWeek} • Details"),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_calendar_outlined),
                onPressed: () => _openTrainingDaysEditor(context, effectiveDays),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                          const SizedBox(height: 6),
                          Text("Trainingstage: ${effectiveDays.map(_weekdayLabel).join(", ")}"),
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
              const Text(
                "Wochenübersicht",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              Card(
                child: Column(
                  children: List.generate(7, (i) {
                    final dayDate = _day(i);
                    final isTrainingDay = effectiveDays.contains(i);
                    final label = dayPlan[i];

                    final subtitle = !isTrainingDay
                        ? "Kein Trainingstag"
                        : (label == null ? "Training (ohne konkrete Empfehlung)" : "Empfehlung: $label");

                    return Column(
                      children: [
                        ListTile(
                          dense: true,
                          leading: SizedBox(
                            width: 42,
                            child: Center(
                              child: Text(
                                _weekdayLabel(i),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          title: Text(_d(dayDate)),
                          subtitle: Text(subtitle),
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

