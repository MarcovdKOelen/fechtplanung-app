import 'age_class.dart';

class Tournament {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final bool isMain;
  final List<AgeClass> ageClasses;

  Tournament({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.isMain,
    required this.ageClasses,
  });

  Map<String, dynamic> toMap() => {
        "name": name,
        "startDate": startDate.toIso8601String(),
        "endDate": endDate.toIso8601String(),
        "isMain": isMain,
        "ageClasses": ageClasses.map((a) => a.name).toList(),
        "updatedAt": DateTime.now().toIso8601String(),
      };

  static Tournament fromDoc(String id, Map<String, dynamic> d) {
    final ages = (d["ageClasses"] as List? ?? const [])
        .map((x) => parseAgeClass(x.toString()) ?? AgeClass.u15)
        .toList();
    return Tournament(
      id: id,
      name: (d["name"] ?? "").toString(),
      startDate: DateTime.parse(d["startDate"].toString()),
      endDate: DateTime.parse(d["endDate"].toString()),
      isMain: (d["isMain"] ?? false) == true,
      ageClasses: ages,
    );
  }
}
