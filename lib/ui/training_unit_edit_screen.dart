import 'package:flutter/material.dart';

import '../models/age_class.dart';
import '../models/training_unit.dart';
import '../services/firestore_service.dart';

class TrainingUnitEditScreen extends StatefulWidget {
  final String uid;
  final TrainingUnit? unit;

  const TrainingUnitEditScreen({super.key, required this.uid, this.unit});

  @override
  State<TrainingUnitEditScreen> createState() => _TrainingUnitEditScreenState();
}

class _TrainingUnitEditScreenState extends State<TrainingUnitEditScreen> {
  final _fs = FirestoreService();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _minCtrl;

  final Set<AgeClass> _ages = {AgeClass.u15};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final u = widget.unit;
    _titleCtrl = TextEditingController(text: u?.title ?? "");
    _descCtrl = TextEditingController(text: u?.description ?? "");
    _minCtrl = TextEditingController(text: (u?.minutes ?? 0).toString());
    if (u != null && u.ageClasses.isNotEmpty) {
      _ages
        ..clear()
        ..addAll(u.ageClasses);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.unit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? "Einheit bearbeiten" : "Einheit anlegen"),
        actions: [
          IconButton(
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            onPressed: _busy ? null : _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: "Titel *"),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _minCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Dauer (Minuten)"),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 6,
            decoration: const InputDecoration(labelText: "Beschreibung"),
          ),
          const SizedBox(height: 16),
          const Text("Altersklassen"),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: AgeClass.values.map((a) {
              return FilterChip(
                label: Text(ageClassLabel(a)),
                selected: _ages.contains(a),
                onSelected: (sel) {
                  setState(() {
                    if (sel) {
                      _ages.add(a);
                    } else {
                      if (_ages.length == 1) return;
                      _ages.remove(a);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.save),
            label: Text(editing ? "Speichern" : "Anlegen"),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() => _busy = true);

    final minutes = int.tryParse(_minCtrl.text.trim()) ?? 0;
    final desc = _descCtrl.text.trim();
    final ages = _ages.toList();

    if (widget.unit == null) {
      await _fs.addTrainingUnit(
        widget.uid,
        TrainingUnit(
          id: "",
          title: title,
          description: desc,
          minutes: minutes,
          ageClasses: ages,
        ),
      );
    } else {
      await _fs.updateTrainingUnit(
        widget.uid,
        TrainingUnit(
          id: widget.unit!.id,
          title: title,
          description: desc,
          minutes: minutes,
          ageClasses: ages,
        ),
      );
    }

    if (mounted) Navigator.pop(context);
    setState(() => _busy = false);
  }
}
