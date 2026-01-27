import 'package:flutter/material.dart';

import '../models/training_unit.dart';
import '../services/firestore_service.dart';
import 'training_unit_edit_screen.dart';

class TrainingUnitsScreen extends StatelessWidget {
  final String uid;
  const TrainingUnitsScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trainingseinheiten-Katalog"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TrainingUnitEditScreen(uid: uid)),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<TrainingUnit>>(
        stream: fs.watchTrainingUnits(uid),
        builder: (context, snap) {
          final units = snap.data ?? const <TrainingUnit>[];

          if (units.isEmpty) {
            return const Center(child: Text("Noch keine Trainingseinheiten im Katalog."));
          }

          return ListView.separated(
            itemCount: units.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final u = units[i];
              final mins = u.minutes > 0 ? " • ${u.minutes} min" : "";
              return ListTile(
                leading: const Icon(Icons.fitness_center),
                title: Text(u.title),
                subtitle: Text((u.description.isEmpty ? "Katalog$mins" : "${u.description}$mins")),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == "edit") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TrainingUnitEditScreen(uid: uid, unit: u),
                        ),
                      );
                      return;
                    }
                    if (v == "delete") {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Löschen?"),
                          content: Text("„${u.title}“ wirklich löschen?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Abbrechen")),
                            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Löschen")),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await fs.deleteTrainingUnit(uid, u.id);
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: "edit", child: Text("Bearbeiten")),
                    PopupMenuItem(value: "delete", child: Text("Löschen")),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrainingUnitEditScreen(uid: uid, unit: u),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
