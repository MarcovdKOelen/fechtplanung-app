import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'import_screen.dart';

class WeekPlanScreen extends StatelessWidget {
  final String uid;
  const WeekPlanScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Wochenplan"),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ImportScreen(uid: uid)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Text(
          "Import ist bereit ✅\n\nÖffne oben das Upload-Icon.",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
