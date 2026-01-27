import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/age_class.dart';
import '../services/import_service.dart';

class ImportScreen extends StatefulWidget {
  final String uid;
  final String scopeId; // "self" oder athleteId
  const ImportScreen({super.key, required this.uid, this.scopeId = "self"});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  Uint8List? _bytes;
  String? _fileName;
  bool _isXlsx = false;

  List<String> _sheetNames = [];
  String? _sheet;

  List<String> _headers = [];
  List<List<dynamic>> _preview = [];

  int? _nameCol;
  int? _startCol;
  int? _endCol;
  int? _mainCol;
  int? _ageCol;

  final Set<AgeClass> _fallbackAges = {AgeClass.u15};

  bool _busy = false;
  String? _status;

  @override
  Widget build(BuildContext context) {
    final mappingOk = _nameCol != null && _startCol != null;

    return Scaffold(
      appBar: AppBar(title: const Text("Import (Excel/CSV)")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            ElevatedButton.icon(
              onPressed: _busy ? null : _pickFile,
              icon: const Icon(Icons.attach_file),
              label: const Text("Datei auswählen"),
            ),
            const SizedBox(height: 8),
            Text(_fileName ?? "Keine Datei gewählt"),

            if (_isXlsx && _sheetNames.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text("Sheet: "),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _sheet,
                    items: _sheetNames.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: _busy
                        ? null
                        : (v) async {
                            setState(() {
                              _sheet = v;
                              _headers = [];
                              _preview = [];
                            });
                            await _loadPreview();
                          },
                  ),
                ],
              ),
            ],

            if (_headers.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text("Vorschau (erste Zeilen):"),
              const SizedBox(height: 8),
              SizedBox(
                height: 140,
                child: ListView.builder(
                  itemCount: _preview.length,
                  itemBuilder: (_, i) => Text(
                    _preview[i].map((e) => (e ?? "").toString()).join(" | "),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text("Spalten-Mapping:"),
              const SizedBox(height: 8),
              _col("Turniername*", _nameCol, (v) => setState(() => _nameCol = v)),
              _col("Startdatum*", _startCol, (v) => setState(() => _startCol = v)),
              _col("Enddatum", _endCol, (v) => setState(() => _endCol = v), allowNone: true),
              _col("Hauptturnier", _mainCol, (v) => setState(() => _mainCol = v), allowNone: true),
              _col("Altersklasse", _ageCol, (v) => setState(() => _ageCol = v), allowNone: true),

              const SizedBox(height: 12),
              const Text("Fallback-Altersklassen:"),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: AgeClass.values.map((a) {
                  return FilterChip(
                    label: Text(ageClassLabel(a)),
                    selected: _fallbackAges.contains(a),
                    onSelected: (sel) {
                      setState(() {
                        if (sel) {
                          _fallbackAges.add(a);
                        } else {
                          if (_fallbackAges.length == 1) return;
                          _fallbackAges.remove(a);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: (_busy || !mappingOk) ? null : _runImportReplace,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.playlist_add_check),
                label: const Text("Import starten (Ersetzen)"),
              ),
            ],

            if (_status != null) ...[
              const SizedBox(height: 12),
              Text(_status!, style: const TextStyle(fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _col(String label, int? value, ValueChanged<int?> onChanged, {bool allowNone = false}) {
    final items = <DropdownMenuItem<int?>>[];
    if (allowNone) items.add(const DropdownMenuItem<int?>(value: null, child: Text("—")));
    for (int i = 0; i < _headers.length; i++) {
      items.add(DropdownMenuItem<int?>(value: i, child: Text("${i + 1}: ${_headers[i]}")));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          DropdownButton<int?>(
            value: value,
            items: items,
            onChanged: _busy ? null : onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    setState(() {
      _status = null;
      _busy = false;

      _bytes = null;
      _fileName = null;
      _isXlsx = false;

      _sheetNames = [];
      _sheet = null;

      _headers = [];
      _preview = [];

      _nameCol = null;
      _startCol = null;
      _endCol = null;
      _mainCol = null;
      _ageCol = null;
    });

    final res = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ["xlsx", "csv"],
    );
    if (res == null || res.files.isEmpty) return;

    final f = res.files.first;
    if (f.bytes == null) {
      setState(() => _status = "Konnte Datei nicht lesen.");
      return;
    }

    final name = f.name;
    final isXlsx = name.toLowerCase().endsWith(".xlsx");

    setState(() {
      _bytes = f.bytes!;
      _fileName = name;
      _isXlsx = isXlsx;
    });

    if (_isXlsx) {
      final excel = Excel.decodeBytes(_bytes!);
      final names = excel.sheets.keys.toList();
      setState(() {
        _sheetNames = names;
        _sheet = names.isNotEmpty ? names.first : null;
      });
    }

    await _loadPreview();
  }

  Future<void> _loadPreview() async {
    final bytes = _bytes;
    if (bytes == null) return;

    try {
      if (_isXlsx) {
        final sheetName = _sheet;
        if (sheetName == null) return;

        final excel = Excel.decodeBytes(bytes);
        final sheet = excel.sheets[sheetName];
        if (sheet == null || sheet.rows.isEmpty) return;

        final headerRow = sheet.rows.first;
        final headers = <String>[];
        for (final c in headerRow) {
          final v = c?.value;
          final s = (v ?? "").toString().trim();
          headers.add(s.isEmpty ? "(leer)" : s);
        }

        final preview = <List<dynamic>>[];
        for (int i = 1; i < sheet.rows.length && preview.length < 12; i++) {
          preview.add(sheet.rows[i].map((c) => c?.value).toList());
        }

        setState(() {
          _headers = headers;
          _preview = preview;
        });
      } else {
        final text = String.fromCharCodes(bytes);
        final lines = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
        if (lines.isEmpty) return;

        final delim = (lines.first.contains(';') && !lines.first.contains(',')) ? ';' : ',';
        List<String> splitLine(String l) => l.split(delim);

        final headers = splitLine(lines.first).map((e) {
          final s = e.trim();
          return s.isEmpty ? "(leer)" : s;
        }).toList();

        final preview = <List<dynamic>>[];
        for (int i = 1; i < lines.length && preview.length < 12; i++) {
          preview.add(splitLine(lines[i]));
        }

        setState(() {
          _headers = headers;
          _preview = preview;
        });
      }

      _autoSuggestMapping();
    } catch (e) {
      setState(() => _status = "Preview-Fehler: $e");
    }
  }

  void _autoSuggestMapping() {
    int? findCol(List<String> keys) {
      final up = _headers.map((h) => h.toUpperCase()).toList();
      for (int i = 0; i < up.length; i++) {
        final h = up[i];
        for (final k in keys) {
          if (h.contains(k.toUpperCase())) return i;
        }
      }
      return null;
    }

    setState(() {
      _nameCol ??= findCol(["TURNIER", "WETTKAMPF", "EVENT", "NAME"]);
      _startCol ??= findCol(["START", "VON", "BEGINN", "DATUM"]);
      _endCol ??= findCol(["ENDE", "BIS"]);
      _mainCol ??= findCol(["HAUPT", "MAIN"]);
      _ageCol ??= findCol(["ALTER", "KLASSE", "KATEGORIE", "U13", "U15", "U17", "U20"]);
    });
  }

  Future<void> _runImportReplace() async {
    final bytes = _bytes;
    if (bytes == null) return;
    if (_nameCol == null || _startCol == null) return;

    setState(() {
      _busy = true;
      _status = null;
    });

    try {
      final fs = FirebaseFirestore.instance;

      final settingsRef = fs
          .collection("users")
          .doc(widget.uid)
          .collection("scopes")
          .doc(widget.scopeId)
          .collection("settings")
          .doc("main");

      final settings = await settingsRef.get();

      DateTime seasonStart = DateTime(DateTime.now().month >= 10 ? DateTime.now().year : DateTime.now().year - 1, 10, 1);
      final s = settings.data()?["seasonStart"]?.toString();
      if (s != null) seasonStart = DateTime.parse(s);

      final mapping = ImportMapping(
        nameCol: _nameCol!,
        startCol: _startCol!,
        endCol: _endCol,
        isMainCol: _mainCol,
        ageClassCol: _ageCol,
      );

      final fallback = _fallbackAges.toList();

      List<Map<String, dynamic>> parsed;
      if (_isXlsx) {
        final sheetName = _sheet;
        if (sheetName == null) throw Exception("Kein Sheet gewählt.");
        parsed = ImportService.parseXlsx(
          bytes: bytes,
          sheetName: sheetName,
          mapping: mapping,
          seasonStart: seasonStart,
          fallbackAgeClasses: fallback,
        );
      } else {
        parsed = ImportService.parseCsv(
          bytes: bytes,
          mapping: mapping,
          seasonStart: seasonStart,
          fallbackAgeClasses: fallback,
        );
      }

      if (parsed.isEmpty) {
        setState(() => _status = "Keine Turniere erkannt.");
        return;
      }

      final col = fs
          .collection("users")
          .doc(widget.uid)
          .collection("scopes")
          .doc(widget.scopeId)
          .collection("tournaments");

      final existing = await col.get();
      final batch = fs.batch();
      for (final d in existing.docs) {
        batch.delete(d.reference);
      }
      for (final t in parsed) {
        batch.set(col.doc(), t);
      }
      await batch.commit();

      setState(() => _status = "Import OK: ${parsed.length} Turniere übernommen.");
    } catch (e) {
      setState(() => _status = "Import-Fehler: $e");
    } finally {
      setState(() => _busy = false);
    }
  }
}
