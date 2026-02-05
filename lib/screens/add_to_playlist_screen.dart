import 'package:audio_player/models/audio.dart';
import 'package:audio_player/services/audio_service.dart';
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

  List<Audio> allAudio = [];

  bool isLoading = true;
  String? errorMessage;

  Set<int> addingIds = {};

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
      final audio = await _audioService.getLibrary();

      setState(() {
        allAudio = audio;

        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _addToPlaylist(Audio audio) async {
    setState(() {
      addingIds.add(audio.id);
    });

    try {
      await _playlistService.addAudioToPlaylist(
        playlistId: widget.playlistId,
        audioId: audio.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Added to ${widget.playlistName}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains("already in playlist")
                  ? "Already in playlist"
                  : "Failed to add: $e",
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          addingIds.remove(audio.id);
        });
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
          : allAudio.isEmpty
          ? Center(child: Text("No audio files available"))
          : ListView.separated(
              itemCount: allAudio.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final audio = allAudio[index];
                final isAdding = addingIds.contains(audio.id);

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

                  trailing: isAdding
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black87,
                          ),
                        )
                      : IconButton(
                          onPressed: () => _addToPlaylist(audio),
                          icon: Icon(Icons.add_circle_outline),
                          color: Colors.black87,
                        ),
                );
              },
            ),
    );
  }
}
