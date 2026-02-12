import 'dart:io';

import 'package:audio_player/database/local_db.dart';
import 'package:audio_player/detail_audio_page.dart';
import 'package:audio_player/models/audio.dart';
import 'package:audio_player/screens/playlists_screen.dart';
import 'package:audio_player/screens/upload_audio_screen.dart';
import 'package:audio_player/services/audio_service.dart';
import 'package:audio_player/services/auth_service.dart';
import 'package:audio_player/services/download_service.dart';
import 'package:audio_player/services/local_file_scanner.dart';
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
  final LocalFileScanner _localScanner = LocalFileScanner();
  final LocalDatabase _localDb = LocalDatabase.instance;

  int cloudFileCount = 0;
  int localFileCount = 0;

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

      cloudFileCount = 0;
      localFileCount = 0;

      //adding both cloud and local files
      List<Audio> allAudio = [];

      //load cloud files from backend or local
      try {
        final cloudAudio = await _audioService.getLibrary();

        allAudio.addAll(cloudAudio);

        cloudFileCount = cloudAudio.length;

        print("loaded ${cloudAudio.length} cloud files");
      } catch (e) {
        print("failed to load cloud files: $e");
      }

      Map<int, String> localPathMappings = {};

      try {
        localPathMappings = await _localDb.getAllAudioLocalPaths();
      } catch (e) {
        print("failed to load local mappings: $e");
      }
      print("found ${localPathMappings.length} cloud->local mappings");

      try {
        //request permission and scan local files
        final hasPermission = await _localScanner.requestPermission();
        if (hasPermission) {
          final localAudio = await _localScanner.scanLocalFiles();

          // build map of cloud files by title
          final cloudTitleMap = <String, Audio>{};
          for (var audio in allAudio) {
            cloudTitleMap[audio.title.toLowerCase()] = audio;
          }

          //set of local paths that are already mapped
          final mappedPaths = localPathMappings.values.toSet();

          //process each local file
          for (var local in localAudio) {
            final cloudMatch = cloudTitleMap[local.title.toLowerCase()];

            if (cloudMatch != null) {
              //mark as downloaded since local copy exists
              downloadStatus[cloudMatch.id] = true;

              print(
                " '${local.title} -> cloud id ${cloudMatch.id} (marked offline)'",
              );

              //create mapping if it does not exist
              if (!localPathMappings.containsKey(cloudMatch.id)) {
                await _localDb.setAudioLocalPath(cloudMatch.id, local.fileUrl);

                print("created mapping: ${cloudMatch.id} -> ${local.fileUrl}");
              }
            } else if (!mappedPaths.contains(local.fileUrl)) {
              allAudio.add(local);
              localFileCount++;
            }
          }

          print("loaded ${localFileCount} local files");
        }
      } catch (e) {
        print("failed to scan local files: $e");
      }

      //check download status for cloud files
      Map<int, bool> status = {};
      if (allAudio.isNotEmpty) {
        for (var audio in allAudio) {
          //positive id means it is a cloud file
          if (audio.id > 0) {
            if (!downloadStatus.containsKey(audio.id)) {
              final isDownloaded = await _downloadService.isDownloaded(
                audio.id,
              );

              final hasLocalPath = localPathMappings.containsKey(audio.id);

              status[audio.id] = isDownloaded || hasLocalPath;
            } else {
              status[audio.id] = downloadStatus[audio.id]!;
            }
          }
        }
      }

      if (allAudio.isNotEmpty) {
        allAudio.sort((a, b) => a.author.compareTo(b.author));
      }

      setState(() {
        audios = allAudio;

        downloadStatus = status;

        isLoading = false;
      });

      print(
        "total library: ${allAudio.length} files (${cloudFileCount} cloud + ${localFileCount} local)",
      );
    } catch (e) {
      print("error message: $e");
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _downloadAudio(Audio audio) async {
    // download cloud files
    if (audio.id < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("This file is already local")));

      return;
    }

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
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete '${audio.title}' permanently?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            Center(child: CircularProgressIndicator(color: Colors.black87)),
      );

      // handling local only file
      if (audio.id < 0) {
        final file = File(audio.fileUrl);

        if (await file.exists()) {
          await file.delete();
        } else {
          throw Exception("File not found at: ${file.path}");
        }
      }
      //handling cloud files
      else {
        //check for local path mapping (desktop synced file)
        final localPath = await _localDb.getAudioLocalPath(audio.id);

        if (localPath != null) {
          final localFile = File(localPath);
          if (await localFile.exists()) {
            await localFile.delete();
          } else {
            print("local file missing: $localPath");
          }

          await _localDb.deleteAudioLocalPath(audio.id);
        }

        //check if in download folder
        final isDownloaded = await _downloadService.isDownloaded(audio.id);
        if (isDownloaded) {
          await _downloadService.deleteDownload(audio.id);
        }

        //delete from backend postgres and s3
        await _audioService.deleteAudio(audio.id);
      }

      Navigator.pop(context);

      await loadData();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Deleted: ${audio.title}")));
    } catch (e) {
      Navigator.pop(context);

      print("delete error: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to delete: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteAudio(Audio audio) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${audio.title}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            Center(child: CircularProgressIndicator(color: Colors.black87)),
      );

      //local file
      if (audio.id < 0) {
        final file = File(audio.fileUrl);

        if (await file.exists()) {
          await file.delete();
        } else {
          print("file does not exist at: ${file.path}");

          throw Exception("file not dound at: ${file.path}");
        }
      } else {
        //check for local path mapping (desktop synced file)
        final localPath = await _localDb.getAudioLocalPath(audio.id);

        if (localPath != null) {
          final localFile = File(localPath);
          if (await localFile.exists()) {
            await localFile.delete();
          } else {
            print("local file already missing: $localPath");
          }

          await _localDb.deleteAudioLocalPath(audio.id);
        }

        final isDownloaded = await _downloadService.isDownloaded(audio.id);
        if (isDownloaded) {
          await _downloadService.deleteDownload(audio.id);
        }

        await _audioService.deleteAudio(audio.id);
      }

      Navigator.pop(context);

      await loadData();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Deleted: ${audio.title}")));
    } catch (e) {
      Navigator.pop(context);

      print("Delete error: $e");

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Library",
              style: TextStyle(
                color: Colors.black87,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (cloudFileCount > 0 || localFileCount > 0)
              Text(
                "${cloudFileCount} cloud * ${localFileCount} local",
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
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

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => UploadAudioScreen()),
          );

          if (result == true) {
            loadData();
          }
        },
        backgroundColor: Colors.black87,
        child: Icon(Icons.add, color: Colors.white),
      ),

      body: RefreshIndicator(
        onRefresh: loadData,
        child: audios.isEmpty
            ? ListView(
                physics: AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),

                  Center(
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
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Upload files",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.separated(
                physics: AlwaysScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final audio = audios[index];

                  final isCloudFile = audio.id > 0;
                  final isLocalFile = audio.id < 0;

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
                        color: isLocalFile || downloadStatus[audio.id] == true
                            ? Colors.green
                            : Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: isDownloaded || isLocalFile
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
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      color: Colors.green,
                                      size: 12,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Icon(
                              Icons.music_note,
                              color: Colors.white,
                              size: 28,
                            ),
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
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            //source indicator
                            if (isLocalFile) ...[
                              Icon(
                                Icons.desktop_windows,
                                size: 14,
                                color: Colors.green,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Desktop",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                ),
                              ),
                            ] else if (isDownloaded) ...[
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
                            ] else ...[
                              Icon(Icons.cloud, size: 14, color: Colors.blue),
                              SizedBox(width: 4),
                              Text(
                                "Cloud",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
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
                              if (isCloudFile && !isDownloaded)
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
                              if (isCloudFile && isDownloaded)
                                PopupMenuItem(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline,
                                        color: Colors.orange,
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
                              PopupMenuItem(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_forever,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text("Delete Audio"),
                                  ],
                                ),
                                onTap: () {
                                  Future.delayed(
                                    Duration.zero,
                                    () => _deleteAudio(audio),
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
      ),
    );
  }

  Future<void> _playAudio(Audio audio) async {
    try {
      String audioPath;
      bool isLocal;

      if (audio.id < 0) {
        audioPath = audio.fileUrl;
        isLocal = true;

        print("playing local file: $audioPath");
      } else {
        final playbackInfo = await _audioService.getPlaybackPath(audio.id);

        if (playbackInfo["path"] == null) {
          throw Exception("could not get audio path");
        }

        audioPath = playbackInfo["path"] as String;
        isLocal = playbackInfo["isLocal"];
      }

      if (!mounted) return;

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
            isLocal: isLocal,
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
