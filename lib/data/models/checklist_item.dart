class ChecklistItem {
  final String id;
  final String noteId;
  String text;
  bool isChecked;
  int sortOrder;

  ChecklistItem({
    required this.id,
    required this.noteId,
    required this.text,
    this.isChecked = false,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'noteId': noteId,
    'text': text,
    'isChecked': isChecked ? 1 : 0,
    'sortOrder': sortOrder,
  };

  factory ChecklistItem.fromMap(Map<String, dynamic> m) => ChecklistItem(
    id: m['id'],
    noteId: m['noteId'],
    text: m['text'],
    isChecked: m['isChecked'] == 1,
    sortOrder: m['sortOrder'],
  );
}