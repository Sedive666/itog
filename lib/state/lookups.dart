import 'package:flutter/foundation.dart';

import '../core/errors.dart';
import '../core/permissions.dart';
import '../data/catalog.dart';
import '../data/records_api.dart';
import '../models/record.dart';

/// Справочники для подписей связей и списков выбора. Загружаются один раз на сессию.
/// Раздел, недоступный роли, даёт пустой справочник, а не ошибку на весь экран.
class Lookups extends ChangeNotifier {
  Lookups(this._api);

  final RecordsApi _api;
  final Map<Section, List<PbRecord>> _items = {};
  String? _userId;

  List<PbRecord> options(Section section) => _items[section] ?? const [];

  /// Справочники зависят от роли (что видно), поэтому при смене пользователя кэш сбрасывается.
  void bindUser(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    _items.clear();
  }

  /// Подпись записи по идентификатору; для неизвестного — прочерк.
  String label(Section section, String id) {
    if (id.isEmpty) return '—';
    for (final r in options(section)) {
      if (r.id == id) return labelOf(section, r);
    }
    return '—';
  }

  Future<void> load(Iterable<Section> sections) async {
    // Уже загруженное и пустой набор не требуют уведомления: иначе он пришёл бы во время сборки экрана.
    final missing = sections.where((s) => !_items.containsKey(s)).toList();
    if (missing.isEmpty) return;
    for (final s in missing) {
      try {
        _items[s] = await _api.all(s);
      } on AppException {
        _items[s] = const [];
      }
    }
    notifyListeners();
  }

  /// Сбрасывает кэш, например после создания новой записи для списка выбора.
  void invalidate(Section section) {
    _items.remove(section);
  }
}
