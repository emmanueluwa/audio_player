import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB("audio_player.db");

    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    //download audio files table
    await db.execute('''
  CREATE TABLE downloaded_audio (
    id INTEGER PRIMARY KEY,
    audio_id INTEGER UNIQUE NOT NULL,
    title TEXT NOT NULL,
    author TEXT NOT NULL,
    duration INTEGER,
    file_size INTEGER,
    local_path TEXT NOT NULL,
    download_date TEXT NOT NULL,
    created_at TEXT NOT NULL
  )
  ''');

    //download queue table (active/pending downloads)
    await db.execute('''
  CREATE TABLE download_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    audio_id INTEGER UNIQUE NOT NULL,
    title TEXT NOT NULL,
    author TEXT NOT NULL,
    download_url TEXT NOT NULL,
    status TEXT NOT NULL,
    progress REAL DEFAULT 0,
    created_at TEXT NOT NULL
  )
''');

    await db.execute('''
  CREATE TABLE cached_playlists (
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    audio_count INTEGER NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    synced_at TEXT NOt NULL
  )
''');

    await db.execute('''
  CREATE TABLE cached_playlist_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    playlist_id INTEGER NOT NULL,
    audio_id INTEGER NOT NULL,
    position INTEGER NOT NULL,
    title TEXT NOT NULL,
    author TEXT NOT NULL,
    duration INTEGER,
    added_at TEXT NOT NULL
  )
''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
    CREATE TABLE IF NOT EXISTS cached_playlists (
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    audio_count INTEGER NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    synced_at TEXT NOT NULL
    )
''');

      await db.execute('''
  CREATE TABLE IF NOT EXISTS cached_playlist_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    playlist_id INTEGER NOT NULL,
    audio_id INTEGER NOT NULL,
    position INTEGER NOT NULL,
    title TEXT NOT NULL,
    author TEXT NOT NULL,
    duration INTEGER,
    added_at TEXT NOT NULL
  )
''');
    }

    if (oldVersion < 3) {
      await db.execute("DROP TABLE IF EXISTS cached_playlists");
      await db.execute("DROP TABLE IF EXISTS cached_playlist_items");

      await db.execute('''
      CREATE TABLE cached_playlists (
      id INTEGER PRIMARY KEY,
      user_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      audio_count INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      synced_at TEXT NOT NULL)
''');

      await db.execute('''
      CREATE TABLE cached_playlist_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      playlist_id INTEGER NOT NULL,
      audio_id INTEGER NOT NULL,
      position INTEGER NOT NULL,
      title TEXT NOT NULL,
      author TEXT NOT NULL,
      duration INTEGER,
      added_at TEXT NOT NULL
      )
''');
    }
  }

  Future<void> insertDownloadedAudio(Map<String, dynamic> audio) async {
    final db = await database;

    await db.insert(
      "downloaded_audio",
      audio,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getDownloadedAudio() async {
    final db = await database;

    return await db.query('downloaded_audio', orderBy: 'download_date DESC');
  }

  Future<Map<String, dynamic>?> getDownloadedAudioById(int audioId) async {
    final db = await database;

    final results = await db.query(
      "downloaded_audio",
      where: "audio_id = ?",
      whereArgs: [audioId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return results.first;
  }

  Future<bool> isAudioDownloaded(int audioId) async {
    final result = await getDownloadedAudioById(audioId);

    return result != null;
  }

  Future<void> deleteDownloadedAudio(int audioId) async {
    final db = await database;

    await db.delete(
      "downloaded_audio",
      where: "audio_id = ?",
      whereArgs: [audioId],
    );
  }

  // queue operations
  Future<void> addToDownloadQueue(Map<String, dynamic> item) async {
    final db = await database;

    await db.insert(
      "download_queue",
      item,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getDownloadQueue() async {
    final db = await database;

    return await db.query("download_queue", orderBy: "created_at ASC");
  }

  Future<void> updateDownloadProgress(int audioId, double progress) async {
    final db = await database;

    await db.update(
      "download_queue",
      {"progress": progress, "status": "downloading"},
      where: "audio_id = ?",
      whereArgs: [audioId],
    );
  }

  Future<void> removeFromDownloadQueue(int audioId) async {
    final db = await database;

    await db.delete(
      "download_queue",
      where: "audio_id = ?",
      whereArgs: [audioId],
    );
  }

  Future<void> cachePlaylists(List<Map<String, dynamic>> playlists) async {
    final db = await database;

    await db.delete("cached_playlists");

    for (var playlist in playlists) {
      await db.insert("cached_playlists", {
        ...playlist,
        'synced_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<Map<String, dynamic>>> getCachedPlaylists() async {
    final db = await database;

    return await db.query("cached_playlists", orderBy: "created_at DESC");
  }

  Future<void> cachePlaylistItems(
    int playlistId,
    List<Map<String, dynamic>> items,
  ) async {
    final db = await database;

    await db.delete(
      "cached_playlist_items",
      where: "playlist_id = ?",
      whereArgs: [playlistId],
    );

    for (var item in items) {
      await db.insert("cached_playlist_items", {
        "playlist_id": playlistId,
        ...item,
      });
    }
  }

  Future<List<Map<String, dynamic>>> getCachedPlaylistItems(
    int playlistId,
  ) async {
    final db = await database;

    return await db.query(
      "cached_playlist_items",
      where: "playlist_id = ?",
      whereArgs: [playlistId],
      orderBy: "position ASC",
    );
  }

  Future<void> clearPlaylistCache() async {
    final db = await database;

    await db.delete("cached_playlists");
    await db.delete("cached_playlist_itmes");
  }

  Future<void> close() async {
    final db = await database;

    await db.close();
  }
}
