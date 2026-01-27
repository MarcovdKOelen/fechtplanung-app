import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/athlete.dart';
import '../models/tournament.dart';
import '../models/training_unit.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> userDoc(String uid) => _db.collection("users").doc(uid);

  DocumentReference<Map<String, dynamic>> profileRef(String uid) =>
      userDoc(uid).collection("meta").doc("profile");

  DocumentReference<Map<String, dynamic>> settingsRef(String uid, {String scopeId = "self"}) =>
      userDoc(uid).collection("scopes").doc(scopeId).collection("settings").doc("main");

  CollectionReference<Map<String, dynamic>> tournamentsRef(String uid, {String scopeId = "self"}) =>
      userDoc(uid).collection("scopes").doc(scopeId).collection("tournaments");

  CollectionReference<Map<String, dynamic>> athletesRef(String uid) => userDoc(uid).collection("athletes");

  // Trainingseinheiten-Katalog (pro User)
  CollectionReference<Map<String, dynamic>> trainingUnitsRef(String uid) =>
      userDoc(uid).collection("training_units");

  // Overrides pro Woche (pro scope)
  CollectionReference<Map<String, dynamic>> weekOverridesRef(String uid, {String scopeId = "self"}) =>
      userDoc(uid).collection("scopes").doc(scopeId).collection("week_overrides");

  DocumentReference<Map<String, dynamic>> weekOverrideDoc(
    String uid, {
    required String scopeId,
    required String ageClassName,
    required String weekStartIsoDate, // yyyy-mm-dd
  }) =>
      weekOverridesRef(uid, scopeId: scopeId).doc("${ageClassName}_$weekStartIsoDate");

  Stream<Map<String, dynamic>?> watchProfile(String uid) =>
      profileRef(uid).snapshots().map((d) => d.data());

  Future<void> ensureDefaults(String uid) async {
    final p = await profileRef(uid).get();
    if (!p.exists) {
      await profileRef(uid).set({
        "role": "trainer",
        "createdAt": DateTime.now().toIso8601String(),
      });
    }

    final s = await settingsRef(uid, scopeId: "self").get();
    if (!s.exists) {
      await settingsRef(uid, scopeId: "self").set({
        "seasonStart": DateTime(DateTime.now().month >= 10 ? DateTime.now().year : DateTime.now().year - 1, 10, 1)
            .toIso8601String(),
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

    // Seed-Katalog, falls leer
    final tu = await trainingUnitsRef(uid).limit(1).get();
    if (tu.docs.isEmpty) {
      final batch = _db.batch();
      final col = trainingUnitsRef(uid);

      batch.set(col.doc(), {
        "title": "Beinarbeit Leiter (Koordination)",
        "description": "8–12 Min Koordination + Fußarbeit, Fokus Rhythmus/Distanz.",
        "minutes": 15,
        "ageClasses": ["u13", "u15", "u17", "u20"],
        "updatedAt": DateTime.now().toIso8601String(),
      });

      batch.set(col.doc(), {
        "title": "Technik: Parade-Riposte (Florett)",
        "description": "Technikblock: 3 Serien à 6 Wiederholungen, dann Partnerdrill.",
        "minutes": 25,
        "ageClasses": ["u15", "u17", "u20"],
        "updatedAt": DateTime.now().toIso8601String(),
      });

      batch.set(col.doc(), {
        "title": "Gefechte kurz (5 Treffer)",
        "description": "Mehrere kurze Gefechte, Fokus Aufgaben & Feedback.",
        "minutes": 30,
        "ageClasses": ["u13", "u15", "u17", "u20"],
        "updatedAt": DateTime.now().toIso8601String(),
      });

      await batch.commit();
    }
  }

  Stream<Map<String, dynamic>> watchSettings(String uid, {String scopeId = "self"}) =>
      settingsRef(uid, scopeId: scopeId).snapshots().map((d) => d.data() ?? {});

  Stream<List<Tournament>> watchTournaments(String uid, {String scopeId = "self"}) =>
      tournamentsRef(uid, scopeId: scopeId)
          .snapshots()
          .map((q) => q.docs.map((d) => Tournament.fromDoc(d.id, d.data())).toList());

  Stream<List<Athlete>> watchAthletes(String uid) =>
      athletesRef(uid).snapshots().map((q) => q.docs.map((d) => Athlete.fromDoc(d.id, d.data())).toList());

  Future<String> addAthlete(String uid, Athlete a) async {
    final ref = await athletesRef(uid).add(a.toMap());
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

  Future<void> saveSeasonStart(String uid, DateTime d, {String scopeId = "self"}) async {
    await settingsRef(uid, scopeId: scopeId).set(
      {"seasonStart": d.toIso8601String(), "updatedAt": DateTime.now().toIso8601String()},
      SetOptions(merge: true),
    );
  }

  Future<void> saveSessions(String uid, Map<String, dynamic> sessions, {String scopeId = "self"}) async {
    await settingsRef(uid, scopeId: scopeId).set(
      {"sessions": sessions, "updatedAt": DateTime.now().toIso8601String()},
      SetOptions(merge: true),
    );
  }

  // Katalog stream
  Stream<List<TrainingUnit>> watchTrainingUnits(String uid) => trainingUnitsRef(uid)
      .orderBy("title")
      .snapshots()
      .map((q) => q.docs.map((d) => TrainingUnit.fromDoc(d.id, d.data())).toList());

  // CRUD Katalog
  Future<String> addTrainingUnit(String uid, TrainingUnit u) async {
    final ref = await trainingUnitsRef(uid).add(u.toMap());
    return ref.id;
  }

  Future<void> updateTrainingUnit(String uid, TrainingUnit u) async {
    await trainingUnitsRef(uid).doc(u.id).set(u.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteTrainingUnit(String uid, String unitId) async {
    await trainingUnitsRef(uid).doc(unitId).delete();
  }

  // Override stream
  Stream<Map<String, dynamic>?> watchWeekOverride(
    String uid, {
    required String scopeId,
    required String ageClassName,
    required String weekStartIsoDate,
  }) =>
      weekOverrideDoc(uid, scopeId: scopeId, ageClassName: ageClassName, weekStartIsoDate: weekStartIsoDate)
          .snapshots()
          .map((d) => d.data());

  // Override speichern: Liste von Unit-IDs pro Slot, null => Default
  Future<void> saveWeekOverrideUnitIds(
    String uid, {
    required String scopeId,
    required String ageClassName,
    required String weekStartIsoDate,
    required List<String?> unitIds,
  }) async {
    await weekOverrideDoc(uid, scopeId: scopeId, ageClassName: ageClassName, weekStartIsoDate: weekStartIsoDate).set({
      "unitIds": unitIds,
      "updatedAt": DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }
}
