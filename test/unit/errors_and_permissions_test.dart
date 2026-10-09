import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoe_store/core/api_client.dart';
import 'package:shoe_store/core/errors.dart';
import 'package:shoe_store/core/permissions.dart';
import 'package:shoe_store/models/page_result.dart';
import 'package:shoe_store/router.dart';

DioException _dio(DioExceptionType type) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  type: type,
);

DioException _status(int code, Object? body) => DioException.badResponse(
  statusCode: code,
  requestOptions: RequestOptions(path: '/x'),
  response: Response(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: code,
    data: body,
  ),
);

void main() {
  group('перевод ошибок сети и сервера', () {
    test('нет соединения — понятное сообщение о сервере', () {
      final e = mapDioException(_dio(DioExceptionType.connectionError));
      expect(e, isA<NetworkException>());
      expect(e.message, contains('Сервер недоступен'));
    });

    test('таймаут — отдельное исключение', () {
      expect(
        mapDioException(_dio(DioExceptionType.receiveTimeout)),
        isA<TimeoutException>(),
      );
      expect(
        mapDioException(_dio(DioExceptionType.connectionTimeout)),
        isA<TimeoutException>(),
      );
    });

    test('422 с ошибками полей: ключи совпадают с именами полей формы', () {
      final e = mapDioException(
        _status(422, {
          'message': 'Ошибка валидации.',
          'data': {
            'stockAvailable': {
              'code': 'invalid',
              'message': 'Доступно пар не может быть больше общего',
            },
          },
        }),
      );
      expect(e, isA<ValidationException>());
      final v = e as ValidationException;
      expect(
        v.errors['stockAvailable'],
        'Доступно пар не может быть больше общего',
      );
      expect(v.message, 'Ошибка валидации.');
    });

    test(
      '400 с полями — тоже ошибка полей, а 400 без полей — отказ в правах',
      () {
        final withFields = mapDioException(
          _status(400, {
            'message': 'Проверьте поля.',
            'data': {
              'email': {
                'code': 'validation_required',
                'message': 'Обязательное поле.',
              },
            },
          }),
        );
        expect(withFields, isA<ValidationException>());

        final rule = mapDioException(
          _status(400, {
            'message': 'Something went wrong while processing your request.',
            'data': <String, dynamic>{},
          }),
        );
        expect(rule, isA<ForbiddenException>());
        expect(rule.message, 'Недостаточно прав для этого действия.');
      },
    );

    test(
      '409 — конфликт с текстом сервера (например, число связанных записей)',
      () {
        final e = mapDioException(
          _status(409, {
            'message': 'Нельзя удалить бренд: на него ссылаются кроссовки (2).',
            'data': <String, dynamic>{},
          }),
        );
        expect(e, isA<ConflictException>());
        expect(e.message, contains('(2)'));
      },
    );

    test('401 и 404 и 500 переводятся в свои исключения', () {
      expect(mapHttpResponse(401, null), isA<UnauthorizedException>());
      expect(mapHttpResponse(404, null), isA<NotFoundException>());
      expect(mapHttpResponse(500, null), isA<ServerException>());
    });
  });

  group('разбор страницы списка', () {
    test('конверт PocketBase: perPage и totalItems попадают в поля', () {
      final page = PageResult.fromJson({
        'page': 2,
        'perPage': 10,
        'totalItems': 26,
        'totalPages': 3,
        'items': [
          {'id': 'a', 'name': 'x'},
        ],
      });
      expect(page.page, 2);
      expect(page.perPage, 10);
      expect(page.totalItems, 26);
      expect(page.totalPages, 3);
      expect(page.hasPrevious, isTrue);
      expect(page.hasNext, isTrue);
      expect(page.items.single.id, 'a');
    });
  });

  group('права ролей', () {
    test('клиент читает каталог, но не создаёт бренды', () {
      expect(can(Role.client, Section.brands, Op.read), isTrue);
      expect(can(Role.client, Section.brands, Op.create), isFalse);
    });

    test('менеджер создаёт и мягко удаляет, но не восстанавливает', () {
      expect(can(Role.manager, Section.sneakers, Op.create), isTrue);
      expect(can(Role.manager, Section.sneakers, Op.softDelete), isTrue);
      expect(can(Role.manager, Section.sneakers, Op.restore), isFalse);
    });

    test(
      'администратор восстанавливает и удаляет навсегда, но не создаёт записи',
      () {
        expect(can(Role.admin, Section.sneakers, Op.restore), isTrue);
        expect(can(Role.admin, Section.sneakers, Op.hardDelete), isTrue);
        expect(can(Role.admin, Section.sneakers, Op.create), isFalse);
      },
    );

    test('у каждой роли есть раздел, которого нет у остальных', () {
      expect(sectionsOf(Role.client).contains(Section.promotions), isFalse);
      expect(sectionsOf(Role.manager).contains(Section.promotions), isTrue);
      expect(canSeeStats(Role.client), isFalse);
      expect(canSeeStats(Role.manager), isTrue);
    });
  });

  group('маршруты', () {
    test('гость уходит на вход и возвращается на свой адрес', () {
      final r = guardRedirect(role: null, uri: Uri.parse('/brands/new'));
      expect(r, startsWith('/login?from='));
      expect(Uri.decodeComponent(r!.split('from=').last), '/brands/new');
    });

    test('клиент не открывает форму создания бренда — экран отказа', () {
      expect(
        guardRedirect(role: Role.client, uri: Uri.parse('/brands/new')),
        '/forbidden',
      );
    });

    test('клиент не открывает отчёт и чужие разделы', () {
      expect(
        guardRedirect(role: Role.client, uri: Uri.parse('/stats')),
        '/forbidden',
      );
      expect(
        guardRedirect(role: Role.client, uri: Uri.parse('/promotions')),
        '/forbidden',
      );
    });

    test('неизвестный адрес ведёт на 404', () {
      expect(
        guardRedirect(role: Role.admin, uri: Uri.parse('/нет-такого')),
        '/not-found',
      );
    });

    test(
      'менеджер открывает свою форму и не открывает отчёт администратора',
      () {
        expect(
          guardRedirect(role: Role.manager, uri: Uri.parse('/sneakers/new')),
          isNull,
        );
        expect(
          guardRedirect(role: Role.manager, uri: Uri.parse('/stats')),
          isNull,
        );
      },
    );

    test('главный раздел зависит от роли', () {
      expect(homeFor(Role.admin), '/stats');
      expect(homeFor(Role.manager), '/orders');
      expect(homeFor(Role.client), '/sneakers');
    });
  });
}
