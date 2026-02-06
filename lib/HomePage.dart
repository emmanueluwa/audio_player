import 'dart:convert' show json;
import 'dart:io';

import 'package:audio_player/app_colours.dart' as AppColors;
import 'package:audio_player/detail_audio_page.dart';
import 'package:audio_player/models/audio.dart';
import 'package:audio_player/my_tabs.dart';
import 'package:audio_player/screens/playlists_screen.dart';
import 'package:audio_player/services/audio_service.dart';
import 'package:audio_player/services/auth_service.dart';
import 'package:audio_player/services/download_service.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Audio> audios = [];

  bool isLoading = true;
  String? errorMessage;

  //tracking download status
  Map<int, bool> downloadStatus = {};
  Map<int, double> downloadProgress = {};
  Set<int> currentlyDownloading = {};

  final AuthService _authService = AuthService();
  final AudioService _audioService = AudioService();
  final DownloadService _downloadService = DownloadService();

  Future<void> loadData() async {
    setState(() {
      isLoading = true;

      errorMessage = null;
    });

    try {
      final loggedIn = await _authService.isLoggedIn();
      if (!loggedIn) {
        Navigator.pushReplacementNamed(context, "/login");

        return;
      }

      final List<Audio> audioList = await _audioService.getLibrary();

      //check which files are downloaded
      Map<int, bool> status = {};
      for (var audio in audioList) {
        status[audio.id] = await _downloadService.isDownloaded(audio.id);
      }

      setState(() {
        audios = audioList;

        downloadStatus = status;

        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _downloadAudio(Audio audio) async {
    setState(() {
      currentlyDownloading.add(audio.id);

      downloadProgress[audio.id] = 0.0;
    });

    try {
      await _downloadService.downloadAudio(
        audio: audio,
        onProgress: (progress) {
          setState(() {
            downloadProgress[audio.id] = progress;
          });
        },
      );

      setState(() {
        downloadStatus[audio.id] = true;

        currentlyDownloading.remove(audio.id);

        downloadProgress.remove(audio.id);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Downloaded: ${audio.title}')));
    } catch (e) {
      setState(() {
        currentlyDownloading.remove(audio.id);
        downloadProgress.remove(audio.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Download failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteDownload(Audio audio) async {
    try {
      await _downloadService.deleteDownload(audio.id);

      setState(() {
        downloadStatus[audio.id] = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Deleted: ${audio.title}")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to delete: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();

    loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Colors.black87)),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  "Error loading library",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: loadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                  ),
                  child: Text("Retry"),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Library",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.playlist_play, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PlaylistsScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.black87),
            onPressed: () async {
              await _authService.logout();
              Navigator.pushReplacementNamed(context, "/login");
            },
          ),
        ],
      ),

      body: audios.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.music_note_outlined,
                    size: 64,
                    color: Colors.grey[360],
                  ),
                  SizedBox(height: 16),
                  Text(
                    "No audio files",
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Upload files",
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                ],
              ),
            )
          : ListView.separated(
              itemBuilder: (context, index) {
                final audio = audios[index];

                final isDownloaded = downloadStatus[audio.id] ?? false;
                final isDownloading = currentlyDownloading.contains(audio.id);
                final progress = downloadProgress[audio.id] ?? 0.0;

                return ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isDownloaded
                        ? Stack(
                            children: [
                              Center(
                                child: Icon(
                                  Icons.music_note,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: Container(
                                  padding: EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Icon(Icons.music_note, color: Colors.white, size: 28),
                  ),
                  title: Text(
                    audio.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 4),
                      Text(
                        audio.author,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      if (audio.duration != null)
                        Row(
                          children: [
                            if (audio.duration != null) ...[
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey[400],
                              ),
                              SizedBox(width: 4),
                              Text(
                                _formatDuration(audio.duration!),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                            if (isDownloaded) ...[
                              SizedBox(width: 12),
                              Icon(
                                Icons.offline_pin,
                                size: 14,
                                color: Colors.green,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Offline",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ],
                        ),
                      if (isDownloading) ...[
                        SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[200],
                          color: Colors.blue,
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Downloading ${(progress * 100).toStringAsFixed(0)}%",
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ],
                    ],
                  ),
                  trailing: isDownloading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blue,
                          ),
                        )
                      : PopupMenuButton(
                          icon: Icon(Icons.more_vert, color: Colors.black87),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.play_arrow,
                                    color: Colors.black87,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text("Play"),
                                ],
                              ),
                              onTap: () {
                                Future.delayed(
                                  Duration.zero,
                                  () => _playAudio(audio),
                                );
                              },
                            ),
                            if (!isDownloaded)
                              PopupMenuItem(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.download,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text("Download"),
                                  ],
                                ),
                                onTap: () {
                                  Future.delayed(
                                    Duration.zero,
                                    () => _downloadAudio(audio),
                                  );
                                },
                              ),
                            if (isDownloaded)
                              PopupMenuItem(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text("Delete Download"),
                                  ],
                                ),
                                onTap: () {
                                  Future.delayed(
                                    Duration.zero,
                                    () => _deleteDownload(audio),
                                  );
                                },
                              ),
                          ],
                        ),
                  onTap: () => _playAudio(audio),
                );
              },
              separatorBuilder: (context, index) =>
                  Divider(height: 1, indent: 72),
              itemCount: audios.length,
            ),
    );
  }

  Future<void> _playAudio(Audio audio) async {
    try {
      // if downloaded play from local storage
      final localPath = await _downloadService.getLocalPath(audio.id);

      String audioPath;
      if (localPath != null) {
        audioPath = localPath;
        print("playing from local storage: $localPath");

        final file = File(localPath);
        final exists = await file.exists();

        if (exists) {
          final fileSize = await file.length();
        }
      } else {
        audioPath = await _audioService.getStreamUrl(audio.id);
        print("streaming from cloud");
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetailAudioPage(
            audioData: [
              {
                "id": audio.id,
                "title": audio.title,
                "text": audio.author,
                "audio": audioPath,
              },
            ],
            index: 0,
            isLocal: localPath != null,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to play audio: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}
