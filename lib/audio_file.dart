import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioFile extends StatefulWidget {
  final AudioPlayer advancedPlayer;

  const AudioFile({super.key, required this.advancedPlayer});

  @override
  State<AudioFile> createState() => _AudioFileState();
}

class _AudioFileState extends State<AudioFile> {
  Duration _duration = new Duration();
  Duration _position = new Duration();

  final String path =
      "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3";

  bool isPlaying = false;
  bool isPaused = false;
  bool isLoop = false;

  List<IconData> _icons = [Icons.play_circle_fill, Icons.pause_circle_filled];

  @override
  void initState() {
    super.initState();

    this.widget.advancedPlayer.onDurationChanged.listen((d) {
      setState(() {
        _duration = d;
      });
    });

    this.widget.advancedPlayer.onPositionChanged.listen((p) {
      setState(() {
        _position = p;
      });
    });

    this.widget.advancedPlayer.setSourceUrl(path);
  }

  Widget btnStart() {
    // isPlaying = bool;

    return IconButton(
      padding: const EdgeInsets.only(bottom: 10),
      icon: isPlaying ? Icon(_icons[1], size: 50) : Icon(_icons[0], size: 50),

      onPressed: () {
        if (!isPlaying) {
          this.widget.advancedPlayer.play(UrlSource(path));

          setState(() {
            isPlaying = true;
          });
        } else if (isPlaying) {
          this.widget.advancedPlayer.pause();

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
        children: [btnSlower(), btnStart(), btnFaster()],
      ),
    );
  }

  Widget btnFaster() {
    return IconButton(
      onPressed: () {},
      icon: ImageIcon(
        AssetImage("images/forward.png"),
        size: 15,
        color: Colors.black,
      ),
    );
  }

  Widget btnSlower() {
    return IconButton(
      onPressed: () {},
      icon: ImageIcon(
        AssetImage("images/backword.png"),
        size: 15,
        color: Colors.black,
      ),
    );
  }

  Widget slider() {
    return Slider(
      activeColor: Colors.black,
      inactiveColor: Colors.black12,
      value: _position.inSeconds.toDouble(),
      min: 0.0,
      max: _duration.inSeconds.toDouble(),

      onChanged: (double value) {
        setState(() {
          changeToSecond(value.toInt());

          value = value;
        });
      },
    );
  }

  void changeToSecond(int second) {
    Duration newDuration = Duration(seconds: second);

    this.widget.advancedPlayer.seek(newDuration);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20),
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
          loadAsset(),
        ],
      ),
    );
  }
}
