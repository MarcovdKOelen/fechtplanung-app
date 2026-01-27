import 'package:flutter/material.dart';

import '../models/age_class.dart';
import '../services/firestore_service.dart';

class SetupScreen extends StatefulWidget {
  final String uid;
  final String scopeId; // "self" or athleteId
  const SetupScreen({super.key, required this.uid, required this.scopeId});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _fs = FirestoreService();

  DateTime _seasonStart = DateTime(DateTime.now().month >= 10 ? DateTime.now().year : DateTime.now().year - 1, 10, 1);

  Map<String, dynamic> _sessions = {
    "u13": {"gruen": 4, "gelb": 3, "rot": 2},
    "u15": {"gruen": 4, "gelb": 3, "rot": 2},
    "u17": {"gruen": 4, "gelb": 3, "rot": 2},
    "u20": {"gruen": 4, "gelb": 3, "rot": 2},
  };

  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Setup")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            ListTile(
              title: const Text("Saisonstart"),
              subtitle: Text(_seasonStart.toIso8601String().substring(0, 10)),
              trailing: const Icon(Icons.date_range),
              onTap: _busy ? null : () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _seasonStart,
                  firstDate: DateTime(2020, 1, 1),
                  lastDate: DateTime(2035, 12, 31),
                );
                if (picked != null) setState(() => _seasonStart = DateTime(picked.year, picked.month, picked.day));
              },
            ),
            const Divider(),
            const Text("Einheiten pro Ampel (pro Altersklasse)"),
            const SizedBox(height: 12),
            for (final a in AgeClass.values) ...[
              _sessionsCard(a),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
              label: const Text("Speichern"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionsCard(AgeClass a) {
    final m = (_sessions[a.name] as Map<String, dynamic>);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ageClassLabel(a), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _numField("Grün", m["gruen"], (v) => m["gruen"] = v)),
              const SizedBox(width: 10),
              Expanded(child: _numField("Gelb", m["gelb"], (v) => m["gelb"] = v)),
              const SizedBox(width: 10),
              Expanded(child: _numField("Rot", m["rot"], (v) => m["rot"] = v)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _numField(String label, dynamic value, void Function(int) setVal) {
    final ctrl = TextEditingController(text: (value ?? 0).toString());
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: (s) {
        final v = int.tryParse(s.trim()) ?? 0;
        setVal(v);
      },
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    await _fs.saveSeasonStart(widget.uid, _seasonStart, scopeId: widget.scopeId);
    await _fs.saveSessions(widget.uid, _sessions, scopeId: widget.scopeId);
    if (mounted) Navigator.pop(context);
    setState(() => _busy = false);
  }
}
