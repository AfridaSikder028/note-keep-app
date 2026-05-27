import 'package:uuid/uuid.dart';

class Label {
  final String id;
  final String name;
  final int colorValue;

  const Label({
    required this.id,
    required this.name,
    this.colorValue = -1,
  });

  factory Label.create({required String name}) {
    return Label(
      id: const Uuid().v4(),
      name: name,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
  };

  factory Label.fromMap(Map<String, dynamic> m) => Label(
    id: m['id'],
    name: m['name'],
    colorValue: m['colorValue'] ?? -1,
  );

  Label copyWith({String? name, int? colorValue}) {
    return Label(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
    );
  }
}