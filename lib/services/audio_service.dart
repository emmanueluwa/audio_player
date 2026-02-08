import 'dart:io';

import 'package:audio_player/config/api_config.dart';
import 'package:audio_player/models/audio.dart';
import 'package:audio_player/services/auth_service.dart';
import 'package:dio/dio.dart';

class AudioService {
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

    return Options(headers: {"Authorization": "Bearer $token"});
  }

  //get users library
  Future<List<Audio>> getLibrary() async {
    try {
      final options = await _getAuthOptions();

      final response = await _dio.get("/audio/library", options: options);

      final List<dynamic> audiosJson = response.data["audios"];

      return audiosJson.map((json) => Audio.fromJson(json)).toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception("session expired. please login again");
      }

      throw Exception("failed to load library: ${e.message}");
    }
  }

  Future<Audio> getAudio(int id) async {
    try {
      final options = await _getAuthOptions();

      final response = await _dio.get("/audio/$id", options: options);

      return Audio.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception("failed to load audio: ${e.message}");
    }
  }

  Future<String> getStreamUrl(int audioId) async {
    try {
      final options = await _getAuthOptions();

      final response = await _dio.get(
        "/audio/$audioId/stream",
        options: options,
      );

      return response.data["stream_url"];
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception("session expired. please login again.");
      }
      throw Exception("failed to get stream url: ${e.message}");
    }
  }

  Future<String> getDownloadUrl(int audioId) async {
    try {
      final options = await _getAuthOptions();

      final response = await _dio.get(
        "/audio/$audioId/download",
        options: options,
      );

      return response.data["download_url"];
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception("Session expired. Please login again");
      }
      throw Exception("Failed to get download url: ${e.message}");
    }
  }

  Future<Audio> uploadAudio({
    required File file,
    required String title,
    required String author,
    Function(double)? onProgress,
  }) async {
    try {
      final options = await _getAuthOptions();

      final formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(
          file.path,
          filename: file.path.split("/").last,
        ),
        "title": title,
        "author": author,
      });

      print("uploading ${file.path}");

      final response = await _dio.post(
        "/audio/upload",
        data: formData,
        options: options,
        onSendProgress: (sent, total) {
          if (total > 0) {
            final progress = sent / total;

            print("upload progress: ${(progress * 100).toStringAsFixed}%");

            onProgress?.call(progress);
          }
        },
      );

      print("upload complete");
      return Audio.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception("session expired please login again.");
      }

      if (e.response?.statusCode == 415) {
        throw Exception("invalid file type. only MP3 files are supported.");
      }

      if (e.response?.statusCode == 400) {
        // Return the actual backend error message
        final detail = e.response?.data?['detail'] ?? 'Invalid request';
        print(detail);
        throw Exception('Bad request: $detail');
      }

      throw Exception("upload failed: ${e.message}");
    }
  }

  Future<void> deleteAudio(int id) async {
    try {
      final options = await _getAuthOptions();

      await _dio.delete("/audio/$id", options: options);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception("Audio not found");
      }
      if (e.response?.statusCode == 401) {
        throw Exception("Session expired. Please login again.");
      }

      throw Exception("upload failed: ${e.message}");
    }
  }
}
