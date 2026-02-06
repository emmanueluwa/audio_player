import 'dart:io';

import 'package:audio_player/database/local_db.dart';
import 'package:audio_player/models/audio.dart';
import 'package:audio_player/services/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class DownloadService {
  final Dio _dio = Dio();
  final LocalDatabase _localDb = LocalDatabase.instance;

  final AudioService _audioService = AudioService();

  Future<Directory> _getAudioDirectory() async {
    final Directory baseDir = Platform.isAndroid
        ? (await getExternalStorageDirectory())!
        : await getApplicationDocumentsDirectory();

    final audioDir = Directory("${baseDir.path}/Audio");

    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }

    return audioDir;
  }

  Future<String> downloadAudio({
    required Audio audio,
    Function(double)? onProgress,
  }) async {
    try {
      final downloadUrl = await _audioService.getDownloadUrl(audio.id);

      final downloadsDir = await _getAudioDirectory();

      final safeTitle = audio.title
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .substring(0, audio.title.length > 50 ? 50 : audio.title.length);

      final filename = '${audio.id}_$safeTitle.mp3';
      final filePath = '${downloadsDir.path}/$filename';

      print("saving to: $filePath");

      await _dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;

            print("progress: ${(progress * 100).toStringAsFixed(0)}%");

            onProgress?.call(progress);
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 10),
        ),
      );

      //verify file exists and has content
      final file = File(filePath);
      if (!await file.exists() || await file.length() == 0) {
        throw Exception("Download failed - file is empty or missing");
      }

      print("download complete");

      //saving to local db
      await _localDb.insertDownloadedAudio({
        "audio_id": audio.id,
        "title": audio.title,
        "author": audio.author,
        "duration": audio.duration,
        "file_size": audio.fileSize,
        "local_path": filePath,
        "download_date": DateTime.now().toIso8601String(),
        "created_at": audio.createdAt.toIso8601String(),
      });

      print("saved to local db");

      return filePath;
    } catch (e) {
      try {
        final audioDir = await _getAudioDirectory();

        final safeTitle = audio.title
            .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
            .replaceAll(RegExp(r'\s+'), '_')
            .substring(0, audio.title.length > 50 ? 50 : audio.title.length);

        final filename = "${audio.id}_$safeTitle.mp3";

        final file = File("${audioDir.path}/$filename");

        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}

      //keep original stack trace
      rethrow;
    }
  }

  Future<bool> isDownloaded(int audioId) async {
    final audio = await _localDb.getDownloadedAudioById(audioId);
    if (audio == null) return false;

    final file = File(audio["local_path"] as String);
    if (!await file.exists()) {
      await _localDb.deleteDownloadedAudio(audioId);

      return false;
    }

    return true;
  }

  Future<String?> getLocalPath(int audioId) async {
    final audio = await _localDb.getDownloadedAudioById(audioId);
    if (audio == null) return null;

    final path = audio["local_path"] as String;

    //sync db with file system
    final file = File(path);
    if (!await file.exists()) {
      await _localDb.deleteDownloadedAudio(audioId);

      return null;
    }

    return path;
  }

  Future<List<Map<String, dynamic>>> getDownloadedAudio() async {
    final downloads = await _localDb.getDownloadedAudio();

    //filter out files that dont exist
    final validDownloads = <Map<String, dynamic>>[];
    for (final download in downloads) {
      final file = File(download['local_path'] as String);

      if (await file.exists()) {
        validDownloads.add(download);
      } else {
        await _localDb.deleteDownloadedAudio(download["audio_id"] as int);
      }
    }

    return validDownloads;
  }

  Future<void> deleteDownload(int audioId) async {
    final audio = await _localDb.getDownloadedAudioById(audioId);
    if (audio == null) return;

    final path = audio["local_path"] as String;
    final file = File(path);

    if (await file.exists()) {
      await file.delete();
    }

    await _localDb.deleteDownloadedAudio(audioId);
  }

  Future<int> getTotalStorageUsed() async {
    final downloads = await getDownloadedAudio();

    int total = 0;

    for (final download in downloads) {
      final file = File(download["local_path"] as String);

      if (await file.exists()) {
        total += await file.length();
      }
    }

    return total;
  }

  Future<void> clearAllDownloads() async {
    final audioDir = await _getAudioDirectory();

    if (await audioDir.exists()) {
      await audioDir.delete(recursive: true);
      await audioDir.create();
    }

    final db = await LocalDatabase.instance.database;
    await db.delete("downloaded_audio");
  }
}
