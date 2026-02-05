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

    return await openDatabase(path, version: 1, onCreate: _createDB);
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

  Future<void> close() async {
    final db = await database;

    await db.close();
  }
}
