import 'age_class.dart';

class TrainingUnit {
  final String id;
  final String title;
  final String description;
  final int minutes;
  final List<AgeClass> ageClasses;

  TrainingUnit({
    required this.id,
    required this.title,
    required this.description,
    required this.minutes,
    required this.ageClasses,
  });

  static TrainingUnit fromDoc(String id, Map<String, dynamic> d) {
    final ages = (d["ageClasses"] as List? ?? const [])
        .map((x) => parseAgeClass(x.toString()))
        .whereType<AgeClass>()
        .toList();

    return TrainingUnit(
      id: id,
      title: (d["title"] ?? "").toString(),
      description: (d["description"] ?? "").toString(),
      minutes: (d["minutes"] is num) ? (d["minutes"] as num).toInt() : 0,
      ageClasses: ages,
    );
  }

  Map<String, dynamic> toMap() => {
        "title": title,
        "description": description,
        "minutes": minutes,
        "ageClasses": ageClasses.map((a) => a.name).toList(),
        "updatedAt": DateTime.now().toIso8601String(),
      };
}
