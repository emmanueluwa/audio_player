import 'package:audio_player/config/api_config.dart';
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

  Future<Options> _getAuthOptions() async {
    final token = await _authService.getToken();

    return Options(headers: {"Autherzation": "Bearer $token"});
  }

  Future<List<Playlist>> getPlaylists() async {
    try {
      final options = await _getAuthOptions();

      final response = await _dio.get("/playlists/", options: options);

      final List<dynamic> playlistsJson = response.data["playlists"];

      return playlistsJson.map((json) => Playlist.fromJson(json)).toList();
    } on DioException catch (e) {
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

      return PlaylistDetail.fromJson(response.data);
    } on DioException catch (e) {
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
        throw Exception("audio already in playist");
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
