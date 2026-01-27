import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/age_class.dart';
import '../models/week_plan.dart';
import '../services/plan_engine.dart';
return Scaffold( // <-- const HIER entfernen
  appBar: AppBar(
    title: const Text("Wochenplan"),
    actions: [
      IconButton(
        icon: const Icon(Icons.logout),
        onPressed: () => FirebaseAuth.instance.signOut(),
      ),
    ],
  ),
  body: ...
);
