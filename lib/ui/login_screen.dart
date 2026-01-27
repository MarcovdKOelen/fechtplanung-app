import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/age_class.dart';
import '../models/week_plan.dart';
import '../services/plan_engine.dart';

class WeekPlanScreen extends StatefulWidget {
  final String uid;
  const WeekPlanScreen({super.key, required this.uid});

  @override
  State<WeekPlanScreen> createState() => _WeekPlanScreenState();
}

class _WeekPlanScreenState extends State<WeekPlanScreen> {
  AgeClass _selectedAge = AgeClass.u15;
  DateTime _seasonStart = DateTime(DateTime.now().month >= 10 ? DateTime.now().year : DateTime.now().year - 1, 10, 1);

  @override
  Widget build(BuildContext context) {
    final settingsRef = FirebaseFirestore.instance
        .collection("users")
        .doc(widget.uid)
        .collection("settings")
        .doc("main");

    final tournamentsRef = FirebaseFirestore.instance
        .collection("users")
        .doc(widget.uid)
        .collection("tournaments");

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
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: settingsRef.snapshots(),
        builder: (context, settingsSnap) {
          // seasonStart from Firestore (optional)
          if (settingsSnap.hasData && settingsSnap.data!.exists) {
            final data = settingsSnap.data!.data();
            final s = data?["seasonStart"]?.toString();
            if (s != null) {
              _seasonStart = DateTime.parse(s);
            }
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: tournamentsRef.snapshots(),
            builder: (context, tourSnap) {
              if (tourSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final tournaments = (tourSnap.data?.docs ?? [])
                  .map((d) => d.data())
                  .toList();

              final weeks = PlanEngine.buildWeeks(
                ageClass: _selectedAge,
                seasonStart: _seasonStart,
                numberOfWeeks: 52,
                tournaments: tournaments,
              );

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        DropdownButton<AgeClass>(
                          value: _selectedAge,
                          items: AgeClass.values
                              .map((a) => DropdownMenuItem(
                                    value: a,
                                    child: Text(ageClassLabel(a)),
                                  ))
                              .toList(),
                          onChanged: (a) {
                            if (a == null) return;
