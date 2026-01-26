class Audio {
  final int id;
  final int userId;
  final String title;
  final String author;
  final String category;
  final String fileUrl;
  final int? duration;
  final int? fileSize;
  final DateTime createdAt;
  final DateTime updatedAt;

  Audio({
    required this.id,
    required this.userId,
    required this.title,
    required this.author,
    required this.category,
    required this.fileUrl,
    this.duration,
    this.fileSize,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Audio.fromJson(Map<String, dynamic> json) {
    return Audio(
      id: json["id"],
      userId: json["user_id"],
      title: json["title"],
      author: json["author"],
      category: json["author"],
      fileUrl: json["fileUrl"],
      duration: json["duration"],
      fileSize: json["fileSize"],
      createdAt: DateTime.parse(json["created_at"]),
      updatedAt: DateTime.parse(json["updated_at"]),
    );
  }

  Map<String, dynamic> toDisplayJson() {
    return {"id": id, "title": title, "text": author, "audio": fileUrl};
  }
}
