import 'package:audio_player/detail_audio_page.dart';
import 'package:audio_player/models/playlist.dart';
import 'package:audio_player/screens/add_to_playlist_screen.dart';
import 'package:audio_player/services/audio_service.dart';
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

  PlaylistDetail? playlistDetail;

  bool isLoading = true;
  String? errorMessage;

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

      setState(() {
        playlistDetail = detail;

        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();

        isLoading = false;
      });
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
                    child: Icon(
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
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      if (audio.duration != null)
                        Row(
                          children: [
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
                        ),
                    ],
                  ),

                  trailing: PopupMenuButton(
                    icon: Icon(Icons.more_vert, color: Colors.black87),
                    itemBuilder: (context) => [
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

                  onTap: () async {
                    try {
                      final streamUrl = await _audioService.getStreamUrl(
                        audio.id,
                      );

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailAudioPage(
                            audioData: [
                              {
                                "id": audio.id,
                                "title": audio.title,
                                "text": audio.author,
                                "audio": streamUrl,
                              },
                            ],
                            index: 0,
                          ),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Failed to load audio: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
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
