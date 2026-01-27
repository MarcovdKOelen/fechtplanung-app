import 'package:flutter/material.dart';

import '../models/athlete.dart';
import '../models/age_class.dart';
import '../services/firestore_service.dart';
import 'setup_screen.dart';

class AthletesScreen extends StatefulWidget {
  final String uid;
  const AthletesScreen({super.key, required this.uid});

  @override
  State<AthletesScreen> createState() => _AthletesScreenState();
}

class _AthletesScreenState extends State<AthletesScreen> {
  final _fs = FirestoreService();

  final _nameCtrl = TextEditingController();
  AgeClass _age = AgeClass.u15;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Athleten")),
      body: StreamBuilder(
        stream: _fs.watchAthletes(widget.uid),
        builder: (context, snapshot) {
          final athletes = (snapshot.data as List<Athlete>?) ?? const [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: "Name"),
                      ),
                      const SizedBox(height: 10),
                      DropdownButton<AgeClass>(
                        value: _age,
                        items: AgeClass.values
                            .map((a) => DropdownMenuItem(value: a, child: Text(ageClassLabel(a))))
                            .toList(),
                        onChanged: (v) => setState(() => _age = v ?? AgeClass.u15),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final name = _nameCtrl.text.trim();
                            if (name.isEmpty) return;
                            final id = await _fs.addAthlete(widget.uid, Athlete(id: "", name: name, ageClass: _age));
                            _nameCtrl.clear();
                            if (!mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => SetupScreen(uid: widget.uid, scopeId: id)),
                            );
                          },
                          child: const Text("Athlet hinzufügen"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final a in athletes)
                ListTile(
                  title: Text(a.name),
                  subtitle: Text(ageClassLabel(a.ageClass)),
                  trailing: const Icon(Icons.settings),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SetupScreen(uid: widget.uid, scopeId: a.id)),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
