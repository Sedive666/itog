import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/permissions.dart';
import '../models/collection_spec.dart';
import '../models/list_query.dart';
import '../models/page_result.dart';
import '../models/record.dart';

/// Доступ к записям. Экраны и состояние зависят только от интерфейса, поэтому в тестах подменяется.
abstract interface class RecordsApi {
  Future<PageResult> list(
    Section section,
    CollectionSpec spec,
    ListQuery query,
  );
  Future<List<PbRecord>> all(Section section);
  Future<PbRecord> getOne(Section section, String id);
  Future<PbRecord> create(Section section, Map<String, dynamic> payload);
  Future<PbRecord> update(
    Section section,
    String id,
    Map<String, dynamic> payload,
  );

  /// Мягкое удаление: поле deleted получает текущую дату.
  Future<void> softDelete(Section section, String id);
  Future<void> restore(Section section, String id);

  /// Физическое удаление (только администратор).
  Future<void> hardDelete(Section section, String id);

  /// Мягкое удаление нескольких записей; возвращает число удалённых.
  Future<int> bulkDelete(Section section, List<String> ids);

  /// Расчёт стоимости заказа на сервере.
  Future<Map<String, dynamic>> quote({
    required String sneakerId,
    String? customerId,
    required int quantity,
  });

  Future<Map<String, dynamic>> statsSummary();

  /// CSV по выбранным полям, в виде байтов.
  Future<List<int>> exportCsv(Section section, List<String> fields);
}

/// Реализация поверх PocketBase REST API.
class PocketBaseApi implements RecordsApi {
  PocketBaseApi(this._dio);

  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  String _path(Section s) => '/collections/${s.collection}/records';

  @override
  Future<PageResult> list(
    Section section,
    CollectionSpec spec,
    ListQuery query,
  ) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      _path(section),
      queryParameters: {
        'page': query.page,
        'perPage': query.perPage,
        'sort': spec.buildSort(query),
        if (spec.buildFilter(query).isNotEmpty)
          'filter': spec.buildFilter(query),
      },
    );
    return PageResult.fromJson(res.data ?? const {});
  });

  @override
  Future<List<PbRecord>> all(Section section) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      _path(section),
      queryParameters: {'perPage': 500, 'filter': 'deleted = ""'},
    );
    final items = (res.data?['items'] as List?) ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(PbRecord.fromJson)
        .toList();
  });

  @override
  Future<PbRecord> getOne(Section section, String id) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>('${_path(section)}/$id');
    return PbRecord.fromJson(res.data ?? const {});
  });

  @override
  Future<PbRecord> create(Section section, Map<String, dynamic> payload) =>
      _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          _path(section),
          data: payload,
        );
        return PbRecord.fromJson(res.data ?? const {});
      });

  @override
  Future<PbRecord> update(
    Section section,
    String id,
    Map<String, dynamic> payload,
  ) => _guard(() async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '${_path(section)}/$id',
      data: payload,
    );
    return PbRecord.fromJson(res.data ?? const {});
  });

  @override
  Future<void> softDelete(Section section, String id) => _guard<void>(() async {
    await _dio.patch<dynamic>(
      '${_path(section)}/$id',
      data: {'deleted': DateTime.now().toUtc().toIso8601String()},
    );
  });

  @override
  Future<void> restore(Section section, String id) => _guard<void>(() async {
    await _dio.post<dynamic>('/restore/${section.collection}/$id');
  });

  @override
  Future<void> hardDelete(Section section, String id) => _guard<void>(() async {
    await _dio.delete<dynamic>('${_path(section)}/$id');
  });

  @override
  Future<int> bulkDelete(Section section, List<String> ids) => _guard(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/bulk-delete/${section.collection}',
      data: {'ids': ids},
    );
    return (res.data?['deleted'] as num?)?.toInt() ?? 0;
  });

  @override
  Future<Map<String, dynamic>> quote({
    required String sneakerId,
    String? customerId,
    required int quantity,
  }) => _guard(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/orders/quote',
      data: {
        'sneakerId': sneakerId,
        if (customerId != null && customerId.isNotEmpty)
          'customerId': customerId,
        'quantity': quantity,
      },
    );
    return res.data ?? const {};
  });

  @override
  Future<Map<String, dynamic>> statsSummary() => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>('/stats/summary');
    return res.data ?? const {};
  });

  @override
  Future<List<int>> exportCsv(Section section, List<String> fields) =>
      _guard(() async {
        final res = await _dio.get<List<int>>(
          '/export/${section.collection}',
          queryParameters: {'fields': fields.join(',')},
          options: Options(responseType: ResponseType.bytes),
        );
        return res.data ?? const <int>[];
      });
}
