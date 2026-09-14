import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

  /// Turns any error (Dio, socket, or otherwise) into a short, human
  /// message safe to show in the UI. Technical details (status codes,
  /// exception types, stack traces) are only ever printed to the debug
  /// console — never surfaced to the person using the app.
  static String messageFromError(Object error) {
    if (kDebugMode) {
      // ignore: avoid_print
      debugPrint('[ApiClient] $error');
    }

    if (error is DioException) {
      final status = error.response?.statusCode;
      final path = error.requestOptions.path;

      // Prefer the backend's own validation/business message when present
      // — those are already written in plain Spanish for people (e.g.
      // "Las contraseñas no coinciden"), not technical jargon.
      final data = error.response?.data;
      if (data is Map && data['message'] != null && status != null && status < 500) {
        final message = data['message'];
        if (message is List && message.isNotEmpty) return message.join(', ');
        if (message is String && message.isNotEmpty) return message;
      }

      if (status == 401) {
        return 'Tu sesión ha expirado. Inicia sesión de nuevo.';
      }
      if (status == 403) {
        return 'No tienes permiso para hacer esto.';
      }
      if (status == 404) {
        return 'No se ha encontrado lo que buscabas.';
      }
      if (status != null && status >= 500) {
        if (path.contains('fantasy')) {
          return 'La sincronización no está disponible temporalmente.';
        }
        return 'Ha ocurrido un error. Inténtalo de nuevo.';
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return 'No se ha podido conectar con el servidor.';
        default:
          return 'Ha ocurrido un error. Inténtalo de nuevo.';
      }
    }

    return 'Ha ocurrido un error. Inténtalo de nuevo.';
  }
}
