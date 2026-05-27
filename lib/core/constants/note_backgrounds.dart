enum NoteBackground {
  none,
  food,
  umbrella,
  nature,
  galaxy,
  music,
}

extension NoteBackgroundExt on NoteBackground {
  String? get assetPath {
    if (this == NoteBackground.none) return null;
    return 'assets/backgrounds/$name.png';
  }
  
  String get label {
    return name[0].toUpperCase() + name.substring(1);
  }
}