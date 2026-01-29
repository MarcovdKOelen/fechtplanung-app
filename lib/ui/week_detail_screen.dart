
// dependencies:
//   pdf: ^3.10.8
//   printing: ^5.12.0
//
// Danach: flutter pub get

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/week_plan.dart';

class WeekDetailScreen extends StatelessWidget {
  final String uid;
  final WeekPlan week;

  const WeekDetailScreen({
    super.key,
    required this.uid,
    required this.week,
  });

  // DE Datum: TT.MM.JJJJ (ohne intl)
  String _d(DateTime d) {
    String two(int n) => n < 10 ? "0$n" : "$n";
    return "${two(d.day)}.${two(d.month)}.${d.year}";
  }

  String _weekdayLabel(int i) {
    const days = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"];
    return days[i];
  }

  bool _isWarmup(String s) => s.trim().toLowerCase() == "aufwärmung";

  bool _isMobility(String s) {
    final t = s.trim().toLowerCase();
    return t.startsWith("mobilität");
  }

  bool _isStretchStab(String s) =>
      s.trim().toLowerCase() == "dehnung/stabilität";

  bool _isCoordination(String s) => s.trim().toLowerCase() == "koordination";
  bool _isReaction(String s) => s.trim().toLowerCase() == "reaktion";

  // Slot 3/4: alles außer Aufwärmung + Mobilität + Dehnung
  bool _isExcludedFromRestPool(String s) =>
      _isWarmup(s) || _isMobility(s) || _isStretchStab(s);

  int _stableSeedForDay(DateTime weekStart, int dayIndex) {
    final base = "${weekStart.toIso8601String()}|$dayIndex|$uid";
    int hash = 0;
    for (final c in base.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return hash;
  }

  // Slot 2 Optionen: Mobilität* / Dehnung/Stabilität / Koordination / Reaktion
  List<String> _slot2Options(List<String> pool) {
    final opts = <String>[];
    opts.addAll(pool.where(_isMobility));
    opts.addAll(pool.where(_isStretchStab));
    opts.addAll(pool.where(_isCoordination));
    opts.addAll(pool.where(_isReaction));
    final dedup = opts.toSet().toList()..sort();
    return dedup;
  }

  // Slot 3 & 4: alles außer Aufwärmung + Mobilität + Dehnung
  List<String> _restOptions(List<String> pool) {
    final opts =
        pool.where((e) => !_isExcludedFromRestPool(e)).toSet().toList()..sort();
    return opts;
  }

  // Basis-Empfehlungen je Trainingstag (4 Slots):
  // Slot1: Aufwärmung
  // Slot2: zufällig 1 aus (Mobilität/Dehnung/Koordination/Reaktion)
  // Slot3+Slot4: zufällig aus Rest (ohne Aufwärmung/Mobilität/Dehnung), ohne Duplikat zum Slot2
  List<String> _baseFourRecsForDay(int dayIndex, List<String> pool) {
    final rng = Random(_stableSeedForDay(week.weekStart, dayIndex));

    const warmup = "Aufwärmung";
    final slot2 = _slot2Options(pool);
    final rest = _restOptions(pool).toList()..shuffle(rng);

    final out = <String>[warmup];

    String slot2Pick = "Training";
    if (slot2.isNotEmpty) {
      slot2Pick = slot2[rng.nextInt(slot2.length)];
    }
    out.add(slot2Pick);

    int i = 0;
    while (out.length < 4) {
      if (i < rest.length) {
        final c = rest[i++];
        if (c == slot2Pick) continue;
        if (!out.contains(c)) out.add(c);
      } else {
        out.add("Training");
      }
    }

    return out.take(4).toList();
  }

  List<String> _allowedOptionsForSlot(int slotIndex, List<String> pool) {
    if (slotIndex == 0) return const ["Aufwärmung"];
    if (slotIndex == 1) return _slot2Options(pool);
    return _restOptions(pool);
  }

  List<String> _applyOverrideIfAny({
    required int dayIndex,
    required Map<String, dynamic> dayOverrides,
    required List<String> base,
    required List<String> pool,
  }) {
    final raw = dayOverrides[dayIndex.toString()];
    if (raw is! List) return base;

    final overridden = raw.map((e) => e.toString()).toList();
    if (overridden.length != 4) return base;
    if (overridden[0] != "Aufwärmung") return base;

    for (int i = 0; i < 4; i++) {
      final allowed = _allowedOptionsForSlot(i, pool);
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
    required List<String> pool,
  }) async {
    if (slotIndex == 0) return;

    final options = _allowedOptionsForSlot(slotIndex, pool);
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
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
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

  Future<void> _downloadWeekPdf({
    required bool trainingFree,
    required Set<int> trainingDays,
    required Map<String, dynamic> dayOverrides,
    required List<String> pool,
    required String weekDocId,
  }) async {
    final start = week.weekStart;
    final end = week.weekStart.add(const Duration(days: 6));
    final title = "Trainingswoche KW ${week.isoWeek}";
    final dateRange = "${_d(start)} – ${_d(end)}";

    final doc = pw.Document();

    // Build Tagesblöcke
    final dayBlocks = <pw.Widget>[];
    for (int i = 0; i < 7; i++) {
      final date = week.weekStart.add(Duration(days: i));
      final isTrainingDay = trainingDays.contains(i) && !trainingFree;

      List<String> recs = const [];
      if (isTrainingDay) {
        final base = _baseFourRecsForDay(i, pool);
        recs = _applyOverrideIfAny(
          dayIndex: i,
          dayOverrides: dayOverrides,
          base: base,
          pool: pool,
        );
      }

      dayBlocks.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 1),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "${_weekdayLabel(i)} • ${_d(date)}",
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              if (!isTrainingDay)
                pw.Text("Kein Trainingstag",
                    style: const pw.TextStyle(fontSize: 11))
              else
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: recs
                      .map((r) => pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 2),
                            child: pw.Text("• $r",
                                style: const pw.TextStyle(fontSize: 11)),
                          ))
                      .toList(),
                ),
            ],
          ),
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        build: (_) => [
          pw.Text(title,
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(dateRange, style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 12),
          if (trainingFree)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey600, width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Text(
                "Diese Woche ist trainingsfrei.",
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            )
          else ...[
            pw.Text("Trainingstage & Einheiten:",
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            ...dayBlocks,
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    final fileName = "KW_${week.isoWeek}_${weekDocId.replaceAll('-', '')}.pdf";

    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  @override
  Widget build(BuildContext context) {
    final weekDocId = week.weekStart.toIso8601String().substring(0, 10);

    final weekRef = FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("weeks")
        .doc(weekDocId);

    final pool = week.recommendations;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: weekRef.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final trainingFree = data["trainingFree"] == true;

        final trainingDays = (data["trainingDays"] as List? ?? [])
            .map((e) => int.tryParse(e.toString()) ?? -1)
            .where((i) => i >= 0 && i <= 6)
            .toSet();

        final dayOverrides = (data["dayOverrides"] is Map)
            ? Map<String, dynamic>.from(data["dayOverrides"] as Map)
            : <String, dynamic>{};

        Future<void> _setTrainingFree(bool v) async {
          if (v) {
            await weekRef.set(
              {
                "trainingFree": true,
                "trainingDays": [],
                "dayOverrides": {},
              },
              SetOptions(merge: true),
            );
          } else {
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
              "trainingFree": false,
              "trainingDays": list,
            },
            SetOptions(merge: true),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text("KW ${week.isoWeek} • Details"),
            actions: [
              IconButton(
                tooltip: "PDF herunterladen",
                icon: const Icon(Icons.picture_as_pdf_outlined),
                onPressed: () => _downloadWeekPdf(
                  trainingFree: trainingFree,
                  trainingDays: trainingDays,
                  dayOverrides: dayOverrides,
                  pool: pool,
                  weekDocId: weekDocId,
                ),
              ),
            ],
          ),
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
                    selected: trainingDays.contains(i),
                    onSelected: trainingFree
                        ? null
                        : (v) {
                            final next = {...trainingDays};
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
                      final isDay = trainingDays.contains(dayIndex);
                      final dateStr =
                          _d(week.weekStart.add(Duration(days: dayIndex)));

                      final base = _baseFourRecsForDay(dayIndex, pool);
                      final recs = _applyOverrideIfAny(
                        dayIndex: dayIndex,
                        dayOverrides: dayOverrides,
                        base: base,
                        pool: pool,
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
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            title: Text(dateStr),
                            subtitle: !isDay
                                ? const Text("Kein Trainingstag")
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                            pool: pool,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 2),
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
            ],
          ),
        );
      },
    );
  }
}
