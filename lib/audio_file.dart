import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioFile extends StatefulWidget {
  final AudioPlayer advancedPlayer;
  final String audioPath;

  const AudioFile({
    super.key,
    required this.advancedPlayer,
    required this.audioPath,
  });

  @override
  State<AudioFile> createState() => _AudioFileState();
}

class _AudioFileState extends State<AudioFile> {
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  bool isPlaying = false;
  bool isPaused = false;
  bool isRepeat = false;
  bool isLoading = true;

  Color repeatColor = Colors.black26;

  List<IconData> _icons = [Icons.play_circle_fill, Icons.pause_circle_filled];

  @override
  void initState() {
    super.initState();

    widget.advancedPlayer.onDurationChanged.listen((d) {
      setState(() {
        _duration = d;
        isLoading = false;
      });
    });

    widget.advancedPlayer.onPositionChanged.listen((p) {
      setState(() {
        _position = p;
      });
    });

    //load s3 URL
    _loadAudio();

    widget.advancedPlayer.onPlayerComplete.listen((e) {
      setState(() {
        _position = Duration.zero;

        if (isRepeat) {
          isPlaying = true;

          widget.advancedPlayer.play(UrlSource(widget.audioPath));
        } else {
          isPlaying = false;
          // isRepeat = false;
        }
      });
    });
  }

  Future<void> _loadAudio() async {
    try {
      await widget.advancedPlayer.setSourceUrl(widget.audioPath);

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print("error loading audio: $e");

      setState(() {
        isLoading = false;
      });
    }
  }

  Widget btnStart() {
    if (isLoading) {
      return SizedBox(
        width: 50,
        height: 50,
        child: CircularProgressIndicator(color: Colors.black87),
      );
    }

    return IconButton(
      padding: const EdgeInsets.only(bottom: 10),
      iconSize: 50,
      icon: Icon(isPlaying ? _icons[1] : _icons[0]),

      onPressed: () async {
        if (!isPlaying) {
          await widget.advancedPlayer.play(UrlSource(widget.audioPath));

          setState(() {
            isPlaying = true;
          });
        } else {
          await widget.advancedPlayer.pause();

          setState(() {
            isPlaying = false;
          });
        }
      },
    );
  }

  Widget loadAsset() {
    return Container(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [btnRepeat(), btnStart()],
      ),
    );
  }

  Widget btnRepeat() {
    return IconButton(
      onPressed: () {
        setState(() {
          isRepeat = !isRepeat;

          if (isRepeat) {
            widget.advancedPlayer.setReleaseMode(ReleaseMode.loop);
            repeatColor = Colors.black87;
          } else {
            widget.advancedPlayer.setReleaseMode(ReleaseMode.release);
            repeatColor = Colors.black26;
          }
        });
      },
      icon: Icon(Icons.repeat, color: repeatColor, size: 28),
    );
  }

  Widget slider() {
    return Slider(
      activeColor: Colors.black,
      inactiveColor: Colors.black12,
      value: _position.inSeconds.toDouble(),
      min: 0.0,
      max: _duration.inSeconds.toDouble() > 0
          ? _duration.inSeconds.toDouble()
          : 1.0,

      onChanged: (double value) {
        setState(() {
          changeToSecond(value.toInt());
        });
      },
    );
  }

  void changeToSecond(int second) {
    Duration newDuration = Duration(seconds: second);

    widget.advancedPlayer.seek(newDuration);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [
                Text(
                  _position.toString().split(".")[0],
                  style: TextStyle(fontSize: 16),
                ),

                Text(
                  _duration.toString().split(".")[0],
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),

          slider(),
          SizedBox(height: 8),
          loadAsset(),
        ],
      ),
    );
  }
}
