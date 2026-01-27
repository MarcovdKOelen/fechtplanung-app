import 'package:flutter/material.dart';

class ExportSheet {
  static void show(
    BuildContext context, {
    required VoidCallback onXlsx,
    required VoidCallback onTournamentsCsv,
    required VoidCallback onWeeksCsv,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text("Export als Excel (.xlsx)"),
              onTap: () {
                Navigator.pop(context);
                onXlsx();
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: const Text("Export Turniere als CSV"),
              onTap: () {
                Navigator.pop(context);
                onTournamentsCsv();
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: const Text("Export Wochenplan als CSV"),
              onTap: () {
                Navigator.pop(context);
                onWeeksCsv();
              },
            ),
          ],
        ),
      ),
    );
  }
}
