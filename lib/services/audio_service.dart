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
  Future<List<Audio>> getLibrary({String? category}) async {
    try {
      final options = await _getAuthOptions();

      final response = await _dio.get(
        "/audio/library",
        queryParameters: category != null ? {"category": category} : null,
        options: options,
      );

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

  Future<Audio> uploadAudio({
    required String filePath,
    required String title,
    required String author,
    String category = "QURAN",
  }) async {
    try {
      final options = await _getAuthOptions();

      final formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(filePath),
        "title": title,
        "author": author,
        "category": category,
      });

      final response = await _dio.post(
        "/audio/upload",
        data: formData,
        options: options,
      );

      return Audio.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception("upload failed: ${e.message}");
    }
  }

  Future<void> deleteAudio(int id) async {
    try {
      final options = await _getAuthOptions();

      await _dio.delete("/audio/$id", options: options);
    } on DioException catch (e) {
      throw Exception("upload failed: ${e.message}");
    }
  }
}
