import 'package:audio_player/models/loop_mode.dart';
import 'package:audio_player/providers/audio_player_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FullPlayerSheet extends ConsumerWidget {
  const FullPlayerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerProvider);
    if (!playerState.hasTrack) {
      return SizedBox.shrink();
    }

    final track = playerState.currentTrack!;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          //drag handle
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          //close button
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          //track counter
          Text(
            "Track ${playerState.currentIndex + 1} of ${playerState.queue.length}",
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),

          SizedBox(height: 40),

          //album art
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: track.isLocal ? Colors.green : Colors.black87,
              shape: BoxShape.circle,
            ),
            child: Icon(
              track.isLocal ? Icons.offline_pin : Icons.music_note,
              size: 100,
              color: Colors.white,
            ),
          ),

          SizedBox(height: 40),

          // track title
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              track.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          SizedBox(height: 8),

          // author
          Text(
            track.author,
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 40),

          // progress slider
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(playerState.position),
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    Text(
                      _formatDuration(playerState.duration),
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
                Slider(
                  activeColor: Colors.black87,
                  inactiveColor: Colors.grey[300],
                  value: playerState.position.inSeconds.toDouble().clamp(
                    0.0,
                    playerState.duration.inSeconds.toDouble() > 0
                        ? playerState.duration.inSeconds.toDouble()
                        : 1.0,
                  ),
                  min: 0.0,
                  max: playerState.duration.inSeconds.toDouble() > 0
                      ? playerState.duration.inSeconds.toDouble()
                      : 1.0,
                  onChanged: (value) {
                    ref
                        .read(audioPlayerProvider.notifier)
                        .seekTo(Duration(seconds: value.toInt()));
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // controls
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                //loop button
                IconButton(
                  icon: _getLoopIcon(playerState.loopMode),
                  iconSize: 28,
                  onPressed: () {
                    ref.read(audioPlayerProvider.notifier).cycleLoopMode();
                  },
                ),

                //previous
                IconButton(
                  icon: Icon(Icons.skip_previous, size: 40),
                  color: Colors.black87,
                  onPressed: () {
                    ref.read(audioPlayerProvider.notifier).playPrevious();
                  },
                ),

                //play pause
                if (playerState.isLoading)
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      color: Colors.black87,
                      strokeWidth: 3,
                    ),
                  )
                else
                  IconButton(
                    icon: Icon(
                      playerState.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                      size: 64,
                    ),
                    color: Colors.black87,
                    onPressed: () {
                      if (playerState.isPlaying) {
                        ref.read(audioPlayerProvider.notifier).pause();
                      } else {
                        ref.read(audioPlayerProvider.notifier).play();
                      }
                    },
                  ),

                //next
                IconButton(
                  icon: Icon(Icons.skip_next, size: 40),
                  color: Colors.black87,
                  onPressed: () {
                    ref.read(audioPlayerProvider.notifier).playNext();
                  },
                ),

                //placeholder for symmetry
                SizedBox(width: 28),
              ],
            ),
          ),

          Spacer(),
        ],
      ),
    );
  }

  Widget _getLoopIcon(LoopMode mode) {
    final color = mode == LoopMode.none ? Colors.grey[400]! : Colors.blue;

    switch (mode) {
      case LoopMode.none:
        return Icon(Icons.repeat, color: color, size: 28);

      case LoopMode.one:
        return Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.repeat, color: color, size: 28),
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
        return Icon(Icons.repeat, color: color, size: 28);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return "$hours:${twoDigits(minutes)}:${twoDigits(seconds)}";
    }

    return "${twoDigits(minutes)}:${twoDigits(seconds)}";
  }
}
