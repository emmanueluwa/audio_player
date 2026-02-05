import 'package:audio_player/app_colours.dart' as AppColors;
import 'package:audio_player/audio_file.dart';
import 'package:audio_player/services/audio_service.dart';
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

  String? audioPath;
  bool isLoadingUrl = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    advancedPlayer = AudioPlayer();

    _loadAudioPath();
  }

  Future<void> _loadAudioPath() async {
    setState(() {
      isLoadingUrl = true;
      errorMessage = null;
    });

    try {
      final audio = widget.audioData[widget.index];

      if (widget.isLocal) {
        audioPath = audio["audio"];

        print("local playback: $audioPath");
      } else {
        final audioData = audio["audio"];

        if (audioData is String && audioData.startsWith("http")) {
          audioPath = audioData;
        } else {
          final audioId = audio["id"];

          audioPath = await _audioService.getStreamUrl(audioId);
        }

        print("streaming: $audioPath");
      }

      setState(() {
        isLoadingUrl = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoadingUrl = false;
      });
    }
  }

  @override
  void dispose() {
    advancedPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audio = widget.audioData[widget.index];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios, color: Colors.black87),
        ),
        actions: [
          if (widget.isLocal)
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
                    Text(errorMessage!),
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
                        color: widget.isLocal ? Colors.green : Colors.black87,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isLocal ? Icons.offline_pin : Icons.music_note,
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
                      isLocal: widget.isLocal,
                    ),

                    Spacer(),
                  ],
                ),
              ),
      ),
    );
  }
}
