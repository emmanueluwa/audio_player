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
  final LoopMode initialLoopMode;
  final bool autoPlay;

  const AudioFile({
    super.key,
    required this.advancedPlayer,
    required this.audioPath,
    this.isLocal = false,
    this.onNext,
    this.onPrevious,
    this.onTrackComplete,
    this.initialLoopMode = LoopMode.none,
    this.autoPlay = false,
  });

  @override
  State<AudioFile> createState() => _AudioFileState();
}

class _AudioFileState extends State<AudioFile> {
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  bool isPlaying = false;
  bool isLoading = true;
  bool hasAutoPlayed = false;

  LoopMode loopMode = LoopMode.none;

  List<IconData> _icons = [Icons.play_circle_fill, Icons.pause_circle_filled];

  @override
  void initState() {
    super.initState();

    loopMode = widget.initialLoopMode;

    if (loopMode == LoopMode.one) {
      widget.advancedPlayer.setReleaseMode(ReleaseMode.loop);
    } else {
      widget.advancedPlayer.setReleaseMode(ReleaseMode.release);
    }

    widget.advancedPlayer.onDurationChanged.listen((d) {
      if (!mounted) return;

      setState(() {
        _duration = d;
        isLoading = false;
      });

      if (widget.autoPlay && !hasAutoPlayed && d.inMilliseconds > 0) {
        hasAutoPlayed = true;

        _playAudio().then((_) {
          if (!mounted) return;

          setState(() {
            isPlaying = true;
          });
        });
      }
    });

    widget.advancedPlayer.onPositionChanged.listen((p) {
      if (!mounted) return;

      setState(() {
        _position = p;
      });
    });

    widget.advancedPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;

      setState(() {
        isPlaying = (state == PlayerState.playing);
      });

      //handling completion
      if (state == PlayerState.completed) {
        setState(() {
          _position = Duration.zero;
        });

        //notify parent, loop one is handled by player
        if (loopMode != LoopMode.one) {
          widget.onTrackComplete?.call(loopMode);
        }
      }
    });

    _loadAudio();
  }

  @override
  void didUpdateWidget(AudioFile oldWidget) {
    super.didUpdateWidget(oldWidget);

    //if audio path changed then reload
    if (oldWidget.audioPath != widget.audioPath) {
      print("audio path changed so reloading");

      hasAutoPlayed = false;

      setState(() {
        isLoading = true;

        _position = Duration.zero;
        _duration = Duration.zero;
      });

      _loadAudio();
    }
  }

  Future<void> _loadAudio() async {
    try {
      if (widget.isLocal) {
        await widget.advancedPlayer.setSourceDeviceFile(widget.audioPath);
      } else {
        await widget.advancedPlayer.setSourceUrl(widget.audioPath);
      }

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print("error loading audio: $e");

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _playAudio() async {
    try {
      if (widget.isLocal) {
        await widget.advancedPlayer.play(DeviceFileSource(widget.audioPath));
      } else {
        await widget.advancedPlayer.play(UrlSource(widget.audioPath));
      }
    } catch (e) {
      print("error playing audio: $e");
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
    //never exceed duration
    final clampedPosition = _position.inSeconds.toDouble().clamp(
      0.0,
      _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
    );

    return Slider(
      activeColor: Colors.black,
      inactiveColor: Colors.black12,
      value: clampedPosition,
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
