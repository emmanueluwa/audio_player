import 'package:audio_player/config/api_config.dart';
import 'package:audio_player/database/local_db.dart';
import 'package:audio_player/models/playlist.dart';
import 'package:audio_player/services/auth_service.dart';
import 'package:dio/dio.dart';

class PlaylistService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: Duration(milliseconds: ApiConfig.connectTimeout),
      receiveTimeout: Duration(milliseconds: ApiConfig.receiveTimeout),
    ),
  );

  final AuthService _authService = AuthService();

  final LocalDatabase _localDb = LocalDatabase.instance;

  Future<Options> _getAuthOptions() async {
    final token = await _authService.getToken();

    return Options(headers: {"Authorization": "Bearer $token"});
  }

  Future<List<Playlist>> getPlaylists() async {
    try {
      final options = await _getAuthOptions();

      final response = await _dio.get("/playlists/", options: options);

      final List<dynamic> playlistsJson = response.data["playlists"];

      await _localDb.cachePlaylists(playlistsJson.cast<Map<String, dynamic>>());

      return playlistsJson.map((json) => Playlist.fromJson(json)).toList();
    } on DioException catch (e) {
      //load from cache if offline
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        print("loading cached playlsts");

        final cached = await _localDb.getCachedPlaylists();

        return cached.map((json) => Playlist.fromJson(json)).toList();
      }

      if (e.response?.statusCode == 401) {
        throw Exception("Session expired. Please login again.");
      }
      throw Exception("failed to load playlists: ${e.message}");
    }
  }

  Future<PlaylistDetail> getPlaylistDetail(int playlistId) async {
    try {
      final options = await _getAuthOptions();

      final response = await _dio.get(
        "/playlists/$playlistId",
        options: options,
      );

      final detail = PlaylistDetail.fromJson(response.data);

      await _localDb.cachePlaylistItems(
        playlistId,
        detail.audioItems
            .map(
              (item) => {
                "audio_id": item.id,
                "title": item.title,
                "author": item.author,
                "duration": item.duration,
                "position": item.position,
                "added_at": item.addedAt.toIso8601String(),
              },
            )
            .toList(),
      );

      return detail;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        final cached = await _localDb.getCachedPlaylists();

        final playlist = cached.firstWhere((p) => p['id'] == playlistId);

        final items = await _localDb.getCachedPlaylistItems(playlistId);

        return PlaylistDetail(
          id: playlist["id"],
          userId: 0,
          name: playlist["name"],
          audioItems: items
              .map(
                (item) => AudioInPlaylist(
                  id: item["audio_id"],
                  title: item["title"],
                  author: item["author"],
                  duration: item["duration"],
                  fileSize: null,
                  position: item["position"],
                  addedAt: DateTime.parse(item["added_at"]),
                ),
              )
              .toList(),
          createdAt: DateTime.parse(playlist["created_at"]),
          updatedAt: DateTime.parse(playlist["updated_at"]),
        );
      }

      if (e.response?.statusCode == 404) {
        throw Exception("playlist not found");
      }

      throw Exception("failed to load playlist: ${e.message}");
    }
  }

  Future<Playlist> createPlaylist({required String name}) async {
    try {
      final options = await _getAuthOptions();

      final response = await _dio.post(
        "/playlists/",
        data: {"name": name},
        options: options,
      );

      return Playlist.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception("failed to create playlist: ${e.message}");
    }
  }

  Future<Playlist> updatePlaylist({
    required int playlistId,
    String? name,
  }) async {
    try {
      final options = await _getAuthOptions();

      final response = await _dio.put(
        "/playlists/$playlistId",
        data: {if (name != null) "name": name},
        options: options,
      );

      return Playlist.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception("failed to update playist: ${e.message}");
    }
  }

  Future<void> addAudioToPlaylist({
    required int playlistId,
    required int audioId,
    int? position,
  }) async {
    try {
      final options = await _getAuthOptions();

      await _dio.post(
        "/playlists/$playlistId/items",
        data: {"audio_id": audioId, if (position != null) "position": position},
        options: options,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw Exception("already in playlist");
      }

      throw Exception("failed to add audio: ${e.message}");
    }
  }

  Future<void> removeAudioFromPlaylist({
    required int playlistId,
    required int audioId,
  }) async {
    try {
      final options = await _getAuthOptions();

      await _dio.delete(
        "/playlists/$playlistId/items/$audioId",
        options: options,
      );
    } on DioException catch (e) {
      throw Exception("failed to remove audio: ${e.message}");
    }
  }

  Future<void> deletePlaylist(int playlistId) async {
    try {
      final options = await _getAuthOptions();

      await _dio.delete("/playlists/$playlistId", options: options);
    } on DioException catch (e) {
      throw Exception("failed to delete playist: ${e.message}");
    }
  }
}
