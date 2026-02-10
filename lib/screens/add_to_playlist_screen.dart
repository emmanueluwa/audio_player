import 'dart:io';

import 'package:audio_player/database/local_db.dart';
import 'package:audio_player/models/audio.dart';
import 'package:audio_player/services/audio_service.dart';
import 'package:audio_player/services/local_file_scanner.dart';
import 'package:audio_player/services/playlist_service.dart';
import 'package:flutter/material.dart';

class AddToPlaylistScreen extends StatefulWidget {
  final int playlistId;
  final String playlistName;

  const AddToPlaylistScreen({
    super.key,
    required this.playlistId,
    required this.playlistName,
  });

  @override
  State<AddToPlaylistScreen> createState() => _AddToPlaylistScreenState();
}

class _AddToPlaylistScreenState extends State<AddToPlaylistScreen> {
  final AudioService _audioService = AudioService();
  final PlaylistService _playlistService = PlaylistService();
  final LocalFileScanner _localScanner = LocalFileScanner();
  final LocalDatabase _localDb = LocalDatabase.instance;

  List<Audio> availableAudio = [];

  bool isLoading = true;
  String? errorMessage;

  Set<int> uploadingFiles = {};

  @override
  void initState() {
    super.initState();

    _loadAudio();
  }

  Future<void> _loadAudio() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      List<Audio> allAudio = [];

      //cloud files
      try {
        final cloudAudio = await _audioService.getLibrary();
        allAudio.addAll(cloudAudio);
      } catch (e) {
        print("failed to load cloud files $e");
      }

      //desktop synced files
      final hasPermission = await _localScanner.requestPermission();
      if (hasPermission) {
        final localAudio = await _localScanner.scanLocalFiles();

        //filter out duplicates
        final cloudTitles = allAudio.map((a) => a.title.toLowerCase()).toSet();
        final uniqueLocalFiles = localAudio.where((local) {
          return !cloudTitles.contains(local.title.toLowerCase());
        }).toList();

        allAudio.addAll(uniqueLocalFiles);
      }

      //filter out audio already in playlist
      final playlistDetail = await _playlistService.getPlaylistDetail(
        widget.playlistId,
      );

      final audioIdsInPlaylist = playlistDetail.audioItems
          .map((item) => item.id)
          .toSet();

      setState(() {
        availableAudio = allAudio
            .where((audio) => !audioIdsInPlaylist.contains(audio.id))
            .toList();

        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<int?> _uploadDesktopFileToBackend(Audio localAudio) async {
    setState(() {
      uploadingFiles.add(localAudio.id);
    });

    try {
      print("uploading desktop file to backend: ${localAudio.fileUrl}");

      //read the file from local storage
      final file = File(localAudio.fileUrl);

      if (!await file.exists()) {
        throw Exception("file not found: ${localAudio.fileUrl}");
      }

      //upload to backend
      final uploadedAudio = await _audioService.uploadAudio(
        file: file,
        title: localAudio.title,
        author: localAudio.author,
        onProgress: (pogress) {
          print("upload: ${(pogress * 100).toInt()}%");
        },
      );

      print(
        "upload complete: ${uploadedAudio.title} (ID: ${uploadedAudio.id})",
      );

      //create mapping between cloud id and local path
      await _localDb.setAudioLocalPath(uploadedAudio.id, localAudio.fileUrl);
      print("mapped cloud id ${uploadedAudio.id} -> ${localAudio.fileUrl}");

      return uploadedAudio.id;
    } finally {
      setState(() {
        uploadingFiles.remove(localAudio.id);
      });
    }
  }

  Future<void> _addToPlaylist(Audio audio) async {
    try {
      int audioIdToAdd;

      //handling desktop files
      if (audio.id < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Uploading to cloud first..."),
            duration: Duration(seconds: 2),
          ),
        );

        final cloudAudioId = await _uploadDesktopFileToBackend(audio);

        if (cloudAudioId == null) {
          throw Exception("Upload failed");
        }

        audioIdToAdd = cloudAudioId;
      } else {
        audioIdToAdd = audio.id;
      }

      await _playlistService.addAudioToPlaylist(
        playlistId: widget.playlistId,
        audioId: audioIdToAdd,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Added to ${widget.playlistName}")),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to add: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return "$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
    }

    return "$minutes:${secs.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context, true),
        ),

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Add to Playlist",
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.playlistName,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),

      body: isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.black87))
          : errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text("Error loading audio"),
                  SizedBox(height: 8),
                  Text(errorMessage!),
                  SizedBox(height: 16),
                  ElevatedButton(onPressed: _loadAudio, child: Text("Retry")),
                ],
              ),
            )
          : availableAudio.isEmpty
          ? Center(child: Text("No audio files available"))
          : ListView.separated(
              itemCount: availableAudio.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final audio = availableAudio[index];
                final isLocalFile = audio.id < 0;
                final isAdding = uploadingFiles.contains(audio.id);

                return ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isLocalFile ? Colors.green : Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isAdding
                        ? Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
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
                      if (isLocalFile) ...[
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.desktop_windows,
                              size: 12,
                              color: Colors.green,
                            ),
                            SizedBox(width: 4),
                            Text(
                              isAdding
                                  ? "Uploading..."
                                  : "Desktop file (will upload)",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),

                  trailing: isAdding
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blue,
                          ),
                        )
                      : Icon(Icons.add_circle_outline, color: Colors.blue),
                  onTap: isAdding ? null : () => _addToPlaylist(audio),
                );
              },
            ),
    );
  }
}
