import '../core/permissions.dart';
import 'list_query.dart';
import 'record.dart';
import 'validators.dart';

/// Поле формы.
enum FieldKind {
  text,
  multiline,
  number,
  date,
  select,
  relation,
  relationMulti,
}

class FieldSpec {
  const FieldSpec({
    required this.name,
    required this.label,
    required this.kind,
    this.required = false,
    this.validators = const [],
    this.options = const [],
    this.relation,
    this.hint,
  });

  /// Имя поля в PocketBase; оно же ключ ошибки 422.
  final String name;
  final String label;
  final FieldKind kind;
  final bool required;
  final List<Validator> validators;

  /// Значения для списка выбора.
  final List<String> options;

  /// Коллекция для relation: поля выбора берут записи из неё.
  final Section? relation;
  final String? hint;
}

enum FilterKind {
  select,
  relation,
  relationMulti,
  minNumber,
  maxNumber,
  equalsText,
  flag,
}

class FilterSpec {
  const FilterSpec({
    required this.key,
    required this.label,
    required this.kind,
    this.field = '',
    this.options = const [],
    this.relation,
  });

  /// Ключ в адресной строке.
  final String key;
  final String label;
  final FilterKind kind;

  /// Поле PocketBase; для relation сравнивается с идентификатором.
  final String field;
  final List<String> options;
  final Section? relation;
}

class ColumnSpec {
  const ColumnSpec(
    this.label,
    this.value, {
    this.numeric = false,
    this.sortKey,
  });

  final String label;
  final String Function(PbRecord r, String Function(Section, String) label)
  value;
  final bool numeric;

  /// Ключ сортировки из белого списка раздела; пусто — колонка не сортируется.
  final String? sortKey;
}

/// Описание раздела: какие поля, колонки, фильтры и сортировка. Экраны общие, различается только это.
class CollectionSpec {
  const CollectionSpec({
    required this.section,
    required this.title,
    required this.singular,
    required this.searchFields,
    required this.sortFields,
    required this.defaultSort,
    required this.columns,
    this.filters = const [],
    this.formFields = const [],
    this.titleOf,
    this.quotePreview = false,
  });

  final Section section;
  final String title;
  final String singular;

  /// Поля поиска (через ИЛИ) в PocketBase.
  final List<String> searchFields;

  /// Белый список сортировки: ключ из адресной строки → поле PocketBase.
  final Map<String, String> sortFields;

  /// Сортировка по умолчанию в формате PocketBase, например `-created`.
  final String defaultSort;
  final List<ColumnSpec> columns;
  final List<FilterSpec> filters;

  /// Поля формы; пусто — раздел только для чтения.
  final List<FieldSpec> formFields;

  /// Подпись записи (для отчётов и заголовков).
  final String Function(PbRecord r)? titleOf;

  /// Показать расчёт стоимости в форме заказа.
  final bool quotePreview;

  bool get isFormReadOnly => formFields.isEmpty;

  Set<String> get filterKeys => {for (final f in filters) f.key};

  /// Фильтр PocketBase из условий списка. Значения экранируются, сортировка только из белого списка.
  String buildFilter(ListQuery q) {
    final parts = <String>[];
    if (!q.includeDeleted) parts.add('deleted = ""');
    if (q.search.isNotEmpty) {
      // Оператор ~ сам подставляет % по краям, поэтому строка передаётся как есть.
      final term = pbString(q.search);
      parts.add('(${searchFields.map((f) => '$f ~ $term').join(' || ')})');
    }
    for (final f in filters) {
      final v = q.filters[f.key];
      if (v == null || v.isEmpty) continue;
      switch (f.kind) {
        case FilterKind.select:
          parts.add('${f.field} = ${pbString(v)}');
        case FilterKind.relation:
          parts.add('${f.field} = ${pbString(v)}');
        case FilterKind.relationMulti:
          parts.add('${f.field} ?= ${pbString(v)}');
        case FilterKind.equalsText:
          parts.add('${f.field} ~ ${pbString(v)}');
        case FilterKind.minNumber:
          final n = num.tryParse(v);
          if (n != null) parts.add('${f.field} >= $n');
        case FilterKind.maxNumber:
          final n = num.tryParse(v);
          if (n != null) parts.add('${f.field} <= $n');
        case FilterKind.flag:
          if (v == '1') parts.add('${f.field} = true');
      }
    }
    return parts.join(' && ');
  }

  /// Сортировка в формате PocketBase: `-поле` для убывания.
  String buildSort(ListQuery q) {
    final field = sortFields[q.sort];
    if (field == null) return defaultSort;
    return q.descending ? '-$field' : field;
  }
}
