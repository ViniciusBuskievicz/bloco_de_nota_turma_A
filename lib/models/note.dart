class Note {
  final int? id;
  final String cloudId;
  final String uid;
  final String title;
  final String content;
  final String category;
  final int updatedAt;
  final String date;

  const Note({
    this.id,
    required this.cloudId,
    required this.uid,
    required this.title,
    required this.content,
    this.category = 'Geral',
    required this.updatedAt,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'cloudId': cloudId,
        'uid': uid,
        'title': title,
        'content': content,
        'category': category,
        'updatedAt': updatedAt,
        'date': date,
      };

  Map<String, dynamic> toCloudMap() => {
        'uid': uid,
        'title': title,
        'content': content,
        'category': category,
        'updatedAt': updatedAt,
        'date': date,
      };

  factory Note.fromMap(Map<String, dynamic> map) => Note(
        id: map['id'] as int?,
        cloudId: map['cloudId'] as String? ?? 'legacy_${map['id']}',
        uid: map['uid'] as String,
        title: map['title'] as String,
        content: map['content'] as String,
        category: map['category'] as String? ?? 'Geral',
        updatedAt: map['updatedAt'] as int? ?? 0,
        date: map['date'] as String,
      );

  factory Note.fromCloud(String cloudId, Map<String, dynamic> map) => Note(
        cloudId: cloudId,
        uid: map['uid'] as String,
        title: map['title'] as String? ?? '',
        content: map['content'] as String? ?? '',
        category: map['category'] as String? ?? 'Geral',
        updatedAt: map['updatedAt'] as int? ?? 0,
        date: map['date'] as String? ?? '',
      );

  Note withId(int value) => Note(
        id: value,
        cloudId: cloudId,
        uid: uid,
        title: title,
        content: content,
        category: category,
        updatedAt: updatedAt,
        date: date,
      );
}
