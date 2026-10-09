/// Ошибки приложения. Экраны показывают `message`, а поля формы берут `errors`.
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Сервер недоступен: нет соединения.
class NetworkException extends AppException {
  const NetworkException()
    : super('Сервер недоступен. Запустите PocketBase и обновите страницу.');
}

/// Сервер не ответил за отведённое время.
class TimeoutException extends AppException {
  const TimeoutException()
    : super('Сервер не ответил вовремя. Попробуйте ещё раз.');
}

/// Сессия истекла или токен недействителен.
class UnauthorizedException extends AppException {
  const UnauthorizedException([
    super.message = 'Сессия истекла. Войдите снова.',
  ]);
}

/// Операция запрещена роли.
class ForbiddenException extends AppException {
  const ForbiddenException([
    super.message = 'Недостаточно прав для этого действия.',
  ]);
}

class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Запись не найдена.']);
}

/// Конфликт данных (код 409): запись связана с другими или не хватает остатка.
class ConflictException extends AppException {
  const ConflictException(super.message);
}

/// Ошибки полей (код 422 или 400 с полями). Ключи `errors` — имена полей формы.
class ValidationException extends AppException {
  const ValidationException(super.message, [this.errors = const {}]);
  final Map<String, String> errors;
}

class ServerException extends AppException {
  const ServerException([
    super.message = 'Ошибка на сервере. Попробуйте позже.',
  ]);
}
