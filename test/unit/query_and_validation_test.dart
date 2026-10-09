import 'package:flutter_test/flutter_test.dart';
import 'package:shoe_store/core/permissions.dart';
import 'package:shoe_store/data/catalog.dart';
import 'package:shoe_store/models/list_query.dart';
import 'package:shoe_store/models/record.dart';
import 'package:shoe_store/models/validators.dart';

void main() {
  sortRegression();
  group('ListQuery из адресной строки', () {
    test('значения по умолчанию не попадают в адрес', () {
      const q = ListQuery();
      expect(q.toUrlParams(), isEmpty);
    });

    test('условия переживают круговой путь: адрес → условия → адрес', () {
      final params = {
        'q': 'air',
        'sort': 'price',
        'dir': 'desc',
        'page': '2',
        'size': '25',
        'deleted': '1',
        'brand': 'b1',
      };
      final q = ListQuery.fromUrlParams(params, filterKeys: {'brand'});
      expect(q.search, 'air');
      expect(q.sort, 'price');
      expect(q.descending, isTrue);
      expect(q.page, 2);
      expect(q.perPage, 25);
      expect(q.includeDeleted, isTrue);
      expect(q.filters, {'brand': 'b1'});
      expect(q.toUrlParams(), params);
    });

    test('неверные значения заменяются безопасными', () {
      final q = ListQuery.fromUrlParams({
        'page': '-4',
        'size': '777',
        'dir': 'вверх',
      });
      expect(q.page, 1);
      expect(q.perPage, 10);
      expect(q.descending, isFalse);
    });

    test('любое изменение условий возвращает на первую страницу', () {
      final q = ListQuery.fromUrlParams({'page': '3'}).copyWith(search: 'x');
      expect(q.page, 1);
    });
  });

  group('фильтр и сортировка PocketBase', () {
    final sneakers = catalog[Section.sneakers]!;

    test('поиск по нескольким полям через ИЛИ и скрытие удалённых', () {
      final f = sneakers.buildFilter(const ListQuery(search: 'air'));
      expect(f, 'deleted = "" && (name ~ "air" || sku ~ "air")');
    });

    test('фильтры по связи, диапазону цены и остатку соединяются через И', () {
      final f = sneakers.buildFilter(
        const ListQuery(
          filters: {
            'brand': 'b1',
            'minPrice': '10000',
            'maxPrice': '20000',
            'minStock': '1',
          },
        ),
      );
      expect(f, contains('deleted = ""'));
      expect(f, contains('brand = "b1"'));
      expect(f, contains('price >= 10000'));
      expect(f, contains('price <= 20000'));
      expect(f, contains('stockAvailable >= 1'));
    });

    test('ввод пользователя с кавычками не превращается в условие', () {
      final f = sneakers.buildFilter(
        const ListQuery(search: 'a" || deleted != "'),
      );
      // Кавычки из ввода удалены: текст остаётся одной строкой внутри поиска.
      expect(
        f,
        'deleted = "" && (name ~ "a || deleted != " || sku ~ "a || deleted != ")',
      );
    });

    test('сортировка только из белого списка и по убыванию', () {
      expect(sneakers.buildSort(const ListQuery(sort: 'price')), 'price');
      expect(
        sneakers.buildSort(const ListQuery(sort: 'price', descending: true)),
        '-price',
      );
      expect(
        sneakers.buildSort(const ListQuery(sort: 'password')),
        sneakers.defaultSort,
      );
    });
  });

  group('валидаторы полей', () {
    test('обязательное поле и границы длины', () {
      expect(requiredField('Введите имя')('   '), 'Введите имя');
      expect(requiredField()('ok'), isNull);
      expect(maxLength(3)('abcd'), 'Не длиннее 3 символов');
      expect(minLength(2)('a'), 'Не короче 2 символов');
    });

    test('целое число в диапазоне', () {
      final rule = intRange(1, 90);
      expect(rule('0'), 'От 1 до 90');
      expect(rule('91'), 'От 1 до 90');
      expect(rule('abc'), 'Введите целое число');
      expect(rule('45'), isNull);
    });

    test('дата и порядок дат', () {
      expect(isoDate()('2026-02-30x'), 'Дата в формате ГГГГ-ММ-ДД');
      expect(isoDate()('2026-06-15'), isNull);
      expect(notBefore('2026-06-15', '2026-06-01'), 'Не раньше даты начала');
      expect(notBefore('2026-06-01', '2026-06-15'), isNull);
    });

    test('телефон и почта', () {
      expect(phone()('+7 900 123-45-67'), isNull);
      expect(phone()('12'), isNotNull);
      expect(email()('a@b.c'), isNull);
      expect(email()('без-собаки'), isNotNull);
    });
  });

  group('разбор записи PocketBase', () {
    test('поля читаются безопасно, пустая дата даёт null', () {
      final r = PbRecord.fromJson({
        'id': 'abc',
        'price': 12990,
        'name': 'Air',
        'categories': ['c1', 'c2'],
        'deleted': '',
        'created': '2026-10-01 10:00:00.000Z',
      });
      expect(r.id, 'abc');
      expect(r.intOf('price'), 12990);
      expect(r.str('missing'), '');
      expect(r.ids('categories'), ['c1', 'c2']);
      expect(r.isDeleted, isFalse);
      expect(r.date('deleted'), isNull);
      expect(r.date('created'), isNotNull);
    });

    test('мягко удалённая запись определяется по дате в deleted', () {
      final r = PbRecord('x', {'deleted': '2026-10-05 08:00:00.000Z'});
      expect(r.isDeleted, isTrue);
    });
  });
}

void sortRegression() {
  group('сортировка разделов', () {
    test(
      'поля сортировки существуют в схеме: у коллекций нет поля created',
      () {
        for (final spec in catalog.values) {
          expect(
            spec.defaultSort.replaceFirst('-', ''),
            isNot('created'),
            reason: spec.title,
          );
          expect(
            spec.sortFields.values,
            isNot(contains('created')),
            reason: spec.title,
          );
        }
      },
    );
  });
}
