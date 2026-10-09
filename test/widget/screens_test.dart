import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoe_store/app.dart';
import 'package:shoe_store/core/errors.dart';
import 'package:shoe_store/core/permissions.dart';

import '../support/fakes.dart';

void main() {
  final brands = {
    Section.brands: [brand('b1', 'Nike'), brand('b2', 'Adidas')],
  };

  group('четыре состояния списка', () {
    testWidgets('загрузка показывает индикатор, затем данные', (tester) async {
      final api = FakeRecordsApi(data: brands)..gate = Completer<void>();
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = await sessionFor(Role.manager);
      await tester.pumpWidget(
        ShoeStoreApp(auth: auth, api: api, initialLocation: '/brands'),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      api.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Nike'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('пустой результат с кнопкой сброса условий', (tester) async {
      final api = FakeRecordsApi(data: brands);
      await pumpApp(
        tester,
        role: Role.manager,
        api: api,
        location: '/brands?q=zzz',
      );

      expect(find.textContaining('Ничего не найдено'), findsOneWidget);
      expect(find.text('Сбросить условия'), findsOneWidget);
    });

    testWidgets('ошибка сервера и повтор загружает данные', (tester) async {
      final api = FakeRecordsApi(data: brands)..listFailures = 1;
      await pumpApp(tester, role: Role.manager, api: api, location: '/brands');

      expect(find.text('Сервер временно недоступен'), findsOneWidget);
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.text('Nike'), findsOneWidget);
    });
  });

  group('роли и видимость действий', () {
    testWidgets('клиент не видит «Добавить» и кнопок правки', (tester) async {
      await pumpApp(
        tester,
        role: Role.client,
        api: FakeRecordsApi(data: brands),
        location: '/brands',
      );
      expect(find.text('Добавить бренд'), findsNothing);
      expect(find.byTooltip('Изменить'), findsNothing);
    });

    testWidgets('менеджер видит «Добавить» и кнопку правки', (tester) async {
      await pumpApp(
        tester,
        role: Role.manager,
        api: FakeRecordsApi(data: brands),
        location: '/brands',
      );
      expect(find.text('Добавить бренд'), findsOneWidget);
      expect(find.byTooltip('Изменить'), findsWidgets);
    });

    testWidgets(
      'администратор видит переключатель удалённых, но не «Добавить»',
      (tester) async {
        await pumpApp(
          tester,
          role: Role.admin,
          api: FakeRecordsApi(data: brands),
          location: '/brands',
        );
        expect(find.text('Показывать удалённые'), findsOneWidget);
        expect(find.text('Добавить бренд'), findsNothing);
      },
    );

    testWidgets(
      'клиент, открывший форму по адресу вручную, попадает на экран отказа',
      (tester) async {
        await pumpApp(
          tester,
          role: Role.client,
          api: FakeRecordsApi(data: brands),
          location: '/brands/new',
        );
        expect(find.text('Доступ запрещён'), findsOneWidget);
      },
    );
  });

  group('адаптивная раскладка', () {
    testWidgets('360 пикселей: карточки и нижняя панель', (tester) async {
      await pumpApp(
        tester,
        role: Role.manager,
        api: FakeRecordsApi(data: brands),
        location: '/brands',
        size: const Size(360, 800),
      );
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(DataTable), findsNothing);
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('1280 пикселей: таблица и боковая полоса', (tester) async {
      await pumpApp(
        tester,
        role: Role.manager,
        api: FakeRecordsApi(data: brands),
        location: '/brands',
        size: const Size(1280, 900),
      );
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
    });
  });

  group('ошибки полей формы', () {
    testWidgets('422 от сервера показывает текст у поля', (tester) async {
      final api = FakeRecordsApi(data: brands)
        ..createError = const ValidationException('Ошибка валидации.', {
          'country': 'Страна не распознана',
        });
      await pumpApp(
        tester,
        role: Role.manager,
        api: api,
        location: '/brands/new',
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Название *'),
        'Puma',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Страна *'),
        'Нигде',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Год основания *'),
        '1948',
      );
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      expect(find.text('Страна не распознана'), findsOneWidget);
    });

    testWidgets(
      'пустые обязательные поля подсвечиваются без обращения к серверу',
      (tester) async {
        final api = FakeRecordsApi(data: brands);
        await pumpApp(
          tester,
          role: Role.manager,
          api: api,
          location: '/brands/new',
        );

        await tester.tap(find.text('Сохранить'));
        await tester.pumpAndSettle();

        expect(find.text('Заполните поле'), findsWidgets);
        expect(api.data[Section.brands]!.length, 2);
      },
    );
  });

  group('вход', () {
    testWidgets('пустая форма входа не отправляется', (tester) async {
      await pumpApp(
        tester,
        role: null,
        api: FakeRecordsApi(),
        location: '/login',
      );
      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle();
      expect(find.text('Введите почту'), findsOneWidget);
      expect(find.text('Введите пароль'), findsOneWidget);
    });
  });
}
