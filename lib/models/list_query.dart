/// Условия списка: поиск, фильтры, сортировка, страница, размер страницы.
/// Хранятся в адресной строке, поэтому ссылку можно передать другому пользователю.
class ListQuery {
  const ListQuery({
    this.search = '',
    this.sort = '',
    this.descending = false,
    this.page = 1,
    this.perPage = 10,
    this.includeDeleted = false,
    this.filters = const {},
  });

  static const perPageOptions = [10, 25, 50];

  final String search;

  /// Поле сортировки из белого списка раздела; пусто — сортировка по умолчанию.
  final String sort;
  final bool descending;
  final int page;
  final int perPage;
  final bool includeDeleted;

  /// Значения фильтров по ключам раздела (например `brand`, `minPrice`).
  final Map<String, String> filters;

  ListQuery copyWith({
    String? search,
    String? sort,
    bool? descending,
    int? page,
    int? perPage,
    bool? includeDeleted,
    Map<String, String>? filters,
  }) {
    return ListQuery(
      search: search ?? this.search,
      sort: sort ?? this.sort,
      descending: descending ?? this.descending,
      // Любое изменение условий возвращает на первую страницу.
      page: page ?? 1,
      perPage: perPage ?? this.perPage,
      includeDeleted: includeDeleted ?? this.includeDeleted,
      filters: filters ?? this.filters,
    );
  }

  /// Параметры адресной строки. Значения по умолчанию не пишутся, чтобы ссылка оставалась короткой.
  Map<String, String> toUrlParams() {
    final params = <String, String>{};
    if (search.isNotEmpty) params['q'] = search;
    if (sort.isNotEmpty) params['sort'] = sort;
    if (descending) params['dir'] = 'desc';
    if (page > 1) params['page'] = '$page';
    if (perPage != 10) params['size'] = '$perPage';
    if (includeDeleted) params['deleted'] = '1';
    for (final e in filters.entries) {
      if (e.value.isNotEmpty) params[e.key] = e.value;
    }
    return params;
  }

  /// Разбор адресной строки. Неверные значения заменяются значениями по умолчанию.
  factory ListQuery.fromUrlParams(
    Map<String, String> params, {
    Set<String> filterKeys = const {},
  }) {
    final size = int.tryParse(params['size'] ?? '') ?? 10;
    final page = int.tryParse(params['page'] ?? '') ?? 1;
    final filters = <String, String>{
      for (final k in filterKeys)
        if ((params[k] ?? '').isNotEmpty) k: params[k]!,
    };
    return ListQuery(
      search: (params['q'] ?? '').trim(),
      sort: params['sort'] ?? '',
      descending: params['dir'] == 'desc',
      page: page < 1 ? 1 : page,
      perPage: perPageOptions.contains(size) ? size : 10,
      includeDeleted: params['deleted'] == '1',
      filters: filters,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ListQuery && _sameParams(toUrlParams(), other.toUrlParams());

  @override
  int get hashCode => toUrlParams().entries
      .map((e) => '${e.key}=${e.value}')
      .join('&')
      .hashCode;

  static bool _sameParams(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}
