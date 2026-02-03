class Playlist {
  final int id;
  final int userId;
  final String name;
  final int audioCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Playlist({
    required this.id,
    required this.userId,
    required this.name,
    required this.audioCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json["id"],
      userId: json["user_id"],
      name: json["name"],
      audioCount: json["audio_count"],
      createdAt: DateTime.parse(json["created_at"]),
      updatedAt: DateTime.parse(json["updated_at"]),
    );
  }
}

class PlaylistDetail {
  final int id;
  final int userId;
  final String name;
  final List<AudioInPlaylist> audioItems;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlaylistDetail({
    required this.id,
    required this.userId,
    required this.name,
    required this.audioItems,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlaylistDetail.fromJson(Map<String, dynamic> json) {
    return PlaylistDetail(
      id: json["id"],
      userId: json["user_id"],
      name: json["name"],
      audioItems: (json["audio_items"] as List)
          .map((item) => AudioInPlaylist.fromJson(item))
          .toList(),
      createdAt: DateTime.parse(json["created_at"]),
      updatedAt: DateTime.parse(json["updated_at"]),
    );
  }
}

class AudioInPlaylist {
  final int id;
  final String title;
  final String author;
  final int? duration;
  final int? fileSize;
  final int position;
  final DateTime addedAt;

  AudioInPlaylist({
    required this.id,
    required this.title,
    required this.author,
    this.duration,
    this.fileSize,
    required this.position,
    required this.addedAt,
  });

  factory AudioInPlaylist.fromJson(Map<String, dynamic> json) {
    return AudioInPlaylist(
      id: json["id"],
      title: json["title"],
      author: json["author"],
      duration: json["duration"],
      fileSize: json["file_size"],
      position: json["position"],
      addedAt: DateTime.parse(json["added_at"]),
    );
  }
}
