import 'age_class.dart';

class Athlete {
  final String id;
  final String name;
  final AgeClass ageClass;

  Athlete({required this.id, required this.name, required this.ageClass});

  Map<String, dynamic> toMap() => {
        "name": name,
        "ageClass": ageClass.name,
        "updatedAt": DateTime.now().toIso8601String(),
      };

  static Athlete fromDoc(String id, Map<String, dynamic> d) {
    return Athlete(
      id: id,
      name: (d["name"] ?? "").toString(),
      ageClass: parseAgeClass((d["ageClass"] ?? "u15").toString()) ?? AgeClass.u15,
    );
  }
}
