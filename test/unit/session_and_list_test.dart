import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoe_store/core/api_client.dart';
import 'package:shoe_store/core/errors.dart';
import 'package:shoe_store/core/permissions.dart';
import 'package:shoe_store/data/auth_api.dart';
import 'package:shoe_store/data/catalog.dart';
import 'package:shoe_store/data/records_api.dart';
import 'package:shoe_store/models/collection_spec.dart';
import 'package:shoe_store/models/list_query.dart';
import 'package:shoe_store/models/page_result.dart';
import 'package:shoe_store/models/record.dart';
import 'package:shoe_store/state/auth_notifier.dart';
import 'package:shoe_store/state/list_notifier.dart';

import '../support/fakes.dart';

/// Сценарный транспорт: отвечает функцией, без сети.
class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

/// Ответы списка выдаются по требованию: проверяем порядок, в котором приходят ответы.
class _OrderedApi extends FakeRecordsApi {
  final Map<String, Completer<PageResult>> _waits = {};

  @override
  Future<PageResult> list(
    Section section,
    CollectionSpec spec,
    ListQuery query,
  ) {
    return _waits.putIfAbsent(query.search, Completer<PageResult>.new).future;
  }

  void answer(String search, List<PbRecord> items) {
    _waits[search]!.complete(
      PageResult(
        items: items,
        page: 1,
        perPage: 10,
        totalItems: items.length,
        totalPages: 1,
      ),
    );
  }
}

const _userJson = {'id': 'u1', 'role': 'manager', 'lastName': 'Петров'};

void main() {
  group('сессия и обновление токена', () {
    test('401 на запросе: токен обновляется и запрос повторяется', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var refreshes = 0;
      late AuthNotifier auth;

      final dio = buildApiDio(
        _Tokens(() => auth),
        adapter: ScriptedAdapter((options) async {
          if (options.path.endsWith('/auth-with-password')) {
            return _json({'token': 'old', 'record': _userJson});
          }
          if (options.path.endsWith('/auth-refresh')) {
            refreshes++;
            return _json({'token': 'new', 'record': _userJson});
          }
          // Старый токен отклоняется, новый принимается.
          if (options.headers['Authorization'] != 'new') {
            return _json({'message': 'Сессия истекла'}, 401);
          }
          return _json({
            'items': [],
            'page': 1,
            'perPage': 10,
            'totalItems': 0,
            'totalPages': 1,
          });
        }),
      );
      auth = AuthNotifier(prefs, AuthApi(() => dio));

      await auth.login('manager@shop.test', 'manager123');
      final page = await PocketBaseApi(
        dio,
      ).list(Section.brands, catalog[Section.brands]!, const ListQuery());

      expect(refreshes, 1);
      expect(auth.accessToken, 'new');
      expect(page.items, isEmpty);
    });

    test(
      'если обновление не удалось — сессия завершается с понятной причиной',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        late AuthNotifier auth;
        final dio = buildApiDio(
          _Tokens(() => auth),
          adapter: ScriptedAdapter((options) async {
            if (options.path.endsWith('/auth-with-password')) {
              return _json({'token': 'old', 'record': _userJson});
            }
            return _json({'message': 'Сессия истекла'}, 401);
          }),
        );
        auth = AuthNotifier(prefs, AuthApi(() => dio));
        await auth.login('manager@shop.test', 'manager123');

        AppException? caught;
        try {
          await PocketBaseApi(dio).getOne(Section.brands, 'b1');
        } on AppException catch (e) {
          caught = e;
        }
        expect(caught, isA<UnauthorizedException>());
        expect(auth.isSignedIn, isFalse);
        expect(auth.endReason, contains('Сессия истекла'));
      },
    );

    test('восстановление: вход старше 30 минут сбрасывается', () async {
      final loginAt = DateTime(2026, 10, 9, 10);
      SharedPreferences.setMockInitialValues({
        'auth_token': 'old',
        'auth_user': jsonEncode(_userJson),
        'auth_login_at': loginAt.toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();
      final auth = AuthNotifier(
        prefs,
        AuthApi(() => Dio()),
        clock: () => loginAt.add(const Duration(hours: 1)),
      );
      await auth.restore();
      expect(auth.isSignedIn, isFalse);
      expect(auth.endReason, contains('истёк'));
    });

    test('восстановление без сервера: сессия остаётся', () async {
      final loginAt = DateTime(2026, 10, 9, 10);
      SharedPreferences.setMockInitialValues({
        'auth_token': 'old',
        'auth_user': jsonEncode(_userJson),
        'auth_login_at': loginAt.toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();
      final dio = buildApiDio(
        _Tokens(() => null),
        adapter: ScriptedAdapter(
          (options) async => throw DioException.connectionError(
            requestOptions: options,
            reason: 'нет сети',
          ),
        ),
      );
      final auth = AuthNotifier(
        prefs,
        AuthApi(() => dio),
        clock: () => loginAt.add(const Duration(minutes: 5)),
      );
      await auth.restore();
      expect(auth.isSignedIn, isTrue);
      expect(auth.role, Role.manager);
    });
  });

  group('состояние списка', () {
    test('ответ устаревшего запроса не перезаписывает свежий', () async {
      final api = _OrderedApi();
      final notifier = ListNotifier(
        api,
        Section.brands,
        catalog[Section.brands]!,
      );

      final first = notifier.applyQuery(const ListQuery(search: 'a'));
      final second = notifier.applyQuery(const ListQuery(search: 'b'));
      api.answer('b', [brand('2', 'Новый')]);
      await second;
      api.answer('a', [brand('1', 'Старый')]);
      await first;

      expect(notifier.query.search, 'b');
      expect(notifier.result!.items.single.id, '2');
    });

    test(
      'ошибка сервера даёт состояние ошибки, повтор загружает данные',
      () async {
        final api = FakeRecordsApi(
          data: {
            Section.brands: [brand('7', 'Nike')],
          },
        )..listFailures = 1;
        final notifier = ListNotifier(
          api,
          Section.brands,
          catalog[Section.brands]!,
        );

        await notifier.applyQuery(const ListQuery());
        expect(notifier.status, ListStatus.error);
        expect(notifier.error, isA<ServerException>());

        await notifier.retry();
        expect(notifier.status, ListStatus.success);
        expect(notifier.result!.items.single.id, '7');
      },
    );

    test(
      'отказ при удалении показывается текстом действия и не падает',
      () async {
        final api = _DenyingApi();
        final notifier = ListNotifier(
          api,
          Section.brands,
          catalog[Section.brands]!,
        );
        await notifier.applyQuery(const ListQuery());

        final ok = await notifier.softDelete('7');
        expect(ok, isFalse);
        expect(notifier.actionError, 'Нет прав');
        expect(notifier.status, ListStatus.success);
      },
    );
  });
}

/// Удаление всегда отказано: проверяем сообщение действия.
class _DenyingApi extends FakeRecordsApi {
  _DenyingApi()
    : super(
        data: {
          Section.brands: [brand('7', 'Nike')],
        },
      );

  @override
  Future<void> softDelete(Section section, String id) async =>
      throw const ForbiddenException('Нет прав');
}

/// Токены берутся из настоящей сессии, поэтому обновление проверяется end-to-end.
class _Tokens implements SessionTokens {
  _Tokens(this._auth);
  final AuthNotifier? Function() _auth;

  @override
  String? get accessToken => _auth()?.accessToken;

  @override
  Future<bool> refreshSession() async =>
      _auth()?.refreshSession() ?? Future.value(false);
}
