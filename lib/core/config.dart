/// Адрес PocketBase. Задаётся при сборке: --dart-define=PB_URL=http://127.0.0.1:8090
const String pbUrl = String.fromEnvironment(
  'PB_URL',
  defaultValue: 'http://127.0.0.1:8090',
);

/// Время ожидания ответа. Сервер локальный, поэтому короткие таймауты.
const Duration connectTimeout = Duration(seconds: 5);
const Duration receiveTimeout = Duration(seconds: 10);

/// Сессия живёт не дольше этого срока с момента входа (как в ПР5–ПР6).
const Duration sessionMaxDuration = Duration(minutes: 30);
