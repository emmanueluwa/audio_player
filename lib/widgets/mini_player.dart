import 'package:audio_player/providers/audio_player_provider.dart';
import 'package:audio_player/widgets/full_player_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerProvider);

    //if no track is loaded do not show
    if (!playerState.hasTrack) {
      return SizedBox.shrink();
    }

    final track = playerState.currentTrack!;

    //bottom padding for system nav
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return GestureDetector(
      onTap: () {
        //expand to full player modal
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => FullPlayerSheet(),
        );
      },
      child: Container(
        height: 80 + bottomPadding,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[300]!, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),

        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: 8 + bottomPadding,
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: track.isLocal ? Colors.green : Colors.black87,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  track.isLocal ? Icons.offline_pin : Icons.music_note,
                  color: Colors.white,
                  size: 28,
                ),
              ),

              SizedBox(width: 12),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      track.author,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              SizedBox(width: 12),

              //play and pause buttons
              if (playerState.isLoading)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black87,
                  ),
                )
              else
                IconButton(
                  icon: Icon(
                    playerState.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    size: 40,
                    color: Colors.black87,
                  ),
                  onPressed: () {
                    if (playerState.isPlaying) {
                      ref.read(audioPlayerProvider.notifier).pause();
                    } else {
                      ref.read(audioPlayerProvider.notifier).play();
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
