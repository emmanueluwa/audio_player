import 'dart:ffi';

import 'package:audio_player/models/loop_mode.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioFile extends StatefulWidget {
  final AudioPlayer advancedPlayer;
  final String audioPath;
  final bool isLocal;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final Function(LoopMode)? onTrackComplete;

  const AudioFile({
    super.key,
    required this.advancedPlayer,
    required this.audioPath,
    this.isLocal = false,
    this.onNext,
    this.onPrevious,
    this.onTrackComplete,
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

  LoopMode loopMode = LoopMode.none;

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
        isPlaying = true;
      });

      //notifying parent about track completion
      widget.onTrackComplete?.call(loopMode);
    });
  }

  Future<void> _loadAudio() async {
    try {
      if (widget.isLocal) {
        print("loading local file: ${widget.audioPath}");

        await widget.advancedPlayer.setSourceDeviceFile(widget.audioPath);
      } else {
        print("loading remote url: ${widget.audioPath}");

        await widget.advancedPlayer.setSourceUrl(widget.audioPath);
      }

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

  Future<void> _playAudio() async {
    if (widget.isLocal) {
      await widget.advancedPlayer.play(DeviceFileSource(widget.audioPath));
    } else {
      await widget.advancedPlayer.play(UrlSource(widget.audioPath));
    }
  }

  void _cycleLoopMode() {
    setState(() {
      switch (loopMode) {
        case LoopMode.none:
          loopMode = LoopMode.one;
          widget.advancedPlayer.setReleaseMode(ReleaseMode.loop);
          break;

        case LoopMode.one:
          loopMode = LoopMode.all;
          widget.advancedPlayer.setReleaseMode(ReleaseMode.release);
          break;

        case LoopMode.all:
          loopMode = LoopMode.none;
          widget.advancedPlayer.setReleaseMode(ReleaseMode.release);
          break;
      }
    });
  }

  Color _getLoopColor() {
    return loopMode == LoopMode.none ? Colors.black26 : Colors.blue;
  }

  Widget _getLoopIcon() {
    switch (loopMode) {
      case LoopMode.none:
        return Icon(Icons.repeat, color: _getLoopColor(), size: 28);

      case LoopMode.one:
        return Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.repeat, color: _getLoopColor(), size: 28),
            Positioned(
              bottom: 0,
              child: Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),

                child: Text(
                  "1",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );

      case LoopMode.all:
        return Icon(Icons.repeat, color: _getLoopColor(), size: 28);
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
          await _playAudio();

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

  Widget btnRepeat() {
    return IconButton(onPressed: _cycleLoopMode, icon: _getLoopIcon());
  }

  Widget btnPrevious() {
    return IconButton(
      onPressed: widget.onPrevious,
      icon: Icon(Icons.skip_previous, color: Colors.black87, size: 32),
    );
  }

  Widget btnNext() {
    return IconButton(
      onPressed: widget.onNext,
      icon: Icon(Icons.skip_next, color: Colors.black87, size: 32),
    );
  }

  Widget loadAsset() {
    return Container(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [btnRepeat(), btnPrevious(), btnStart(), btnNext()],
      ),
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return "$hours:${twoDigits(minutes)}:${twoDigits(seconds)}";
    }

    return "${twoDigits(minutes)}:${twoDigits(seconds)}";
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
                  _formatDuration(_position),
                  style: TextStyle(fontSize: 16),
                ),

                Text(
                  _formatDuration(_duration),
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
