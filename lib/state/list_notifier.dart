import 'package:flutter/foundation.dart';

import '../core/errors.dart';
import '../core/permissions.dart';
import '../data/records_api.dart';
import '../models/collection_spec.dart';
import '../models/list_query.dart';
import '../models/page_result.dart';

/// Состояния списка: ожидание, загрузка, данные (включая пусто), ошибка.
enum ListStatus { idle, loading, success, error }

/// Состояние одного раздела: страница, условия, выбор записей, действия.
class ListNotifier extends ChangeNotifier {
  ListNotifier(this._api, this.section, this.spec);

  final RecordsApi _api;
  final Section section;
  final CollectionSpec spec;

  ListQuery _query = const ListQuery();
  ListStatus _status = ListStatus.idle;
  PageResult? _result;
  AppException? _error;
  String? _actionError;
  final Set<String> _selected = {};
  int _ticket = 0;

  ListQuery get query => _query;
  ListStatus get status => _status;
  PageResult? get result => _result;
  AppException? get error => _error;

  /// Ошибка последнего действия (удаление, восстановление). Показывается снэкбаром.
  String? get actionError => _actionError;
  Set<String> get selected => Set.unmodifiable(_selected);
  bool get hasSelection => _selected.isNotEmpty;

  /// Применяет новые условия. Одинаковые условия не запрашиваются повторно, если всё хорошо.
  Future<void> applyQuery(ListQuery next) async {
    if (next == _query &&
        _status != ListStatus.error &&
        _status != ListStatus.idle) {
      return;
    }
    _query = next;
    await load();
  }

  Future<void> load() async {
    final ticket = ++_ticket;
    _status = ListStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final page = await _api.list(section, spec, _query);
      if (ticket != _ticket) return;
      _result = page;
      _status = ListStatus.success;
      _selected.removeWhere((id) => !page.items.any((r) => r.id == id));
    } on AppException catch (e) {
      if (ticket != _ticket) return;
      _error = e;
      _status = ListStatus.error;
    }
    notifyListeners();
  }

  Future<void> retry() => load();

  void toggleSelection(String id) {
    if (!_selected.remove(id)) _selected.add(id);
    notifyListeners();
  }

  void setSelectionAll(bool value) {
    _selected.clear();
    if (value && _result != null) {
      _selected.addAll(_result!.items.map((r) => r.id));
    }
    notifyListeners();
  }

  void clearSelection() {
    _selected.clear();
    notifyListeners();
  }

  void clearActionError() {
    _actionError = null;
  }

  Future<bool> softDelete(String id) =>
      _run(() => _api.softDelete(section, id));

  Future<bool> restore(String id) => _run(() => _api.restore(section, id));

  Future<bool> hardDelete(String id) =>
      _run(() => _api.hardDelete(section, id));

  /// Мягкое удаление выбранных. Возвращает число удалённых.
  Future<int> deleteSelected() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return 0;
    try {
      final n = await _api.bulkDelete(section, ids);
      _selected.clear();
      await load();
      return n;
    } on AppException catch (e) {
      _actionError = e.message;
      notifyListeners();
      return 0;
    }
  }

  Future<bool> _run(Future<void> Function() action) async {
    try {
      await action();
      await load();
      return true;
    } on AppException catch (e) {
      _actionError = e.message;
      notifyListeners();
      return false;
    }
  }
}
