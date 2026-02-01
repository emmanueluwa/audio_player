import 'dart:convert' show json;

import 'package:audio_player/app_colours.dart' as AppColors;
import 'package:audio_player/detail_audio_page.dart';
import 'package:audio_player/models/audio.dart';
import 'package:audio_player/my_tabs.dart';
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
  String selectedCategory = "ALL";

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
      print("Error LOADING LIBRARY: ${e}");
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  List<Audio> get filteredAudios {
    if (selectedCategory == "ALL") return audios;

    return audios.where((a) => a.category == selectedCategory).toList();
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
            icon: Icon(Icons.logout, color: Colors.black87),
            onPressed: () async {
              await _authService.logout();
              Navigator.pushReplacementNamed(context, "/login");
            },
          ),
        ],
      ),

      body: Column(
        children: [
          //category filter
          Container(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryChip("All"),
                SizedBox(width: 8),
                _buildCategoryChip("QURAN"),
                SizedBox(width: 8),
                _buildCategoryChip("LECTURE"),
                SizedBox(width: 8),
                _buildCategoryChip("REMINDER"),
              ],
            ),
          ),

          Divider(height: 1),

          //audio list
          Expanded(
            child: filteredAudios.isEmpty
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
                          "No audio files",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Upload files via web interface",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemBuilder: (context, index) {
                      final audio = filteredAudios[index];

                      return ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _getCategoryColor(audio.category),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getCategoryIcon(audio.category),
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
                    itemCount: filteredAudios.length,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    final isSelected = selectedCategory == category;

    return FilterChip(
      label: Text(
        category,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : Colors.black87,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          selectedCategory = category;
        });
      },
      backgroundColor: Colors.grey[100],
      selectedColor: Colors.black87,
      checkmarkColor: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      showCheckmark: false,
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'QURAN':
        return Colors.green;
      case 'LECTURE':
        return Colors.blue;
      case 'REMINDER':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case "QURAN":
        return Icons.menu_book;
      case "LECTURE":
        return Icons.school;
      case "REMINDER":
        return Icons.notifications;
      default:
        return Icons.music_note;
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
