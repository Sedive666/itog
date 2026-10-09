import 'package:dio/dio.dart';

import 'config.dart';
import 'errors.dart';

/// Источник токена. Реализует `AuthNotifier`; сетевой слой не знает о самой сессии.
abstract interface class SessionTokens {
  String? get accessToken;

  /// Обновляет токен. Возвращает false, если сессия потеряна.
  Future<bool> refreshSession();
}

/// Клиент PocketBase: добавляет токен, при 401 один раз обновляет сессию и повторяет запрос.
/// Любой ответ не в диапазоне 2xx — ошибка Dio: её переводит `mapDioException`.
Dio buildApiDio(SessionTokens tokens, {HttpClientAdapter? adapter}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: '$pbUrl/api',
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      contentType: Headers.jsonContentType,
    ),
  );
  if (adapter != null) dio.httpClientAdapter = adapter;

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokens.accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = token;
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final options = error.requestOptions;
        final isAuthCall = options.path.contains('/auth-');
        final expired = error.response?.statusCode == 401;
        if (expired && !isAuthCall && options.extra['retried'] != true) {
          final refreshed = await tokens.refreshSession();
          if (refreshed) {
            options.extra['retried'] = true;
            options.headers['Authorization'] = tokens.accessToken;
            try {
              return handler.resolve(await dio.fetch<dynamic>(options));
            } on DioException catch (e) {
              return handler.next(e);
            }
          }
        }
        handler.next(error);
      },
    ),
  );
  return dio;
}

/// Переводит ошибку Dio в исключение приложения.
AppException mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionError:
      return const NetworkException();
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const TimeoutException();
    default:
      break;
  }
  final response = e.response;
  if (response == null) return const ServerException();
  return mapHttpResponse(response.statusCode ?? 0, response.data);
}

/// Разбор ответа PocketBase по статусу. Ошибки полей приходят в `data`.
AppException mapHttpResponse(int status, dynamic body) {
  final map = body is Map ? body : const <String, dynamic>{};
  final message = map['message'] is String ? map['message'] as String : null;
  final data = map['data'] is Map ? map['data'] as Map : const {};

  switch (status) {
    case 400:
      if (data.isEmpty) {
        // PocketBase отвечает 400 без полей, когда правило доступа запрещает запись.
        return ForbiddenException(
          message == null || message.startsWith('Something')
              ? 'Недостаточно прав для этого действия.'
              : message,
        );
      }
      return ValidationException(
        message ?? 'Проверьте заполнение полей.',
        _fieldErrors(data),
      );
    case 401:
      return UnauthorizedException(message ?? 'Сессия истекла. Войдите снова.');
    case 403:
      return ForbiddenException(
        message ?? 'Недостаточно прав для этого действия.',
      );
    case 404:
      return NotFoundException(message ?? 'Запись не найдена.');
    case 409:
      return ConflictException(
        message ?? 'Операция невозможна: данные используются.',
      );
    case 422:
      return ValidationException(
        message ?? 'Ошибка валидации.',
        _fieldErrors(data),
      );
    default:
      return ServerException(message ?? 'Ошибка на сервере. Попробуйте позже.');
  }
}

Map<String, String> _fieldErrors(Map data) {
  final result = <String, String>{};
  data.forEach((key, value) {
    if (value is Map && value['message'] is String) {
      result['$key'] = value['message'] as String;
    }
  });
  return result;
}
