/// Запись PocketBase: идентификатор строкой и словарь полей.
/// Типы полей читаются через методы, поэтому пустые и неверные значения не падают.
class PbRecord {
  const PbRecord(this.id, this.data);

  factory PbRecord.fromJson(Map<String, dynamic> json) =>
      PbRecord(json['id'] as String? ?? '', Map<String, dynamic>.from(json));

  final String id;
  final Map<String, dynamic> data;

  String str(String key) {
    final v = data[key];
    return v == null ? '' : '$v';
  }

  int intOf(String key) {
    final v = data[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  /// Значение многозначного relation: список идентификаторов.
  List<String> ids(String key) {
    final v = data[key];
    if (v is List) {
      return v.map((e) => '$e').where((e) => e.isNotEmpty).toList();
    }
    if (v is String && v.isNotEmpty) return [v];
    return const [];
  }

  /// Дата. Пустая строка и неверный формат дают null.
  DateTime? date(String key) {
    final s = str(key);
    if (s.isEmpty) return null;
    return DateTime.tryParse(s.replaceFirst(' ', 'T'));
  }

  /// Мягко удалённая запись: поле deleted заполнено датой.
  bool get isDeleted => str('deleted').isNotEmpty;
}
