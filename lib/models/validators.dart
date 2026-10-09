/// Проверка поля формы: возвращает текст ошибки или null.
typedef Validator = String? Function(String? value);

bool _empty(String? v) => v == null || v.trim().isEmpty;

Validator requiredField([String message = 'Заполните поле']) =>
    (v) => _empty(v) ? message : null;

Validator maxLength(int max) =>
    (v) => (v ?? '').trim().length > max ? 'Не длиннее $max символов' : null;

Validator minLength(int min) =>
    (v) =>
        !_empty(v) && v!.trim().length < min ? 'Не короче $min символов' : null;

Validator pattern(RegExp re, String message) =>
    (v) => !_empty(v) && !re.hasMatch(v!.trim()) ? message : null;

/// Целое число в диапазоне. Пустое значение проверяет `required`.
Validator intRange(int min, int max) => (v) {
  if (_empty(v)) return null;
  final n = int.tryParse(v!.trim());
  if (n == null) return 'Введите целое число';
  if (n < min || n > max) return 'От $min до $max';
  return null;
};

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
Validator email() => pattern(_email, 'Введите адрес электронной почты');

final _phone = RegExp(r'^\+?[0-9 ()-]{10,20}$');
Validator phone() =>
    pattern(_phone, 'Телефон: от 10 до 20 цифр, можно +, пробелы и скобки');

/// Дата в формате ГГГГ-ММ-ДД, проверяется и сам день.
final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');
Validator isoDate() => (v) {
  if (_empty(v)) return null;
  if (!_date.hasMatch(v!.trim())) return 'Дата в формате ГГГГ-ММ-ДД';
  return DateTime.tryParse(v.trim()) == null
      ? 'Такой даты не существует'
      : null;
};

/// Вторая дата не раньше первой (сравнение строк ГГГГ-ММ-ДД работает корректно).
String? notBefore(
  String? from,
  String? to, {
  String message = 'Не раньше даты начала',
}) {
  if (_empty(from) || _empty(to)) return null;
  return to!.trim().compareTo(from!.trim()) < 0 ? message : null;
}

/// Значение для фильтра PocketBase в двойных кавычках.
/// Кавычки и обратные слэши из пользовательского ввода удаляются, поэтому условие нельзя «сломать».
String pbString(String value) => '"${value.replaceAll(RegExp(r'["\\]'), '')}"';

/// Цепочка проверок: первая найденная ошибка.
Validator combine(List<Validator> rules) => (v) {
  for (final rule in rules) {
    final err = rule(v);
    if (err != null) return err;
  }
  return null;
};
