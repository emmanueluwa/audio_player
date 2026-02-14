//current track model
import 'package:audio_player/models/loop_mode.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CurrentTrack {
  final int id;
  final String title;
  final String author;
  final String audioPath;
  final bool isLocal;

  CurrentTrack({
    required this.id,
    required this.title,
    required this.author,
    required this.audioPath,
    required this.isLocal,
  });
}

// player state model
class AudioPlayerState {
  final AudioPlayer player;
  final CurrentTrack? currentTrack;
  final List<Map<String, dynamic>> queue;
  final int currentIndex;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final LoopMode loopMode;
  final bool isLoading;

  AudioPlayerState({
    required this.player,
    this.currentTrack,
    this.queue = const [],
    this.currentIndex = 0,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.loopMode = LoopMode.none,
    this.isLoading = false,
  });

  AudioPlayerState copyWith({
    AudioPlayer? player,
    CurrentTrack? currentTrack,
    List<Map<String, dynamic>>? queue,
    int? currentIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    LoopMode? loopMode,
    bool? isLoading,
  }) {
    return AudioPlayerState(
      player: player ?? this.player,
      currentTrack: currentTrack ?? this.currentTrack,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      loopMode: loopMode ?? this.loopMode,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool get hasTrack => currentTrack != null;
}

//state notifier
class AudioPlayerNotifier extends StateNotifier<AudioPlayerState> {
  AudioPlayerNotifier() : super(AudioPlayerState(player: AudioPlayer())) {
    _initializeListeners();
  }

  void _initializeListeners() {
    state.player.onDurationChanged.listen((d) {
      if (!mounted) return;
      state = state.copyWith(duration: d, isLoading: false);
    });

    state.player.onPositionChanged.listen((p) {
      if (!mounted) return;
      state = state.copyWith(position: p);
    });

    state.player.onPlayerStateChanged.listen((playerState) {
      if (!mounted) return;

      final playing = playerState == PlayerState.playing;
      state = state.copyWith(isPlaying: playing);

      //handling track completion
      if (playerState == PlayerState.completed) {
        state = state.copyWith(position: Duration.zero);

        _handleTrackComplete();
      }
    });
  }

  void _handleTrackComplete() {
    switch (state.loopMode) {
      case LoopMode.none:
        break;
      case LoopMode.one:
        break;
      case LoopMode.all:
        playNext();
        break;
    }
  }

  Future<void> loadQueue({
    required List<Map<String, dynamic>> queue,
    required int startIndex,
  }) async {
    state = state.copyWith(
      queue: queue,
      currentIndex: startIndex,
      isLoading: true,
    );

    await _loadTrackAtIndex(startIndex);
  }

  Future<void> _loadTrackAtIndex(int index) async {
    if (index < 0 || index >= state.queue.length) return;

    await state.player.stop();

    final trackData = state.queue[index];

    final track = CurrentTrack(
      id: trackData["id"],
      title: trackData["title"],
      author: trackData["text"],
      audioPath: trackData["audio"],
      isLocal: trackData["isLocal"],
    );

    state = state.copyWith(
      currentTrack: track,
      currentIndex: index,
      isLoading: true,
      position: Duration.zero,
    );

    try {
      //setting audio source
      if (track.isLocal) {
        await state.player.setSourceDeviceFile(track.audioPath);
      } else {
        await state.player.setSourceUrl(track.audioPath);
      }

      //setting release mode based on loop selection
      if (state.loopMode == LoopMode.one) {
        await state.player.setReleaseMode(ReleaseMode.loop);
      } else {
        await state.player.setReleaseMode(ReleaseMode.release);
      }

      await play();
    } catch (e) {
      print("error loading track: $e");
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> play() async {
    if (state.currentTrack == null) return;

    try {
      if (state.currentTrack!.isLocal) {
        await state.player.play(
          DeviceFileSource(state.currentTrack!.audioPath),
        );
      } else {
        await state.player.play(UrlSource(state.currentTrack!.audioPath));
      }

      state = state.copyWith(isPlaying: true);
    } catch (e) {
      print("error playing $e");
    }
  }

  Future<void> pause() async {
    await state.player.pause();

    state = state.copyWith(isPlaying: false);
  }

  Future<void> playNext() async {
    int nextIndex;

    if (state.currentIndex < state.queue.length - 1) {
      nextIndex = state.currentIndex + 1;
    } else {
      nextIndex = 0;
    }

    await _loadTrackAtIndex(nextIndex);
  }

  Future<void> playPrevious() async {
    int prevIndex;

    if (state.currentIndex > 0) {
      prevIndex = state.currentIndex - 1;
    } else {
      prevIndex = state.queue.length - 1;
    }

    await _loadTrackAtIndex(prevIndex);
  }

  void cycleLoopMode() {
    LoopMode nextMode;

    switch (state.loopMode) {
      case LoopMode.none:
        nextMode = LoopMode.one;
        state.player.setReleaseMode(ReleaseMode.loop);
        break;

      case LoopMode.one:
        nextMode = LoopMode.all;
        state.player.setReleaseMode(ReleaseMode.release);
        break;

      case LoopMode.all:
        nextMode = LoopMode.none;
        state.player.setReleaseMode(ReleaseMode.release);
        break;
    }

    state = state.copyWith(loopMode: nextMode);
  }

  Future<void> seekTo(Duration position) async {
    await state.player.seek(position);
  }

  @override
  void dispose() {
    state.player.dispose();
    super.dispose();
  }
}

//provider
final audioPplayerProvider =
    StateNotifierProvider<AudioPlayerNotifier, AudioPlayerState>((ref) {
      return AudioPlayerNotifier();
    });
