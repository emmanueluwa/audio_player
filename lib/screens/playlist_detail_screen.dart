import 'package:audio_player/database/local_db.dart';
import 'package:audio_player/detail_audio_page.dart';
import 'package:audio_player/models/audio.dart';
import 'package:audio_player/models/playlist.dart';
import 'package:audio_player/screens/add_to_playlist_screen.dart';
import 'package:audio_player/services/audio_service.dart';
import 'package:audio_player/services/download_service.dart';
import 'package:audio_player/services/playlist_service.dart';
import 'package:flutter/material.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final int playlistId;
  final String playlistName;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    required this.playlistName,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final PlaylistService _playlistService = PlaylistService();
  final AudioService _audioService = AudioService();
  final DownloadService _downloadService = DownloadService();
  final LocalDatabase _localDb = LocalDatabase.instance;

  PlaylistDetail? playlistDetail;

  bool isLoading = true;
  String? errorMessage;

  Map<int, bool> downloadStatus = {};
  Map<int, bool> offlineAvailable = {};
  Map<int, double> downloadProgress = {};
  Set<int> currrentlyDownloading = {};

  @override
  void initState() {
    super.initState();

    _loadPlaylistDetail();
  }

  Future<void> _loadPlaylistDetail() async {
    setState(() {
      isLoading = true;

      errorMessage = null;
    });

    try {
      final detail = await _playlistService.getPlaylistDetail(
        widget.playlistId,
      );

      Map<int, bool> status = {};
      Map<int, bool> offline = {};

      for (var audio in detail.audioItems) {
        final isDownloaded = await _downloadService.isDownloaded(audio.id);
        status[audio.id] = isDownloaded;

        final hasLocalPath = await _localDb.getAudioLocalPath(audio.id);

        offline[audio.id] = isDownloaded || (hasLocalPath != null);
      }

      setState(() {
        playlistDetail = detail;

        downloadStatus = status;

        offlineAvailable = offline;

        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();

        isLoading = false;
      });
    }
  }

  Future<void> _downloadAudio(AudioInPlaylist audio) async {
    setState(() {
      currrentlyDownloading.add(audio.id);
      downloadProgress[audio.id] = 0.0;
    });

    try {
      final streamUrl = await _audioService.getStreamUrl(audio.id);

      final audioToDownload = Audio(
        id: audio.id,
        userId: 0,
        title: audio.title,
        author: audio.author,
        fileUrl: streamUrl,
        duration: audio.duration,
        fileSize: audio.fileSize,
        createdAt: audio.addedAt,
        updatedAt: audio.addedAt,
      );

      await _downloadService.downloadAudio(
        audio: audioToDownload,
        onProgress: (progress) {
          setState(() {
            downloadProgress[audio.id] = progress;
          });
        },
      );

      setState(() {
        downloadStatus[audio.id] = true;
        currrentlyDownloading.remove(audio.id);
        downloadProgress.remove(audio.id);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Downloaded: ${audio.title}")));
    } catch (e) {
      setState(() {
        currrentlyDownloading.remove(audio.id);
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

  Future<void> _deleteDownload(AudioInPlaylist audio) async {
    try {
      await _downloadService.deleteDownload(audio.id);

      setState(() {
        downloadStatus[audio.id] = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Deleted download: ${audio.title}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to delete: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeFromPlaylist(int audioId) async {
    try {
      await _playlistService.removeAudioFromPlaylist(
        audioId: audioId,
        playlistId: widget.playlistId,
      );

      _loadPlaylistDetail();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Removed from playlist")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to remove: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _playAudio(AudioInPlaylist audio) async {
    try {
      final playbackInfo = await _audioService.getPlaybackPath(audio.id);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetailAudioPage(
            audioData: [
              {
                "id": audio.id,
                "title": audio.title,
                "text": audio.author,
                "audio": playbackInfo["path"],
              },
            ],
            index: 0,
            isLocal: playbackInfo["isLocal"],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains("connection") ||
                    e.toString().contains("network")
                ? "Audio not available offline. Download it first."
                : "Failed to load audio: $e",
          ),
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
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios, color: Colors.black87),
        ),
        title: Text(
          widget.playlistName,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.black87),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddToPlaylistScreen(
                    playlistId: widget.playlistId,
                    playlistName: widget.playlistName,
                  ),
                ),
              );
              if (result == true) {
                _loadPlaylistDetail();
              }
            },
          ),
        ],
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
                  Text("Error loading playlist"),
                  SizedBox(height: 8),
                  Text(errorMessage!),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadPlaylistDetail,
                    child: Text("Retry"),
                  ),
                ],
              ),
            )
          : playlistDetail!.audioItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.music_note_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  SizedBox(height: 16),
                  Text(
                    "No audio in the playlist",
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Tap + to add audio",
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                ],
              ),
            )
          : ListView.separated(
              itemCount: playlistDetail!.audioItems.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final audio = playlistDetail!.audioItems[index];
                final isDownloaded = downloadStatus[audio.id] ?? false;
                final isDownloading = currrentlyDownloading.contains(audio.id);
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
                      Row(
                        children: [
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

                            //download option
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
                                    Icons.remove_circle_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text("Remove from playlist"),
                                ],
                              ),
                              onTap: () {
                                Future.delayed(
                                  Duration.zero,
                                  () => _showRemoveConfirmation(audio),
                                );
                              },
                            ),
                          ],
                        ),

                  onTap: () => _playAudio(audio),
                );
              },
            ),
    );
  }

  void _showRemoveConfirmation(AudioInPlaylist audio) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Remove from Playlist"),
        content: Text("Remove '${audio.title}' from this playlist?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeFromPlaylist(audio.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text("Remove"),
          ),
        ],
      ),
    );
  }
}
