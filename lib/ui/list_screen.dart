import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../core/download.dart';
import '../core/errors.dart';
import '../core/permissions.dart';
import '../data/catalog.dart';
import '../data/records_api.dart';
import '../models/collection_spec.dart';
import '../models/list_query.dart';
import '../models/page_result.dart';
import '../models/record.dart';
import '../state/auth_notifier.dart';
import '../state/list_notifier.dart';
import '../state/lookups.dart';
import 'app_scaffold.dart';
import 'status_pages.dart';

/// Общий экран списка для любого раздела: поиск, фильтры, сортировка, страницы, действия.
class ListScreen extends StatefulWidget {
  const ListScreen({super.key, required this.section, required this.params});

  final Section section;

  /// Параметры адресной строки: условия списка хранятся в адресе.
  final Map<String, String> params;

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  late final CollectionSpec _spec = catalog[widget.section]!;
  late final ListNotifier _notifier;
  final _searchCtl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _notifier = ListNotifier(context.read<RecordsApi>(), widget.section, _spec);
    _notifier.addListener(_showActionError);
    _searchCtl.text = widget.params['q'] ?? '';
    _applyFromUrl();
    context.read<Lookups>().load(_relationSections());
  }

  @override
  void didUpdateWidget(covariant ListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      _applyFromUrl();
    } else if (!_sameParams(oldWidget.params, widget.params)) {
      _applyFromUrl();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _notifier.removeListener(_showActionError);
    _notifier.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  bool _sameParams(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  void _applyFromUrl() {
    _notifier.applyQuery(
      ListQuery.fromUrlParams(widget.params, filterKeys: _spec.filterKeys),
    );
  }

  /// Разделы, из которых берутся подписи и списки выбора для фильтров.
  Set<Section> _relationSections() => {
    for (final f in _spec.filters)
      if (f.relation != null) f.relation!,
  };

  void _showActionError() {
    final message = _notifier.actionError;
    if (message == null || !mounted) return;
    _notifier.clearActionError();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Единственный способ менять условия: переход по адресу. Список обновляется сам.
  void _go(ListQuery q) {
    final params = q.toUrlParams();
    context.go(
      Uri(
        path: _spec.section.path,
        queryParameters: params.isEmpty ? null : params,
      ).toString(),
    );
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _go(_notifier.query.copyWith(search: text.trim()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final role = auth.role;
    final section = widget.section;
    final layout = layoutOf(MediaQuery.sizeOf(context).width);
    final lookups = context.watch<Lookups>();

    return ListenableBuilder(
      listenable: _notifier,
      builder: (context, _) {
        final q = _notifier.query;
        final page = _notifier.result;
        final items = page?.items ?? const <PbRecord>[];
        final canCreate =
            can(role, section, Op.create) && !_spec.isFormReadOnly;
        final canBulk = can(role, section, Op.bulkDelete);
        final canExport = can(role, section, Op.export);

        return AppScaffold(
          title: _spec.title,
          actions: [
            if (canExport)
              IconButton(
                tooltip: 'Экспорт CSV',
                icon: const Icon(Icons.file_download_outlined),
                onPressed: () => _exportCsv(context),
              ),
          ],
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Toolbar(
                  searchCtl: _searchCtl,
                  onSearch: _onSearchChanged,
                  onSubmit: (text) => _go(q.copyWith(search: text.trim())),
                  spec: _spec,
                  query: q,
                  lookups: lookups,
                  onGo: _go,
                  showDeletedToggle: can(role, section, Op.viewDeleted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (canCreate)
                      FilledButton.icon(
                        onPressed: () => context.go('${section.path}/new'),
                        icon: const Icon(Icons.add),
                        label: Text('Добавить ${_spec.singular}'),
                      ),
                    const Spacer(),
                    if (canBulk && _notifier.hasSelection)
                      OutlinedButton.icon(
                        onPressed: () => _bulkDelete(context),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(
                          'Удалить выбранные (${_notifier.selected.length})',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StateView(
                    // Индикатор — только пока данных ещё нет; при обновлении старые строки остаются на экране.
                    loading:
                        _notifier.status == ListStatus.loading && page == null,
                    error: _notifier.error,
                    isEmpty:
                        _notifier.status == ListStatus.success && items.isEmpty,
                    onRetry: _notifier.retry,
                    onReset: _hasConditions(q)
                        ? () => _go(ListQuery(perPage: q.perPage))
                        : null,
                    emptyText:
                        'Ничего не найдено. Измените условия или сбросьте фильтры.',
                    child: layout.showsTable
                        ? _Table(
                            spec: _spec,
                            items: items,
                            notifier: _notifier,
                            lookups: lookups,
                            role: role,
                            onSort: (key) => _go(_sortBy(q, key)),
                            onEdit: (id) =>
                                context.go('${section.path}/$id/edit'),
                            onAction: (action, id) =>
                                _rowAction(context, action, id),
                            canBulk: canBulk,
                          )
                        : _Cards(
                            spec: _spec,
                            items: items,
                            notifier: _notifier,
                            lookups: lookups,
                            role: role,
                            columns: layout.cardColumns,
                            onEdit: (id) =>
                                context.go('${section.path}/$id/edit'),
                            onAction: (action, id) =>
                                _rowAction(context, action, id),
                            canBulk: canBulk,
                          ),
                  ),
                ),
                if (page != null && items.isNotEmpty)
                  _Pager(page: page, query: q, onGo: _go),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _hasConditions(ListQuery q) =>
      q.search.isNotEmpty ||
      q.filters.values.any((v) => v.isNotEmpty) ||
      q.includeDeleted ||
      q.sort.isNotEmpty;

  ListQuery _sortBy(ListQuery q, String key) {
    if (q.sort == key) return q.copyWith(sort: key, descending: !q.descending);
    return q.copyWith(sort: key, descending: false);
  }

  /// Список перезагружает сам ListNotifier после действия.
  Future<void> _rowAction(
    BuildContext context,
    String action,
    String id,
  ) async {
    switch (action) {
      case 'delete':
        if (!await _confirm(
          context,
          'Удалить ${_spec.singular}? Её можно будет восстановить.',
        )) {
          return;
        }
        await _notifier.softDelete(id);
      case 'restore':
        await _notifier.restore(id);
      case 'hard':
        if (!await _confirm(
          context,
          'Удалить ${_spec.singular} навсегда? Это действие необратимо.',
        )) {
          return;
        }
        await _notifier.hardDelete(id);
    }
  }

  Future<void> _bulkDelete(BuildContext context) async {
    final n = _notifier.selected.length;
    final messenger = ScaffoldMessenger.of(context);
    if (!await _confirm(
      context,
      'Удалить выбранные записи ($n)? Их можно будет восстановить.',
    )) {
      return;
    }
    final deleted = await _notifier.deleteSelected();
    messenger.showSnackBar(
      SnackBar(content: Text('Удалено записей: $deleted')),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final api = context.read<RecordsApi>();
    final messenger = ScaffoldMessenger.of(context);
    final fields = <String>['id', ..._spec.formFields.map((f) => f.name)];
    try {
      final bytes = await api.exportCsv(widget.section, fields);
      saveBytes(bytes, '${widget.section.collection}.csv', 'text/csv');
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<bool> _confirm(BuildContext context, String text) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchCtl,
    required this.onSearch,
    required this.onSubmit,
    required this.spec,
    required this.query,
    required this.lookups,
    required this.onGo,
    required this.showDeletedToggle,
  });

  final TextEditingController searchCtl;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onSubmit;
  final CollectionSpec spec;
  final ListQuery query;
  final Lookups lookups;
  final ValueChanged<ListQuery> onGo;
  final bool showDeletedToggle;

  @override
  Widget build(BuildContext context) {
    final sortKeys = [
      for (final c in spec.columns)
        if (c.sortKey != null) (label: c.label, key: c.sortKey!),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: searchCtl,
            onChanged: onSearch,
            onSubmitted: onSubmit,
            decoration: InputDecoration(
              hintText: 'Поиск',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: searchCtl.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Очистить поиск',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchCtl.clear();
                        onSubmit('');
                      },
                    ),
            ),
          ),
        ),
        for (final f in spec.filters) _filter(f),
        if (sortKeys.isNotEmpty)
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              key: ValueKey('sort-${query.sort}'),
              initialValue: sortKeys.any((s) => s.key == query.sort)
                  ? query.sort
                  : null,
              decoration: const InputDecoration(
                labelText: 'Сортировка',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                for (final s in sortKeys)
                  DropdownMenuItem(value: s.key, child: Text(s.label)),
              ],
              onChanged: (v) => onGo(
                query.copyWith(sort: v ?? '', descending: query.descending),
              ),
            ),
          ),
        if (sortKeys.isNotEmpty)
          IconButton(
            tooltip: query.descending ? 'По убыванию' : 'По возрастанию',
            icon: Icon(
              query.descending ? Icons.arrow_downward : Icons.arrow_upward,
            ),
            onPressed: () =>
                onGo(query.copyWith(descending: !query.descending)),
          ),
        if (showDeletedToggle)
          FilterChip(
            label: const Text('Показывать удалённые'),
            selected: query.includeDeleted,
            onSelected: (v) => onGo(query.copyWith(includeDeleted: v)),
          ),
      ],
    );
  }

  Widget _filter(FilterSpec f) {
    final current = query.filters[f.key] ?? '';
    switch (f.kind) {
      case FilterKind.select:
        return _dropdown(f, [
          for (final o in f.options) (value: o, label: o),
        ], current);
      case FilterKind.relation:
      case FilterKind.relationMulti:
        final opts = [
          for (final r in lookups.options(f.relation!))
            (value: r.id, label: labelOf(f.relation!, r)),
        ];
        return _dropdown(f, opts, current);
      case FilterKind.minNumber:
      case FilterKind.maxNumber:
      case FilterKind.equalsText:
      case FilterKind.flag:
        return _TextFilter(
          key: ValueKey('${spec.section.name}-${f.key}-$current'),
          label: f.label,
          initial: current,
          numeric:
              f.kind == FilterKind.minNumber || f.kind == FilterKind.maxNumber,
          onSubmit: (v) => onGo(_with(f.key, v)),
        );
    }
  }

  Widget _dropdown(
    FilterSpec f,
    List<({String value, String label})> opts,
    String current,
  ) {
    final values = opts.map((o) => o.value).toSet();
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<String>(
        key: ValueKey('${f.key}-$current'),
        isExpanded: true,
        initialValue: values.contains(current) ? current : null,
        decoration: InputDecoration(
          labelText: f.label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem(value: '', child: Text('Все')),
          for (final o in opts)
            DropdownMenuItem(
              value: o.value,
              child: Text(o.label, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) => onGo(_with(f.key, v ?? '')),
      ),
    );
  }

  ListQuery _with(String key, String value) {
    final next = Map<String, String>.from(query.filters);
    if (value.isEmpty) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    return query.copyWith(filters: next);
  }
}

class _TextFilter extends StatefulWidget {
  const _TextFilter({
    super.key,
    required this.label,
    required this.initial,
    required this.numeric,
    required this.onSubmit,
  });

  final String label;
  final String initial;
  final bool numeric;
  final ValueChanged<String> onSubmit;

  @override
  State<_TextFilter> createState() => _TextFilterState();
}

class _TextFilterState extends State<_TextFilter> {
  late final TextEditingController _ctl = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: TextField(
        controller: _ctl,
        keyboardType: widget.numeric
            ? TextInputType.number
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: widget.label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (v) => widget.onSubmit(v.trim()),
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({
    required this.spec,
    required this.items,
    required this.notifier,
    required this.lookups,
    required this.role,
    required this.onSort,
    required this.onEdit,
    required this.onAction,
    required this.canBulk,
  });

  final CollectionSpec spec;
  final List<PbRecord> items;
  final ListNotifier notifier;
  final Lookups lookups;
  final Role? role;
  final ValueChanged<String> onSort;
  final ValueChanged<String> onEdit;
  final void Function(String action, String id) onAction;
  final bool canBulk;

  String _label(Section s, String id) => lookups.label(s, id);

  @override
  Widget build(BuildContext context) {
    final section = spec.section;
    final canEdit = can(role, section, Op.edit);
    final canSoft = can(role, section, Op.softDelete);
    final canRestore = can(role, section, Op.restore);
    final canHard = can(role, section, Op.hardDelete);
    final hasActions = canEdit || canSoft || canRestore || canHard;

    // Таблица прокручивается по вертикали и по горизонтали внутри своей области.
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: canBulk,
          sortColumnIndex: _sortIndex(),
          sortAscending: !notifier.query.descending,
          columns: [
            for (final c in spec.columns)
              DataColumn(
                label: Text(c.label),
                numeric: c.numeric,
                onSort: c.sortKey == null
                    ? null
                    : (_, __) => onSort(c.sortKey!),
              ),
            if (hasActions) const DataColumn(label: Text('Действия')),
          ],
          rows: [
            for (final r in items)
              DataRow(
                selected: notifier.selected.contains(r.id),
                onSelectChanged: canBulk
                    ? (_) => notifier.toggleSelection(r.id)
                    : null,
                color: r.isDeleted
                    ? WidgetStatePropertyAll(
                        Theme.of(
                          context,
                        ).colorScheme.errorContainer.withValues(alpha: 0.4),
                      )
                    : null,
                cells: [
                  for (final c in spec.columns)
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: Text(
                          c.value(r, _label),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  if (hasActions)
                    DataCell(
                      _Actions(
                        record: r,
                        canEdit: canEdit,
                        canSoft: canSoft,
                        canRestore: canRestore,
                        canHard: canHard,
                        onEdit: onEdit,
                        onAction: onAction,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  int? _sortIndex() {
    final key = notifier.query.sort;
    if (key.isEmpty) return null;
    final idx = spec.columns.indexWhere((c) => c.sortKey == key);
    return idx < 0 ? null : idx;
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.record,
    required this.canEdit,
    required this.canSoft,
    required this.canRestore,
    required this.canHard,
    required this.onEdit,
    required this.onAction,
  });

  final PbRecord record;
  final bool canEdit;
  final bool canSoft;
  final bool canRestore;
  final bool canHard;
  final ValueChanged<String> onEdit;
  final void Function(String action, String id) onAction;

  @override
  Widget build(BuildContext context) {
    final deleted = record.isDeleted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canEdit && !deleted)
          IconButton(
            tooltip: 'Изменить',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => onEdit(record.id),
          ),
        if (canSoft && !deleted)
          IconButton(
            tooltip: 'Удалить',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => onAction('delete', record.id),
          ),
        if (canRestore && deleted)
          IconButton(
            tooltip: 'Восстановить',
            icon: const Icon(Icons.restore),
            onPressed: () => onAction('restore', record.id),
          ),
        if (canHard)
          IconButton(
            tooltip: 'Удалить навсегда',
            icon: const Icon(Icons.delete_forever_outlined),
            onPressed: () => onAction('hard', record.id),
          ),
      ],
    );
  }
}

class _Cards extends StatelessWidget {
  const _Cards({
    required this.spec,
    required this.items,
    required this.notifier,
    required this.lookups,
    required this.role,
    required this.columns,
    required this.onEdit,
    required this.onAction,
    required this.canBulk,
  });

  final CollectionSpec spec;
  final List<PbRecord> items;
  final ListNotifier notifier;
  final Lookups lookups;
  final Role? role;
  final int columns;
  final ValueChanged<String> onEdit;
  final void Function(String action, String id) onAction;
  final bool canBulk;

  @override
  Widget build(BuildContext context) {
    final section = spec.section;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return SingleChildScrollView(
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final r in items)
                SizedBox(
                  width: width,
                  child: Card(
                    color: r.isDeleted
                        ? Theme.of(
                            context,
                          ).colorScheme.errorContainer.withValues(alpha: 0.3)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (canBulk)
                                Checkbox(
                                  value: notifier.selected.contains(r.id),
                                  onChanged: (_) =>
                                      notifier.toggleSelection(r.id),
                                ),
                              Expanded(
                                child: Text(
                                  spec.columns.first.value(r, lookups.label),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          for (final c in spec.columns.skip(1))
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${c.label}: ${c.value(r, lookups.label)}',
                              ),
                            ),
                          if (r.isDeleted)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text('Удалена'),
                            ),
                          _Actions(
                            record: r,
                            canEdit: can(role, section, Op.edit),
                            canSoft: can(role, section, Op.softDelete),
                            canRestore: can(role, section, Op.restore),
                            canHard: can(role, section, Op.hardDelete),
                            onEdit: onEdit,
                            onAction: onAction,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({required this.page, required this.query, required this.onGo});

  final PageResult page;
  final ListQuery query;
  final ValueChanged<ListQuery> onGo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Text('Всего: ${page.totalItems}', overflow: TextOverflow.ellipsis),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: 'Назад',
                onPressed: page.hasPrevious
                    ? () => onGo(query.copyWith(page: query.page - 1))
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${page.page} из ${page.totalPages}'),
              IconButton(
                tooltip: 'Вперёд',
                onPressed: page.hasNext
                    ? () => onGo(query.copyWith(page: query.page + 1))
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: query.perPage,
                items: [
                  for (final n in ListQuery.perPageOptions)
                    DropdownMenuItem(value: n, child: Text('$n / стр.')),
                ],
                onChanged: (v) => onGo(query.copyWith(perPage: v ?? 10)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
