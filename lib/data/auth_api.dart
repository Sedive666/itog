import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/record.dart';

/// Результат входа или обновления: токен и запись пользователя.
class AuthResult {
  const AuthResult(this.token, this.user);
  final String token;
  final PbRecord user;
}

/// Вход, регистрация и обновление токена через коллекцию users.
class AuthApi {
  /// Клиент передаётся функцией: сам клиент зависит от сессии, которая создаёт этот API.
  AuthApi(this._dioOf);

  final Dio Function() _dioOf;
  Dio get _dio => _dioOf();
  static const _users = '/collections/users';

  Future<AuthResult> login(String identity, String password) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_users/auth-with-password',
        data: {'identity': identity, 'password': password},
      );
      return _parse(res.data);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Регистрация покупателя. Роль и карточку клиента назначает сервер.
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      await _dio.post<dynamic>(
        '$_users/records',
        data: {
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'phone': phone,
          'password': password,
          'passwordConfirm': password,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Обновляет токен по действующему. Вызывается при 401 и при восстановлении сессии.
  Future<AuthResult> refresh() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('$_users/auth-refresh');
      return _parse(res.data);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  AuthResult _parse(Map<String, dynamic>? data) {
    final token = data?['token'] as String? ?? '';
    final record = data?['record'];
    if (token.isEmpty || record is! Map<String, dynamic>) {
      throw const FormatException('Неверный ответ сервера при входе');
    }
    return AuthResult(token, PbRecord.fromJson(record));
  }
}
