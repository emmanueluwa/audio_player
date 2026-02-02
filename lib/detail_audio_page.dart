import 'package:audio_player/app_colours.dart' as AppColors;
import 'package:audio_player/audio_file.dart';
import 'package:audio_player/services/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class DetailAudioPage extends StatefulWidget {
  final List<dynamic> audioData;
  final int index;

  const DetailAudioPage({
    super.key,
    required this.audioData,
    required this.index,
  });

  @override
  State<DetailAudioPage> createState() => _DetailAudioPageState();
}

class _DetailAudioPageState extends State<DetailAudioPage> {
  late AudioPlayer advancedPlayer;
  final AudioService _audioService = AudioService();

  String? streamUrl;
  bool isLoadingUrl = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    advancedPlayer = AudioPlayer();

    _loadStreamUrl();
  }

  Future<void> _loadStreamUrl() async {
    setState(() {
      isLoadingUrl = true;
      errorMessage = null;
    });

    try {
      final audio = widget.audioData[widget.index];
      final audioId = audio["id"];

      final url = await _audioService.getStreamUrl(audioId);

      setState(() {
        streamUrl = url;
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
                      onPressed: _loadStreamUrl,
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
                        color: Colors.black87,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.music_note,
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
                      audioPath: streamUrl!,
                    ),

                    Spacer(),
                  ],
                ),
              ),
      ),
    );
  }
}
