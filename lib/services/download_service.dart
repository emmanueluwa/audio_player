import 'dart:io';

import 'package:audio_player/database/local_db.dart';
import 'package:audio_player/models/audio.dart';
import 'package:audio_player/services/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadService {
  final Dio _dio = Dio();
  final LocalDatabase _localDb = LocalDatabase.instance;

  final AudioService _audioService = AudioService();

  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      if (await Permission.storage.isGranted) {
        return true;
      }

      //for android 13+
      // if (Platform.version.contains("13") || Platform.version.contains("14")) {
      //   final status = await Permission.audio.request();

      //   return status.isGranted;
      // }
      final sdkInt = int.parse(Platform.operatingSystemVersion.split(' ')[1]);
      if (sdkInt >= 33) {
        final status = await Permission.audio.request();

        return status.isGranted;
      }

      //for older android versions
      final status = await Permission.storage.request();

      return status.isGranted;
    }

    return true;
  }

  Future<Directory> getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      //using apps external storage directory
      final dir = await getExternalStorageDirectory();

      final audioDir = Directory("${dir!.path}/Audio");
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      return audioDir;
    } else {
      // ios use documents directory
      final dir = await getApplicationDocumentsDirectory();

      final audioDir = Directory("${dir.path}/Audio");
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      return audioDir;
    }
  }

  Future<String> downloadAudio({
    required Audio audio,
    Function(double)? onProgress,
  }) async {
    final hasPermission = await requestStoragePermission();
    if (!hasPermission) {
      throw Exception("Storage permission denied");
    }

    final downloadUrl = await _audioService.getDownloadUrl(audio.id);
    print("download url obtained");

    final downloadsDir = await getDownloadsDirectory();

    final safeTitle = audio.title
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');

    final filename = '${audio.id}_$safeTitle.mp3';
    final filePath = '${downloadsDir.path}/$filename';

    print("saving to: $filePath");

    await _dio.download(
      downloadUrl,
      filePath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          final progress = received / total;

          print("progress: ${(progress * 100).toStringAsFixed(0)}%");

          onProgress?.call(progress);
        }
      },
    );

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
  }

  Future<bool> isDownloaded(int audioId) async {
    return await _localDb.isAudioDownloaded(audioId);
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
}
