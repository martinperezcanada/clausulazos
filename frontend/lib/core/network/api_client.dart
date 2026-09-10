import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../storage/token_storage.dart';

/// Thrown when the backend responds 401: the caller (typically
/// AuthProvider) should clear the session and route back to Login.
class UnauthorizedException implements Exception {}

/// Wraps a configured [Dio] instance. Every repository goes through this
/// client instead of building its own Dio — this is the single place
/// that knows about the base URL, timeouts, auth header, and 401 handling.
class ApiClient {
  ApiClient({required TokenStorage tokenStorage, void Function()? onUnauthorized})
      : _tokenStorage = tokenStorage,
        _onUnauthorized = onUnauthorized {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        contentType: 'application/json',
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.readToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await _tokenStorage.clearToken();
            _onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final TokenStorage _tokenStorage;
  final void Function()? _onUnauthorized;
  late final Dio _dio;

  Dio get dio => _dio;

  /// Extracts a readable error message from a DioException's response
  /// body (NestJS validation/errors typically look like { message: ... }).
  static String messageFromError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        final message = data['message'];
        if (message is List) return message.join(', ');
        return message.toString();
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'No se ha podido conectar con el servidor.';
      }
    }
    return 'Ha ocurrido un error inesperado.';
  }
}
