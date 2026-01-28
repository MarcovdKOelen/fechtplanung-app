import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/age_class.dart';
import '../models/tournament.dart';
import '../services/firestore_service.dart';
import '../services/plan_engine.dart';
import '../services/export_service.dart';
import '../services/share_file.dart';

import 'import_screen.dart';
import 'setup_screen.dart';
import 'athletes_screen.dart';
import 'export_sheet.dart';

class WeekPlanScreen extends StatefulWidget {
  final String uid;
  const WeekPlanScreen({super.key, required this.uid});

  @override
  State<WeekPlanScreen> createState() => _WeekPlanScreenState();
}

class _WeekPlanScreenState extends State<WeekPlanScreen> with SingleTickerProviderStateMixin {
  final _fs = FirestoreService();

  String _scopeId = "self"; // "self" oder athleteId
  String _scopeLabel = "Ich";

  late final TabController _tabs = TabController(length: AgeClass.values.length, vsync: this);

  @override
  void initState() {
    super.initState();
    _fs.ensureDefaults(widget.uid);
  }

  AgeClass get _activeAge => AgeClass.values[_tabs.index];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Wochenplan • $_scopeLabel"),
        bottom: TabBar(
          controller: _tabs,
          tabs: AgeClass.values.map((a) => Tab(text: ageClassLabel(a))).toList(),
          onTap: (_) => setState(() {}),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ImportScreen(uid: widget.uid, scopeId: _scopeId),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _export(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SetupScreen(uid: widget.uid, scopeId: _scopeId),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () async {
              final profile = await _fs.profileRef(widget.uid).get();
              final role = (profile.data()?["role"] ?? "trainer").toString();
              if (!mounted) return;
              if (role != "trainer") return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AthletesScreen(uid: widget.uid)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _fs.watchProfile(widget.uid),
        builder: (context, profileSnap) {
          final role = (profileSnap.data?["role"] ?? "trainer").toString();

          return Column(
            children: [
              if (role == "trainer") _scopePicker(),
              Expanded(
                child: StreamBuilder(
                  stream: _fs.watchSettings(widget.uid, scopeId: _scopeId),
                  builder: (context, settingsSnap) {
                    final settings = (settingsSnap.data as Map<String, dynamic>?) ?? {};
                    final seasonStartStr = (settings["seasonStart"] ?? DateTime.now().toIso8601String()).toString();
                    final seasonStart = DateTime.parse(seasonStartStr);

                    return StreamBuilder(
                      stream: _fs.watchTournaments(widget.uid, scopeId: _scopeId),
                      builder: (context, tSnap) {
                        final tournaments = (tSnap.data as List<Tournament>?) ?? const <Tournament>[];

                        final weeks = PlanEngine.buildWeeks(
                          ageClass: _activeAge,
                          seasonStart: seasonStart,
                          numberOfWeeks: 52,
                          tournaments: tournaments,
                          settings: settings,
                        );

                        return ListView.separated(
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
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _scopePicker() {
    return StreamBuilder(
      stream: _fs.watchAthletes(widget.uid),
      builder: (context, snap) {
        final athletes = (snap.data as List?)?.cast() ?? const [];
        final items = <DropdownMenuItem<String>>[
          const DropdownMenuItem(value: "self", child: Text("Ich")),
          for (final a in athletes) DropdownMenuItem(value: a.id, child: Text(a.name)),
        ];

        return Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text("Bereich: "),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _scopeId,
                items: items,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _scopeId = v;
                    _scopeLabel = v == "self"
                        ? "Ich"
                        : (athletes.firstWhere((x) => x.id == v).name);
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _export(BuildContext context) async {
    final sDoc = await _fs.settingsRef(widget.uid, scopeId: _scopeId).get();
    final settings = sDoc.data() ?? {};
    final seasonStart = DateTime.parse((settings["seasonStart"] ?? DateTime.now().toIso8601String()).toString());

    final tQ = await _fs.tournamentsRef(widget.uid, scopeId: _scopeId).get();
    final t = tQ.docs.map((d) => Tournament.fromDoc(d.id, d.data())).toList();

    final weeks = PlanEngine.buildWeeks(
      ageClass: _activeAge,
      seasonStart: seasonStart,
      numberOfWeeks: 52,
      tournaments: t,
      settings: settings,
    );

    ExportSheet.show(
      context,
      onXlsx: () async {
        final bytes = ExportService.toXlsx(tournaments: t, weeks: weeks);
        await ShareFile.shareBytes(
          bytes: bytes,
          fileName: "Fechtplanung_${_scopeLabel}_${ageClassLabel(_activeAge)}.xlsx",
          mimeType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        );
      },
      onTournamentsCsv: () async {
        final bytes = ExportService.tournamentsCsv(t);
        await ShareFile.shareBytes(
          bytes: bytes,
          fileName: "Turniere_${_scopeLabel}.csv",
          mimeType: "text/csv",
        );
      },
      onWeeksCsv: () async {
        final bytes = ExportService.weekplanCsv(weeks);
        await ShareFile.shareBytes(
          bytes: bytes,
          fileName: "Wochenplan_${_scopeLabel}_${ageClassLabel(_activeAge)}.csv",
          mimeType: "text/csv",
        );
      },
    );
  }
}
