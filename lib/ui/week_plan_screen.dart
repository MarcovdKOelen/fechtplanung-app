import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Text(
          "Willkommen!\nUID:\n$uid",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
