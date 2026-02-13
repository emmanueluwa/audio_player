import 'dart:io';

import 'package:audio_player/audio_file.dart';
import 'package:audio_player/database/local_db.dart';
import 'package:audio_player/models/audio.dart';
import 'package:audio_player/models/loop_mode.dart';
import 'package:audio_player/services/audio_service.dart';
import 'package:audio_player/services/download_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class DetailAudioPage extends StatefulWidget {
  final List<dynamic> audioData;
  final int index;
  final bool isLocal;

  const DetailAudioPage({
    super.key,
    required this.audioData,
    required this.index,
    this.isLocal = false,
  });

  @override
  State<DetailAudioPage> createState() => _DetailAudioPageState();
}

class _DetailAudioPageState extends State<DetailAudioPage> {
  late AudioPlayer advancedPlayer;
  final AudioService _audioService = AudioService();
  final DownloadService _downloadService = DownloadService();
  final LocalDatabase _localDb = LocalDatabase.instance;

  late int currentIndex;
  LoopMode currentLoopMode = LoopMode.none;

  bool isDownloaded = false;
  bool isDownloading = false;
  double downloadedProgress = 0.0;

  String? audioPath;
  bool isLoadingUrl = true;
  String? errorMessage;
  bool currentTrackIsLocal = false;

  @override
  void initState() {
    super.initState();

    currentIndex = widget.index;
    advancedPlayer = AudioPlayer();

    _loadAudioPath();

    _checkDownloadStatus();
  }

  Future<void> _checkDownloadStatus() async {
    final audioId = widget.audioData[currentIndex]["id"];

    //skip local files
    if (audioId < 0) return;

    final downloaded = await _downloadService.isDownloaded(audioId);
    final hasLocalPath = await _localDb.getAudioLocalPath(audioId);

    setState(() {
      isDownloaded = downloaded || (hasLocalPath != null);
    });
  }

  Future<void> _downloadAudio() async {
    final audioData = widget.audioData[currentIndex];
    final audioId = audioData["id"];

    //do not download local files
    if (audioId < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("This file is already local")));

      return;
    }

    setState(() {
      isDownloading = true;
      downloadedProgress = 0.0;
    });

    try {
      final audio = Audio(
        id: audioId,
        userId: 0,
        title: audioData["title"],
        author: audioData["text"],
        fileUrl: audioData["audio"],
        duration: null,
        fileSize: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _downloadService.downloadAudio(
        audio: audio,
        onProgress: (progress) {
          setState(() {
            downloadedProgress = progress;
          });
        },
      );

      setState(() {
        isDownloaded = true;
        isDownloading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Downloaded: ${audioData["title"]}")),
      );
    } catch (e) {
      setState(() {
        isDownloading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Download failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteDownload() async {
    final audioId = widget.audioData[currentIndex]["id"];

    try {
      await _downloadService.deleteDownload(audioId);

      setState(() {
        isDownloaded = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Deleted download")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to delete: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadAudioPath() async {
    await advancedPlayer.stop();

    setState(() {
      isLoadingUrl = true;
      errorMessage = null;
      audioPath = null;
    });

    try {
      final audio = widget.audioData[currentIndex];
      final audioId = audio["id"];

      if (audioId < 0) {
        audioPath = audio["audio"];
        currentTrackIsLocal = true;

        print("local playback: $audioPath");

        if (audioPath != null) {
          final file = File(audioPath!);

          if (!await file.exists()) {
            throw Exception("file not found at: $audioPath");
          }
        }
      } else {
        // get playback path for cloud file
        final playbackInfo = await _audioService.getPlaybackPath(audioId);
        audioPath = playbackInfo["path"];
        currentTrackIsLocal = playbackInfo["isLocal"];
      }

      if (!mounted) return;

      setState(() {
        isLoadingUrl = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString();
        isLoadingUrl = false;
      });
    }
  }

  void _handleTrackComplete(LoopMode loopMode) {
    print("Track completed. Loop mode: $loopMode");

    currentLoopMode = loopMode;

    switch (loopMode) {
      case LoopMode.none:
        break;

      case LoopMode.one:
        //loop handled by AudioPlayer
        break;

      case LoopMode.all:
        _playNext();
        break;
    }
  }

  void _playNext() {
    if (currentIndex < widget.audioData.length - 1) {
      setState(() {
        currentIndex++;
      });
    } else {
      //last track
      setState(() {
        currentIndex = 0;
      });
    }

    _loadAudioPath();
    _checkDownloadStatus();
  }

  void _playPrevious() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
      });
    } else {
      setState(() {
        currentIndex = widget.audioData.length - 1;
      });
    }

    _loadAudioPath();
    _checkDownloadStatus();
  }

  @override
  void dispose() {
    advancedPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audio = widget.audioData[currentIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios, color: Colors.black87),
        ),
        title: Text(
          "Track ${currentIndex + 1} of ${widget.audioData.length}",
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        actions: [
          if (currentTrackIsLocal)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Chip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.offline_pin, size: 16, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      "Offline",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: isLoadingUrl
            ? Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text("Failed to load audio"),
                    SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadAudioPath,
                      child: Text("Retry"),
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 40),
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: currentTrackIsLocal
                            ? Colors.green
                            : Colors.black87,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        currentTrackIsLocal
                            ? Icons.offline_pin
                            : Icons.music_note,
                        size: 100,
                        color: Colors.white,
                      ),
                    ),

                    SizedBox(height: 40),

                    Text(
                      audio["title"] ?? "Unknown Title",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: 8),

                    Text(
                      audio["text"] ?? "Unknown Author",
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 40),

                    AudioFile(
                      advancedPlayer: advancedPlayer,
                      audioPath: audioPath!,
                      isLocal: currentTrackIsLocal,
                      onNext: _playNext,
                      onPrevious: _playPrevious,
                      onTrackComplete: _handleTrackComplete,
                      initialLoopMode: currentLoopMode,
                      autoPlay: true,
                    ),

                    SizedBox(height: 24),

                    //download button for cloud files
                    if (audio["id"] > 0)
                      isDownloading
                          ? Column(
                              children: [
                                SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: CircularProgressIndicator(
                                    value: downloadedProgress,
                                    strokeWidth: 4,
                                    color: Colors.blue,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Downloading ${(downloadedProgress * 100).toInt()}%",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            )
                          : ElevatedButton.icon(
                              onPressed: isDownloaded
                                  ? _deleteDownload
                                  : _downloadAudio,
                              icon: Icon(
                                isDownloaded
                                    ? Icons.delete_outline
                                    : Icons.download,
                                size: 20,
                              ),
                              label: Text(
                                isDownloaded
                                    ? "Delete Download"
                                    : "Download for Offline",
                                style: TextStyle(fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDownloaded
                                    ? Colors.orange
                                    : Colors.blue,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),

                    Spacer(),
                  ],
                ),
              ),
      ),
    );
  }
}
