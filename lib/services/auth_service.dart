import 'package:audio_player/config/api_config.dart';
import 'package:audio_player/models/user.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: Duration(milliseconds: ApiConfig.connectTimeout),
      receiveTimeout: Duration(milliseconds: ApiConfig.receiveTimeout),
    ),
  );

  final FlutterSecureStorage _storage = FlutterSecureStorage();

  //keys for secure storage
  static const String _tokenKey = "jwt_token";
  static const String _emailKey = "user_email";

  //login
  Future<User> login(String email, String password) async {
    try {
      final response = await _dio.post(
        "/auth/login",
        data: {"email": email, "password": password},
      );

      final token = response.data["access_token"];
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _emailKey, value: email);

      return await getCurrentUser();
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response!.data['detail'] ?? "login failed");
      }
      throw Exception("network error. check your connection.");
    }
  }

  Future<User> register(String email, String password) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {'email': email, "password": password},
      );

      final token = response.data["access_token"];
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _emailKey, value: email);

      return User.fromJson(response.data["user"]);
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response!.data["detail"] ?? "registration failed");
      }
      throw Exception("network error. check your connection.");
    }
  }

  Future<User> getCurrentUser() async {
    try {
      final token = await getToken();
      if (token == null) throw Exception("not authrnticated");

      final response = await _dio.get(
        "/auth/me",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      return User.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await logout();
        throw Exception("session expired. please login again.");
      }
      throw Exception("failed to get user info");
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: _tokenKey);

    return token != null;
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _emailKey);
  }
}
