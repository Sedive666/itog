import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:shoe_store/app.dart';
import 'package:shoe_store/core/errors.dart';
import 'package:shoe_store/core/permissions.dart';
import 'package:shoe_store/data/auth_api.dart';
import 'package:shoe_store/data/records_api.dart';
import 'package:shoe_store/models/collection_spec.dart';
import 'package:shoe_store/models/list_query.dart';
import 'package:shoe_store/models/page_result.dart';
import 'package:shoe_store/models/record.dart';
import 'package:shoe_store/state/auth_notifier.dart';

/// Подменяет сервер: данные в памяти, по желанию — задержка, ошибки и отказы.
class FakeRecordsApi implements RecordsApi {
  FakeRecordsApi({Map<Section, List<PbRecord>>? data}) : data = data ?? {};

  final Map<Section, List<PbRecord>> data;

  /// Если задан, список ждёт этот completer (чтобы увидеть состояние загрузки).
  Completer<void>? gate;

  /// Сколько следующих запросов списка завершатся ошибкой сервера.
  int listFailures = 0;

  /// Ошибка, которую вернёт следующее создание записи.
  AppException? createError;

  int listCalls = 0;
  Map<String, dynamic> quoteResult = const {
    'basePrice': 15990,
    'promoPercent': 20,
    'loyaltyPercent': 5,
    'unitPrice': 12152,
    'quantity': 1,
    'total': 12152,
  };
  final List<String> softDeleted = [];

  @override
  Future<PageResult> list(
    Section section,
    CollectionSpec spec,
    ListQuery query,
  ) async {
    listCalls++;
    if (gate != null) await gate!.future;
    if (listFailures > 0) {
      listFailures--;
      throw const ServerException('Сервер временно недоступен');
    }
    final all = (data[section] ?? const <PbRecord>[])
        .where((r) => query.includeDeleted || !r.isDeleted)
        .where(
          (r) =>
              query.search.isEmpty ||
              r.data.values.any((v) => '$v'.contains(query.search)),
        )
        .toList();
    final start = (query.page - 1) * query.perPage;
    final items = all.skip(start).take(query.perPage).toList();
    final totalPages = all.isEmpty ? 1 : (all.length / query.perPage).ceil();
    return PageResult(
      items: items,
      page: query.page,
      perPage: query.perPage,
      totalItems: all.length,
      totalPages: totalPages,
    );
  }

  @override
  Future<List<PbRecord>> all(Section section) async =>
      data[section] ?? const [];

  @override
  Future<PbRecord> getOne(Section section, String id) async {
    return (data[section] ?? const <PbRecord>[]).firstWhere(
      (r) => r.id == id,
      orElse: () => throw const NotFoundException(),
    );
  }

  @override
  Future<PbRecord> create(Section section, Map<String, dynamic> payload) async {
    if (createError != null) throw createError!;
    final rec = PbRecord('new-${data[section]?.length ?? 0}', payload);
    data.putIfAbsent(section, () => []).add(rec);
    return rec;
  }

  @override
  Future<PbRecord> update(
    Section section,
    String id,
    Map<String, dynamic> payload,
  ) async {
    if (createError != null) throw createError!;
    return PbRecord(id, payload);
  }

  @override
  Future<void> softDelete(Section section, String id) async =>
      softDeleted.add(id);

  @override
  Future<void> restore(Section section, String id) async {}

  @override
  Future<void> hardDelete(Section section, String id) async {}

  @override
  Future<int> bulkDelete(Section section, List<String> ids) async => ids.length;

  @override
  Future<Map<String, dynamic>> quote({
    required String sneakerId,
    String? customerId,
    required int quantity,
  }) async => quoteResult;

  @override
  Future<Map<String, dynamic>> statsSummary() async => {
    'ordersTotal': 3,
    'ordersActive': 2,
    'revenue': 40000,
    'byBrand': [
      {'brand': 'Nike', 'revenue': 30000},
      {'brand': 'Adidas', 'revenue': 10000},
    ],
    'byStatus': [
      {'status': 'Новый', 'count': 1},
      {'status': 'Отменён', 'count': 1},
    ],
    'lowStock': 1,
  };

  @override
  Future<List<int>> exportCsv(Section section, List<String> fields) async =>
      const [];
}

/// Пустой Dio для AuthNotifier: в тестах интерфейса сеть не используется.
Future<AuthNotifier> sessionFor(Role? role) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = AuthNotifier(prefs, AuthApi(() => Dio()));
  if (role != null) {
    auth.debugSignIn(
      PbRecord('u-${role.name}', {
        'role': role.name,
        'lastName': 'Тестов',
        'customer': 'c1',
      }),
    );
  }
  return auth;
}

/// Запуск приложения в тесте под ролью и с заданным адресом.
Future<void> pumpApp(
  WidgetTester tester, {
  required Role? role,
  required FakeRecordsApi api,
  String location = '/',
  Size size = const Size(1280, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = await sessionFor(role);
  await tester.pumpWidget(
    ShoeStoreApp(auth: auth, api: api, initialLocation: location),
  );
  await tester.pumpAndSettle();
}

PbRecord brand(String id, String name, {String? deleted}) => PbRecord(id, {
  'name': name,
  'country': 'США',
  'year': 1971,
  'deleted': deleted ?? '',
});
