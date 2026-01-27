import 'package:flutter/material.dart';

import '../models/week_plan.dart';
import '../models/age_class.dart';
import '../models/training_unit.dart';
import '../services/firestore_service.dart';

class WeekDetailScreen extends StatefulWidget {
  final String uid;
  final String scopeId;
  final String scopeLabel;
  final AgeClass ageClass;
  final WeekPlan week;

  const WeekDetailScreen({
    super.key,
    required this.uid,
    required this.scopeId,
    required this.scopeLabel,
    required this.ageClass,
    required this.week,
  });

  @override
  State<WeekDetailScreen> createState() => _WeekDetailScreenState();
}

class _WeekDetailScreenState extends State<WeekDetailScreen> {
  final _fs = FirestoreService();

  String _d(DateTime d) => d.toIso8601String().substring(0, 10);
  String get _weekKey => _d(widget.week.weekStart);

  @override
  Widget build(BuildContext context) {
    final start = widget.week.weekStart;
    final end = widget.week.weekStart.add(const Duration(days: 6));

    return Scaffold(
      appBar: AppBar(
        title: Text("KW ${widget.week.isoWeek} • ${ageClassLabel(widget.ageClass)} • ${widget.scopeLabel}"),
      ),
      body: StreamBuilder<List<TrainingUnit>>(
        stream: _fs.watchTrainingUnits(widget.uid),
        builder: (context, unitsSnap) {
          final allUnits = unitsSnap.data ?? const <TrainingUnit>[];

          return StreamBuilder<Map<String, dynamic>?>(
            stream: _fs.watchWeekOverride(
              widget.uid,
              scopeId: widget.scopeId,
              ageClassName: widget.ageClass.name,
              weekStartIsoDate: _weekKey,
            ),
            builder: (context, ovSnap) {
              final ov = ovSnap.data ?? {};
              final List<dynamic> raw = (ov["unitIds"] as List?) ?? const [];

              final slotCount = widget.week.recommendedSessions;
              final List<String?> unitIds = List<String?>.generate(
                slotCount,
                (i) => i < raw.length ? (raw[i] as String?) : null,
              );

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Zeitraum: ${_d(start)} – ${_d(end)}",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text("Ampel: ${ampelLabel(widget.week.ampel)}"),
                          Text("Einheiten: $slotCount"),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Trainingseinheiten (Tippen zum Austauschen)",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          for (int i = 0; i < slotCount; i++)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.fitness_center),
                              title: Text(_slotTitle(i, unitIds, allUnits)),
                              subtitle: Text(_slotSubtitle(i, unitIds, allUnits)),
                              trailing: const Icon(Icons.swap_horiz),
                              onTap: () => _pickUnitForSlot(i, unitIds, allUnits),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Turniere in dieser Woche", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),
                          if (widget.week.tournamentNames.isEmpty)
                            const Text("Keine Turniere in dieser Woche.")
                          else
                            ...widget.week.tournamentNames.map((t) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.emoji_events),
                                  title: Text(t),
                                )),
                        ],
                      ),
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

  String _slotTitle(int i, List<String?> unitIds, List<TrainingUnit> units) {
    final id = unitIds[i];
    if (id == null || id.isEmpty) {
      final fallback = (i < widget.week.recommendations.length) ? widget.week.recommendations[i] : "Empfehlung";
      return "Slot ${i + 1}: $fallback";
    }
    final u = units.where((x) => x.id == id).cast<TrainingUnit?>().firstWhere((x) => x != null, orElse: () => null);
    return u == null ? "Slot ${i + 1}: (Unbekannt) → Default" : "Slot ${i + 1}: ${u.title}";
  }

  String _slotSubtitle(int i, List<String?> unitIds, List<TrainingUnit> units) {
    final id = unitIds[i];
    if (id == null || id.isEmpty) return "Default-Empfehlung";
    final u = units.where((x) => x.id == id).cast<TrainingUnit?>().firstWhere((x) => x != null, orElse: () => null);
    if (u == null) return "Einheit nicht gefunden";
    final mins = u.minutes > 0 ? " • ${u.minutes} min" : "";
    return (u.description.trim().isEmpty) ? "Aus Katalog$mins" : "${u.description}$mins";
  }

  Future<void> _pickUnitForSlot(int slotIndex, List<String?> current, List<TrainingUnit> all) async {
    final units = all.where((u) => u.ageClasses.isEmpty || u.ageClasses.contains(widget.ageClass)).toList();

    final picked = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text("Default-Empfehlung verwenden"),
              onTap: () => Navigator.pop(context, null),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: units.length,
                itemBuilder: (_, i) {
                  final u = units[i];
                  final mins = u.minutes > 0 ? " • ${u.minutes} min" : "";
                  return ListTile(
                    leading: const Icon(Icons.fitness_center),
                    title: Text(u.title),
                    subtitle: Text(u.description.isEmpty ? "Katalog$mins" : "${u.description}$mins"),
                    onTap: () => Navigator.pop(context, u.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    final next = List<String?>.from(current);
    next[slotIndex] = picked; // null => default
    await _fs.saveWeekOverrideUnitIds(
      widget.uid,
      scopeId: widget.scopeId,
      ageClassName: widget.ageClass.name,
      weekStartIsoDate: _weekKey,
      unitIds: next,
    );
  }
}
