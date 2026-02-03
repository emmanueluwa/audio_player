import 'dart:convert' show json;

import 'package:audio_player/app_colours.dart' as AppColors;
import 'package:audio_player/detail_audio_page.dart';
import 'package:audio_player/models/audio.dart';
import 'package:audio_player/my_tabs.dart';
import 'package:audio_player/screens/playlists_screen.dart';
import 'package:audio_player/services/audio_service.dart';
import 'package:audio_player/services/auth_service.dart';
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

  final AuthService _authService = AuthService();
  final AudioService _audioService = AudioService();

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

      setState(() {
        audios = audioList;

        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
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
                  trailing: Icon(
                    Icons.play_circle_outline,
                    color: Colors.black87,
                    size: 32,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailAudioPage(
                          audioData: audios
                              .map((a) => a.toDisplayJson())
                              .toList(),
                          index: index,
                        ),
                      ),
                    );
                  },
                );
              },
              separatorBuilder: (context, index) =>
                  Divider(height: 1, indent: 72),
              itemCount: audios.length,
            ),
    );
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
