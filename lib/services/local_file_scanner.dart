import 'dart:io';

import 'package:audio_player/models/audio.dart';
import 'package:permission_handler/permission_handler.dart';

class LocalFileScanner {
  static const String SYNC_FOLDER = "/storage/emulated/0/Idaeho";

  //requesting storage permission
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.audio.request();

      if (status.isGranted) {
        return true;
      }

      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }

      return false;
    }

    //ios does not need permission for apps own files
    return true;
  }

  //scan local symc folder for MP3 files
  Future<List<Audio>> scanLocalFiles() async {
    print("scanning local files in: $SYNC_FOLDER");

    try {
      final syncDir = Directory(SYNC_FOLDER);

      if (!await syncDir.exists()) {
        print("sync folder does not exist yet");

        return [];
      }

      final files = syncDir.listSync();
      final audioFiles = <Audio>[];

      for (var file in files) {
        if (file is File) {
          final path = file.path;

          //only process audio files
          if (path.toLowerCase().endsWith(".mp3") ||
              path.toLowerCase().endsWith(".m4a") ||
              path.toLowerCase().endsWith(".wav")) {
            final audio = await _createAudioFromFile(file);

            if (audio != null) {
              audioFiles.add(audio);
            }
          }
        }
      }

      print("found ${audioFiles.length} local files");
      return audioFiles;
    } catch (e) {
      print("error scanning files: $e");

      return [];
    }
  }

  //creating audio object from local file
  Future<Audio?> _createAudioFromFile(File file) async {
    try {
      final filename = file.path.split("/").last;

      final stats = await file.stat();

      //getting title from filename
      final titleWithExtension = filename;
      final title = titleWithExtension
          .substring(0, titleWithExtension.lastIndexOf("."))
          .replaceAll("_", " ");

      //netage id indicates local-only files
      final localId = -filename.hashCode;

      return Audio(
        id: localId,
        userId: 0,
        title: title,
        author: "Unkown",
        fileUrl: file.path,
        duration: null,
        fileSize: stats.size,
        createdAt: stats.modified,
        updatedAt: stats.modified,
      );
    } catch (e) {
      print("error creating audio from file: $e");

      return null;
    }
  }

  Future<bool> syncFolderExists() async {
    final dir = Directory(SYNC_FOLDER);

    return await dir.exists();
  }

  Future<void> createSyncFolder() async {
    final dir = Directory(SYNC_FOLDER);

    if (!await dir.exists()) {
      await dir.create(recursive: true);
      print("created sync folder: $SYNC_FOLDER");
    }
  }

  Future<int> getLocalFileCount() async {
    try {
      final syncDir = Directory(SYNC_FOLDER);

      if (!await syncDir.exists()) {
        return 0;
      }

      // .listSync() returns a list
      final files = syncDir.listSync();

      return files.where((f) {
        if (f is File) {
          final path = f.path.toLowerCase();

          return path.endsWith(".mp3") ||
              path.endsWith(".m4a") ||
              path.endsWith(".wav");
        }

        return false;
      }).length;
    } catch (e) {
      return 0;
    }
  }
}
