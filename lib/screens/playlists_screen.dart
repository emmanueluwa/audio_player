import 'package:audio_player/models/playlist.dart';
import 'package:audio_player/screens/create_playlist_screen.dart';
import 'package:audio_player/screens/playlist_detail_screen.dart';
import 'package:audio_player/services/playlist_service.dart';
import 'package:flutter/material.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  final PlaylistService _playlistService = PlaylistService();

  List<Playlist> playlists = [];

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final loadedPlaylists = await _playlistService.getPlaylists();

      setState(() {
        playlists = loadedPlaylists;

        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();

        isLoading = false;
      });
    }
  }

  Future<void> _deletePlaylist(int playlistId) async {
    try {
      await _playlistService.deletePlaylist(playlistId);

      _loadPlaylists();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Playlist deleted")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("failed to delete: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
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
          "Playlists",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.black87),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CreatePlaylistScreen()),
              );

              if (result == true) {
                _loadPlaylists();
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
                  Text("Error loading playlists"),
                  SizedBox(height: 8),
                  Text(errorMessage!),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadPlaylists,
                    child: Text("Retry"),
                  ),
                ],
              ),
            )
          : playlists.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.playlist_play, size: 64, color: Colors.grey[300]),
                  SizedBox(height: 16),
                  Text(
                    "No playlists yet",
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Tap + to create your first playlist",
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                ],
              ),
            )
          : ListView.separated(
              itemCount: playlists.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final playlist = playlists[index];

                return ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.purple,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.queue_music,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  title: Text(
                    playlist.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    "${playlist.audioCount} ${playlist.audioCount == 1 ? "track" : "tracks"}",
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  trailing: PopupMenuButton(
                    icon: Icon(Icons.more_vert, color: Colors.black87),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: Text("Delete"),
                        onTap: () {
                          Future.delayed(
                            Duration.zero,
                            () => _showDeleteConfirmation(playlist),
                          );
                        },
                      ),
                    ],
                  ),
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlaylistDetailScreen(
                          playlistId: playlist.id,
                          playlistName: playlist.name,
                        ),
                      ),
                    );

                    if (result == true) {
                      _loadPlaylists();
                    }
                  },
                );
              },
            ),
    );
  }

  void _showDeleteConfirmation(Playlist playlist) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Playlist"),
        content: Text("Are you sure you want to delete '${playlist.name}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePlaylist(playlist.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text("Delete"),
          ),
        ],
      ),
    );
  }
}
