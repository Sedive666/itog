import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/errors.dart';
import '../core/permissions.dart';
import '../data/catalog.dart';
import '../data/records_api.dart';
import '../models/collection_spec.dart';
import '../models/record.dart';
import '../state/auth_notifier.dart';
import '../state/lookups.dart';
import 'app_scaffold.dart';
import 'status_pages.dart';

/// Общая форма создания и изменения. Поля берутся из спецификации раздела.
class FormScreen extends StatefulWidget {
  const FormScreen({super.key, required this.section, this.id});

  final Section section;

  /// Пусто — создание, иначе — изменение записи с этим идентификатором.
  final String? id;

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  late final CollectionSpec _spec = catalog[widget.section]!;
  final Map<String, TextEditingController> _text = {};
  final Map<String, dynamic> _values = {};

  /// Ошибки клиентской проверки и ошибки сервера (422) по именам полей.
  Map<String, String> _errors = {};
  String? _banner;
  bool _loading = false;
  bool _saving = false;
  AppException? _loadError;

  bool get _isEdit => widget.id != null;

  @override
  void initState() {
    super.initState();
    for (final f in _spec.formFields) {
      if (_isTextKind(f.kind)) {
        _text[f.name] = TextEditingController();
      } else if (f.kind == FieldKind.relationMulti) {
        _values[f.name] = <String>[];
      } else {
        _values[f.name] = null;
      }
    }
    context.read<Lookups>().load({
      for (final f in _spec.formFields)
        if (f.relation != null) f.relation!,
    });
    if (_isEdit) _load();
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  static bool _isTextKind(FieldKind k) =>
      k == FieldKind.text ||
      k == FieldKind.multiline ||
      k == FieldKind.number ||
      k == FieldKind.date;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final rec = await context.read<RecordsApi>().getOne(
        widget.section,
        widget.id!,
      );
      _fillFrom(rec);
    } on AppException catch (e) {
      _loadError = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fillFrom(PbRecord rec) {
    for (final f in _spec.formFields) {
      if (_isTextKind(f.kind)) {
        _text[f.name]!.text = rec.str(f.name);
      } else if (f.kind == FieldKind.relationMulti) {
        _values[f.name] = rec.ids(f.name);
      } else {
        final v = rec.str(f.name);
        _values[f.name] = v.isEmpty ? null : v;
      }
    }
  }

  /// Значение поля в том виде, в каком его примет PocketBase.
  dynamic _valueOf(FieldSpec f) {
    if (_isTextKind(f.kind)) {
      final raw = _text[f.name]!.text.trim();
      if (f.kind == FieldKind.number) {
        return raw.isEmpty ? null : int.tryParse(raw);
      }
      return raw.isEmpty ? '' : raw;
    }
    if (f.kind == FieldKind.relationMulti) {
      return List<String>.from(_values[f.name] as List? ?? const []);
    }
    final v = _values[f.name] as String?;
    return v == null || v.isEmpty ? null : v;
  }

  /// Ошибки клиентской проверки: обязательность, длина, диапазоны, форматы.
  Map<String, String> _validate() {
    final errors = <String, String>{};
    for (final f in _spec.formFields) {
      final value = _valueOf(f);
      final isEmpty =
          value == null ||
          (value is String && value.isEmpty) ||
          (value is List && value.isEmpty);
      if (f.required && isEmpty) {
        errors[f.name] = 'Заполните поле';
        continue;
      }
      if (f.kind == FieldKind.number &&
          _text[f.name]!.text.trim().isNotEmpty &&
          value == null) {
        errors[f.name] = 'Введите целое число';
        continue;
      }
      if (f.kind == FieldKind.number && value == null) continue;
      final text = value is String ? value : (value?.toString() ?? '');
      for (final rule in f.validators) {
        final err = rule(text);
        if (err != null) {
          errors[f.name] = err;
          break;
        }
      }
    }
    return errors;
  }

  Map<String, dynamic> _payload() => {
    for (final f in _spec.formFields) f.name: _valueOf(f),
  };

  Future<void> _save() async {
    final clientErrors = _validate();
    setState(() {
      _errors = clientErrors;
      _banner = null;
    });
    if (clientErrors.isNotEmpty) return;

    setState(() => _saving = true);
    final api = context.read<RecordsApi>();
    try {
      if (_isEdit) {
        await api.update(widget.section, widget.id!, _payload());
      } else {
        await api.create(widget.section, _payload());
      }
      if (!mounted) return;
      context.read<Lookups>().invalidate(widget.section);
      context.go(widget.section.path);
    } on ValidationException catch (e) {
      // Ошибки полей (422) показываются у соответствующих полей, общее сообщение — баннером.
      setState(() {
        _errors = {...e.errors};
        _banner = e.message;
      });
    } on AppException catch (e) {
      setState(() => _banner = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final role = auth.role;
    final section = widget.section;
    final canEdit = _isEdit
        ? can(role, section, Op.edit)
        : can(role, section, Op.create);
    final title = _isEdit
        ? 'Изменить ${_spec.singular}'
        : 'Новая ${_spec.singular}';

    if (_spec.isFormReadOnly || !canEdit) {
      return AppScaffold(title: title, body: const ForbiddenScreen());
    }

    return AppScaffold(
      title: title,
      body: StateView(
        loading: _loading,
        error: _loadError,
        isEmpty: false,
        onRetry: _load,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: FocusTraversalGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_banner != null) ...[
                      Card(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _banner!,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    for (var i = 0; i < _spec.formFields.length; i++) ...[
                      _buildField(
                        _spec.formFields[i],
                        autofocus: i == 0 && !_isEdit,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_spec.quotePreview)
                      _QuotePreview(
                        sneakerId: _values['sneaker'] as String?,
                        customerId: _values['customer'] as String?,
                        quantity:
                            int.tryParse(
                              _text['quantity']?.text.trim() ?? '',
                            ) ??
                            0,
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => context.go(section.path),
                          child: const Text('Отмена'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Сохранить'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(FieldSpec f, {bool autofocus = false}) {
    final error = _errors[f.name];
    final label = f.required ? '${f.label} *' : f.label;

    if (_isTextKind(f.kind)) {
      return TextField(
        controller: _text[f.name],
        autofocus: autofocus,
        maxLines: f.kind == FieldKind.multiline ? 4 : 1,
        keyboardType: f.kind == FieldKind.number ? TextInputType.number : null,
        textInputAction: TextInputAction.next,
        // Перерисовка при каждом изменении: предпросмотр стоимости читает значения формы.
        onChanged: (_) => setState(() => _errors.remove(f.name)),
        decoration: InputDecoration(
          labelText: label,
          helperText: f.hint,
          errorText: error,
          border: const OutlineInputBorder(),
        ),
      );
    }

    if (f.kind == FieldKind.select) {
      return _dropdown(f, label, error, [
        for (final o in f.options) (value: o, label: o),
      ]);
    }

    if (f.kind == FieldKind.relation) {
      final opts = context.watch<Lookups>().options(f.relation!);
      return _dropdown(f, label, error, [
        for (final r in opts) (value: r.id, label: labelOf(f.relation!, r)),
      ]);
    }

    // Множественный выбор: фишки с отметкой.
    final opts = context.watch<Lookups>().options(f.relation!);
    final selected = (_values[f.name] as List).cast<String>();
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        helperText: f.hint,
        errorText: error,
        border: const OutlineInputBorder(),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          if (opts.isEmpty) const Text('Нет записей для выбора'),
          for (final r in opts)
            FilterChip(
              label: Text(labelOf(f.relation!, r)),
              selected: selected.contains(r.id),
              onSelected: (on) {
                setState(() {
                  final next = List<String>.from(selected);
                  on ? next.add(r.id) : next.remove(r.id);
                  _values[f.name] = next;
                  _errors.remove(f.name);
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _dropdown(
    FieldSpec f,
    String label,
    String? error,
    List<({String value, String label})> opts,
  ) {
    final current = _values[f.name] as String?;
    final values = opts.map((o) => o.value).toSet();
    return DropdownButtonFormField<String>(
      key: ValueKey('${f.name}-${values.contains(current) ? current : ''}'),
      isExpanded: true,
      initialValue: values.contains(current) ? current : null,
      decoration: InputDecoration(
        labelText: label,
        errorText: error,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final o in opts)
          DropdownMenuItem(
            value: o.value,
            child: Text(o.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        setState(() {
          _values[f.name] = v;
          _errors.remove(f.name);
        });
      },
    );
  }
}

/// Расчёт стоимости на сервере: показывает цену за пару, скидки и итог.
class _QuotePreview extends StatefulWidget {
  const _QuotePreview({
    required this.sneakerId,
    required this.customerId,
    required this.quantity,
  });

  final String? sneakerId;
  final String? customerId;
  final int quantity;

  @override
  State<_QuotePreview> createState() => _QuotePreviewState();
}

class _QuotePreviewState extends State<_QuotePreview> {
  Future<Map<String, dynamic>>? _future;
  String _key = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant _QuotePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_key != _keyOf(widget)) _reload();
  }

  static String _keyOf(_QuotePreview w) =>
      '${w.sneakerId}|${w.customerId}|${w.quantity}';

  void _reload() {
    _key = _keyOf(widget);
    final sneaker = widget.sneakerId;
    if (sneaker == null || sneaker.isEmpty || widget.quantity < 1) {
      _future = null;
      return;
    }
    _future = context.read<RecordsApi>().quote(
      sneakerId: sneaker,
      customerId: widget.customerId,
      quantity: widget.quantity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) {
      return const Text(
        'Выберите кроссовки и количество, чтобы увидеть стоимость.',
      );
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const LinearProgressIndicator();
        }
        if (snap.hasError) {
          final e = snap.error;
          return Text(
            e is AppException ? e.message : 'Не удалось рассчитать стоимость.',
          );
        }
        final q = snap.data ?? const {};
        final promo = (q['promoPercent'] as num?)?.toInt() ?? 0;
        final loyalty = (q['loyaltyPercent'] as num?)?.toInt() ?? 0;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Расчёт стоимости',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text('Базовая цена: ${q['basePrice']} ₽ за пару'),
                if (promo > 0) Text('Скидка по акции: $promo %'),
                if (loyalty > 0) Text('Скидка по карте лояльности: $loyalty %'),
                Text('Цена за пару: ${q['unitPrice']} ₽'),
                Text(
                  'Итого за ${q['quantity']} пар: ${q['total']} ₽',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
