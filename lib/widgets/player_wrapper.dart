import 'package:audio_player/providers/audio_player_provider.dart';
import 'package:audio_player/widgets/mini_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayerWrapper extends ConsumerWidget {
  final Widget child;

  const PlayerWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    //calculate miniplayer height
    final miniPlayerHeight = playerState.hasTrack
        ? (80.0 + bottomPadding)
        : 0.0;

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: miniPlayerHeight,
          child: child,
        ),

        //mini player positioned at bottom
        Positioned(left: 0, right: 0, bottom: 0, child: MiniPlayer()),
      ],
    );
  }
}
