import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/athlete.dart';
import '../models/tournament.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      _db.collection("users").doc(uid);

  DocumentReference<Map<String, dynamic>> profileRef(String uid) =>
      userDoc(uid).collection("meta").doc("profile");

  DocumentReference<Map<String, dynamic>> settingsRef(String uid, {String scopeId = "self"}) =>
      userDoc(uid).collection("scopes").doc(scopeId).collection("settings").doc("main");

  CollectionReference<Map<String, dynamic>> tournamentsRef(String uid, {String scopeId = "self"}) =>
      userDoc(uid).collection("scopes").doc(scopeId).collection("tournaments");

  CollectionReference<Map<String, dynamic>> athletesRef(String uid) =>
      userDoc(uid).collection("athletes");

  Stream<Map<String, dynamic>?> watchProfile(String uid) =>
      profileRef(uid).snapshots().map((d) => d.data());

  Future<void> ensureDefaults(String uid) async {
    final p = await profileRef(uid).get();
    if (!p.exists) {
      await profileRef(uid).set({
        "role": "trainer", // trainer | sportler
        "createdAt": DateTime.now().toIso8601String(),
      });
    }
    final s = await settingsRef(uid, scopeId: "self").get();
    if (!s.exists) {
      await settingsRef(uid, scopeId: "self").set({
        "seasonStart": DateTime(DateTime.now().month >= 10 ? DateTime.now().year : DateTime.now().year - 1, 10, 1).toIso8601String(),
        "sessions": {
          "u13": {"gruen": 4, "gelb": 3, "rot": 2},
          "u15": {"gruen": 4, "gelb": 3, "rot": 2},
          "u17": {"gruen": 4, "gelb": 3, "rot": 2},
          "u20": {"gruen": 4, "gelb": 3, "rot": 2},
        },
        "recommendations": {
          "gruen": ["Athletik Basis", "Beinarbeit Volumen", "Technik/Taktik", "Gefechte intensiv"],
          "gelb": ["Technik/Taktik", "Gefechte kurz", "Athletik kurz"],
          "rot": ["Aktivierung + Technik", "Locker Technik"],
        },
        "updatedAt": DateTime.now().toIso8601String(),
      });
    }
  }

  Stream<Map<String, dynamic>> watchSettings(String uid, {String scopeId = "self"}) =>
      settingsRef(uid, scopeId: scopeId).snapshots().map((d) => d.data() ?? {});

  Stream<List<Tournament>> watchTournaments(String uid, {String scopeId = "self"}) =>
      tournamentsRef(uid, scopeId: scopeId).snapshots().map((q) =>
          q.docs.map((d) => Tournament.fromDoc(d.id, d.data())).toList());

  Future<void> replaceAllTournaments(String uid, List<Map<String, dynamic>> items, {String scopeId = "self"}) async {
    final col = tournamentsRef(uid, scopeId: scopeId);
    final existing = await col.get();
    final batch = _db.batch();
    for (final d in existing.docs) {
      batch.delete(d.reference);
    }
    for (final item in items) {
      batch.set(col.doc(), item);
    }
    await batch.commit();
  }

  Stream<List<Athlete>> watchAthletes(String uid) =>
      athletesRef(uid).snapshots().map((q) => q.docs.map((d) => Athlete.fromDoc(d.id, d.data())).toList());

  Future<String> addAthlete(String uid, Athlete a) async {
    final ref = await athletesRef(uid).add(a.toMap());
    // create scope defaults for athlete
    await settingsRef(uid, scopeId: ref.id).set({
      "seasonStart": DateTime(DateTime.now().month >= 10 ? DateTime.now().year : DateTime.now().year - 1, 10, 1).toIso8601String(),
      "sessions": {
        "u13": {"gruen": 4, "gelb": 3, "rot": 2},
        "u15": {"gruen": 4, "gelb": 3, "rot": 2},
        "u17": {"gruen": 4, "gelb": 3, "rot": 2},
        "u20": {"gruen": 4, "gelb": 3, "rot": 2},
      },
      "recommendations": {
        "gruen": ["Athletik Basis", "Beinarbeit Volumen", "Technik/Taktik", "Gefechte intensiv"],
        "gelb": ["Technik/Taktik", "Gefechte kurz", "Athletik kurz"],
        "rot": ["Aktivierung + Technik", "Locker Technik"],
      },
      "updatedAt": DateTime.now().toIso8601String(),
    });
    return ref.id;
  }

  Future<void> saveProfileRole(String uid, String role) async {
    await profileRef(uid).set({"role": role, "updatedAt": DateTime.now().toIso8601String()}, SetOptions(merge: true));
  }

  Future<void> saveSeasonStart(String uid, DateTime d, {String scopeId = "self"}) async {
    await settingsRef(uid, scopeId: scopeId).set({"seasonStart": d.toIso8601String(), "updatedAt": DateTime.now().toIso8601String()}, SetOptions(merge: true));
  }

  Future<void> saveSessions(String uid, Map<String, dynamic> sessions, {String scopeId = "self"}) async {
    await settingsRef(uid, scopeId: scopeId).set({"sessions": sessions, "updatedAt": DateTime.now().toIso8601String()}, SetOptions(merge: true));
  }
}
