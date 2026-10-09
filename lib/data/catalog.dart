import '../core/permissions.dart';
import '../models/collection_spec.dart';
import '../models/record.dart';
import '../models/validators.dart';

/// Подписи связей: раздел и идентификатор → подпись (из кэша справочников).
typedef Labeler = String Function(Section section, String id);

const sizes = [
  '35',
  '36',
  '37',
  '38',
  '39',
  '40',
  '41',
  '42',
  '43',
  '44',
  '45',
  '46',
  '47',
  '48',
];
const orderStatuses = ['Новый', 'Оплачен', 'Отправлен', 'Доставлен', 'Отменён'];
const cardLevels = ['Серебряная', 'Золотая', 'Платиновая'];

/// Все разделы приложения. Экраны общие, различаются только описания.
final Map<Section, CollectionSpec> catalog = {
  Section.brands: CollectionSpec(
    section: Section.brands,
    title: 'Бренды',
    singular: 'бренд',
    searchFields: const ['name', 'country'],
    sortFields: const {'name': 'name', 'country': 'country', 'year': 'year'},
    defaultSort: 'name',
    filters: const [
      FilterSpec(
        key: 'country',
        label: 'Страна',
        kind: FilterKind.equalsText,
        field: 'country',
      ),
    ],
    columns: [
      ColumnSpec('Название', (r, _) => r.str('name'), sortKey: 'name'),
      ColumnSpec('Страна', (r, _) => r.str('country'), sortKey: 'country'),
      ColumnSpec(
        'Год',
        (r, _) => r.str('year'),
        numeric: true,
        sortKey: 'year',
      ),
    ],
    formFields: [
      FieldSpec(
        name: 'name',
        label: 'Название',
        kind: FieldKind.text,
        required: true,
        validators: [minLength(2), maxLength(60)],
      ),
      FieldSpec(
        name: 'country',
        label: 'Страна',
        kind: FieldKind.text,
        required: true,
        validators: [maxLength(60)],
      ),
      FieldSpec(
        name: 'year',
        label: 'Год основания',
        kind: FieldKind.number,
        required: true,
        validators: [intRange(1900, 2100)],
      ),
    ],
  ),
  Section.series: CollectionSpec(
    section: Section.series,
    title: 'Серии',
    singular: 'серия',
    searchFields: const ['name'],
    sortFields: const {'name': 'name', 'year': 'year'},
    defaultSort: 'name',
    filters: const [
      FilterSpec(
        key: 'brand',
        label: 'Бренд',
        kind: FilterKind.relation,
        field: 'brand',
        relation: Section.brands,
      ),
    ],
    columns: [
      ColumnSpec('Название', (r, _) => r.str('name'), sortKey: 'name'),
      ColumnSpec('Бренд', (r, l) => l(Section.brands, r.str('brand'))),
      ColumnSpec(
        'Год',
        (r, _) => r.str('year'),
        numeric: true,
        sortKey: 'year',
      ),
    ],
    formFields: [
      FieldSpec(
        name: 'name',
        label: 'Название',
        kind: FieldKind.text,
        required: true,
        validators: [minLength(2), maxLength(60)],
      ),
      FieldSpec(
        name: 'brand',
        label: 'Бренд',
        kind: FieldKind.relation,
        required: true,
        relation: Section.brands,
      ),
      FieldSpec(
        name: 'year',
        label: 'Год',
        kind: FieldKind.number,
        validators: [intRange(1900, 2100)],
      ),
    ],
  ),
  Section.categories: CollectionSpec(
    section: Section.categories,
    title: 'Категории',
    singular: 'категория',
    searchFields: const ['name', 'description'],
    sortFields: const {'name': 'name'},
    defaultSort: 'name',
    columns: [
      ColumnSpec('Название', (r, _) => r.str('name'), sortKey: 'name'),
      ColumnSpec('Описание', (r, _) => r.str('description')),
    ],
    formFields: [
      FieldSpec(
        name: 'name',
        label: 'Название',
        kind: FieldKind.text,
        required: true,
        validators: [minLength(2), maxLength(60)],
      ),
      FieldSpec(
        name: 'description',
        label: 'Описание',
        kind: FieldKind.multiline,
        validators: [maxLength(500)],
      ),
    ],
  ),
  Section.sneakers: CollectionSpec(
    section: Section.sneakers,
    title: 'Кроссовки',
    singular: 'кроссовки',
    searchFields: const ['name', 'sku'],
    sortFields: const {
      'name': 'name',
      'price': 'price',
      'stock': 'stockAvailable',
      'year': 'year',
    },
    defaultSort: 'name',
    filters: const [
      FilterSpec(
        key: 'brand',
        label: 'Бренд',
        kind: FilterKind.relation,
        field: 'brand',
        relation: Section.brands,
      ),
      FilterSpec(
        key: 'category',
        label: 'Категория',
        kind: FilterKind.relationMulti,
        field: 'categories',
        relation: Section.categories,
      ),
      FilterSpec(
        key: 'minPrice',
        label: 'Цена от',
        kind: FilterKind.minNumber,
        field: 'price',
      ),
      FilterSpec(
        key: 'maxPrice',
        label: 'Цена до',
        kind: FilterKind.maxNumber,
        field: 'price',
      ),
      FilterSpec(
        key: 'minStock',
        label: 'Остаток от',
        kind: FilterKind.minNumber,
        field: 'stockAvailable',
      ),
    ],
    columns: [
      ColumnSpec('Название', (r, _) => r.str('name'), sortKey: 'name'),
      ColumnSpec('Артикул', (r, _) => r.str('sku')),
      ColumnSpec('Бренд', (r, l) => l(Section.brands, r.str('brand'))),
      ColumnSpec(
        'Цена, ₽',
        (r, _) => r.str('price'),
        numeric: true,
        sortKey: 'price',
      ),
      ColumnSpec(
        'На складе',
        (r, _) => '${r.str('stockAvailable')} из ${r.str('stockTotal')}',
        numeric: true,
        sortKey: 'stock',
      ),
    ],
    formFields: [
      FieldSpec(
        name: 'name',
        label: 'Название',
        kind: FieldKind.text,
        required: true,
        validators: [minLength(2), maxLength(100)],
      ),
      FieldSpec(
        name: 'sku',
        label: 'Артикул',
        kind: FieldKind.text,
        required: true,
        validators: [
          pattern(
            RegExp(r'^[A-Za-z0-9-]{4,20}$'),
            'Латиница, цифры и дефис, от 4 до 20 знаков',
          ),
        ],
      ),
      FieldSpec(
        name: 'year',
        label: 'Год выпуска',
        kind: FieldKind.number,
        required: true,
        validators: [intRange(1990, 2100)],
      ),
      FieldSpec(
        name: 'price',
        label: 'Цена, ₽',
        kind: FieldKind.number,
        required: true,
        validators: [intRange(1, 1000000)],
      ),
      FieldSpec(
        name: 'stockTotal',
        label: 'Всего пар',
        kind: FieldKind.number,
        required: true,
        validators: [intRange(0, 100000)],
      ),
      FieldSpec(
        name: 'stockAvailable',
        label: 'Доступно пар',
        kind: FieldKind.number,
        required: true,
        validators: [intRange(0, 100000)],
        hint: 'Не больше общего количества',
      ),
      FieldSpec(
        name: 'brand',
        label: 'Бренд',
        kind: FieldKind.relation,
        required: true,
        relation: Section.brands,
      ),
      FieldSpec(
        name: 'series',
        label: 'Серии',
        kind: FieldKind.relationMulti,
        relation: Section.series,
      ),
      FieldSpec(
        name: 'categories',
        label: 'Категории',
        kind: FieldKind.relationMulti,
        relation: Section.categories,
      ),
    ],
  ),
  Section.promotions: CollectionSpec(
    section: Section.promotions,
    title: 'Акции',
    singular: 'акция',
    searchFields: const ['title'],
    sortFields: const {
      'title': 'title',
      'from': 'dateFrom',
      'percent': 'percent',
    },
    defaultSort: '-dateFrom',
    filters: const [
      FilterSpec(
        key: 'sneaker',
        label: 'Кроссовки',
        kind: FilterKind.relationMulti,
        field: 'sneakers',
        relation: Section.sneakers,
      ),
      FilterSpec(
        key: 'minPercent',
        label: 'Скидка от, %',
        kind: FilterKind.minNumber,
        field: 'percent',
      ),
    ],
    columns: [
      ColumnSpec('Название', (r, _) => r.str('title'), sortKey: 'title'),
      ColumnSpec(
        'Скидка, %',
        (r, _) => r.str('percent'),
        numeric: true,
        sortKey: 'percent',
      ),
      ColumnSpec(
        'Период',
        (r, _) => '${r.str('dateFrom')} — ${r.str('dateTo')}',
        sortKey: 'from',
      ),
      ColumnSpec(
        'Кроссовки',
        (r, l) =>
            r.ids('sneakers').map((id) => l(Section.sneakers, id)).join(', '),
      ),
    ],
    formFields: [
      FieldSpec(
        name: 'title',
        label: 'Название',
        kind: FieldKind.text,
        required: true,
        validators: [minLength(3), maxLength(100)],
      ),
      FieldSpec(
        name: 'percent',
        label: 'Скидка, %',
        kind: FieldKind.number,
        required: true,
        validators: [intRange(1, 90)],
      ),
      FieldSpec(
        name: 'dateFrom',
        label: 'Начало (ГГГГ-ММ-ДД)',
        kind: FieldKind.date,
        required: true,
        validators: [isoDate()],
      ),
      FieldSpec(
        name: 'dateTo',
        label: 'Окончание (ГГГГ-ММ-ДД)',
        kind: FieldKind.date,
        required: true,
        validators: [isoDate()],
      ),
      FieldSpec(
        name: 'sneakers',
        label: 'Кроссовки',
        kind: FieldKind.relationMulti,
        relation: Section.sneakers,
      ),
    ],
  ),
  Section.customers: CollectionSpec(
    section: Section.customers,
    title: 'Клиенты',
    singular: 'клиент',
    searchFields: const ['firstName', 'lastName', 'email'],
    sortFields: const {'name': 'lastName', 'city': 'city'},
    defaultSort: 'lastName',
    filters: const [
      FilterSpec(
        key: 'city',
        label: 'Город',
        kind: FilterKind.equalsText,
        field: 'city',
      ),
    ],
    columns: [
      ColumnSpec(
        'Фамилия и имя',
        (r, _) => '${r.str('lastName')} ${r.str('firstName')}',
        sortKey: 'name',
      ),
      ColumnSpec('Почта', (r, _) => r.str('email')),
      ColumnSpec('Телефон', (r, _) => r.str('phone')),
      ColumnSpec('Город', (r, _) => r.str('city'), sortKey: 'city'),
    ],
    formFields: [
      FieldSpec(
        name: 'firstName',
        label: 'Имя',
        kind: FieldKind.text,
        required: true,
        validators: [minLength(2), maxLength(50)],
      ),
      FieldSpec(
        name: 'lastName',
        label: 'Фамилия',
        kind: FieldKind.text,
        required: true,
        validators: [minLength(2), maxLength(50)],
      ),
      FieldSpec(
        name: 'email',
        label: 'Почта',
        kind: FieldKind.text,
        required: true,
        validators: [email()],
      ),
      FieldSpec(
        name: 'phone',
        label: 'Телефон',
        kind: FieldKind.text,
        required: true,
        validators: [phone()],
      ),
      FieldSpec(
        name: 'city',
        label: 'Город',
        kind: FieldKind.text,
        validators: [maxLength(60)],
      ),
    ],
  ),
  Section.loyaltyCards: CollectionSpec(
    section: Section.loyaltyCards,
    title: 'Карты лояльности',
    singular: 'карту',
    searchFields: const ['number'],
    sortFields: const {'number': 'number', 'bonus': 'bonusPoints'},
    defaultSort: 'number',
    filters: const [
      FilterSpec(
        key: 'level',
        label: 'Уровень',
        kind: FilterKind.select,
        field: 'level',
        options: cardLevels,
      ),
      FilterSpec(
        key: 'customer',
        label: 'Клиент',
        kind: FilterKind.relation,
        field: 'customer',
        relation: Section.customers,
      ),
    ],
    columns: [
      ColumnSpec('Номер', (r, _) => r.str('number'), sortKey: 'number'),
      ColumnSpec('Клиент', (r, l) => l(Section.customers, r.str('customer'))),
      ColumnSpec('Уровень', (r, _) => r.str('level')),
      ColumnSpec(
        'Бонусы',
        (r, _) => r.str('bonusPoints'),
        numeric: true,
        sortKey: 'bonus',
      ),
    ],
    formFields: [
      FieldSpec(
        name: 'customer',
        label: 'Клиент',
        kind: FieldKind.relation,
        required: true,
        relation: Section.customers,
      ),
      FieldSpec(
        name: 'number',
        label: 'Номер карты (8–16 цифр)',
        kind: FieldKind.text,
        required: true,
        validators: [
          pattern(RegExp(r'^[0-9]{8,16}$'), 'Только цифры, от 8 до 16'),
        ],
      ),
      FieldSpec(
        name: 'level',
        label: 'Уровень',
        kind: FieldKind.select,
        required: true,
        options: cardLevels,
      ),
      FieldSpec(
        name: 'bonusPoints',
        label: 'Бонусы',
        kind: FieldKind.number,
        validators: [intRange(0, 1000000)],
      ),
      FieldSpec(
        name: 'issuedAt',
        label: 'Выдана (ГГГГ-ММ-ДД)',
        kind: FieldKind.date,
        validators: [isoDate()],
      ),
    ],
  ),
  Section.orders: CollectionSpec(
    section: Section.orders,
    title: 'Заказы',
    singular: 'заказ',
    searchFields: const ['number'],
    sortFields: const {
      'number': 'number',
      'price': 'price',
      'created': 'created',
    },
    defaultSort: '-created',
    filters: const [
      FilterSpec(
        key: 'status',
        label: 'Статус',
        kind: FilterKind.select,
        field: 'status',
        options: orderStatuses,
      ),
      FilterSpec(
        key: 'customer',
        label: 'Клиент',
        kind: FilterKind.relation,
        field: 'customer',
        relation: Section.customers,
      ),
      FilterSpec(
        key: 'sneaker',
        label: 'Кроссовки',
        kind: FilterKind.relation,
        field: 'sneaker',
        relation: Section.sneakers,
      ),
    ],
    columns: [
      ColumnSpec('Номер', (r, _) => r.str('number'), sortKey: 'number'),
      ColumnSpec('Клиент', (r, l) => l(Section.customers, r.str('customer'))),
      ColumnSpec(
        'Кроссовки',
        (r, l) =>
            '${l(Section.sneakers, r.str('sneaker'))}, ${r.str('size')} р.',
      ),
      ColumnSpec(
        'Цена, ₽',
        (r, _) => r.str('price'),
        numeric: true,
        sortKey: 'price',
      ),
      ColumnSpec('Статус', (r, _) => r.str('status')),
    ],
    formFields: [
      FieldSpec(
        name: 'number',
        label: 'Номер заказа',
        kind: FieldKind.text,
        required: true,
        validators: [minLength(4), maxLength(20)],
      ),
      FieldSpec(
        name: 'customer',
        label: 'Клиент',
        kind: FieldKind.relation,
        required: true,
        relation: Section.customers,
      ),
      FieldSpec(
        name: 'sneaker',
        label: 'Кроссовки',
        kind: FieldKind.relation,
        required: true,
        relation: Section.sneakers,
      ),
      FieldSpec(
        name: 'size',
        label: 'Размер',
        kind: FieldKind.select,
        required: true,
        options: sizes,
      ),
      FieldSpec(
        name: 'quantity',
        label: 'Количество пар',
        kind: FieldKind.number,
        required: true,
        validators: [intRange(1, 20)],
      ),
      FieldSpec(
        name: 'status',
        label: 'Статус',
        kind: FieldKind.select,
        required: true,
        options: orderStatuses,
      ),
    ],
    quotePreview: true,
  ),
  Section.reviews: CollectionSpec(
    section: Section.reviews,
    title: 'Отзывы',
    singular: 'отзыв',
    searchFields: const ['text'],
    sortFields: const {'rating': 'rating', 'created': 'created'},
    defaultSort: '-created',
    filters: const [
      FilterSpec(
        key: 'sneaker',
        label: 'Кроссовки',
        kind: FilterKind.relation,
        field: 'sneaker',
        relation: Section.sneakers,
      ),
      FilterSpec(
        key: 'minRating',
        label: 'Оценка от',
        kind: FilterKind.minNumber,
        field: 'rating',
      ),
    ],
    columns: [
      ColumnSpec('Кроссовки', (r, l) => l(Section.sneakers, r.str('sneaker'))),
      ColumnSpec('Клиент', (r, l) => l(Section.customers, r.str('customer'))),
      ColumnSpec(
        'Оценка',
        (r, _) => r.str('rating'),
        numeric: true,
        sortKey: 'rating',
      ),
      ColumnSpec('Текст', (r, _) => r.str('text')),
    ],
    formFields: [
      FieldSpec(
        name: 'sneaker',
        label: 'Кроссовки',
        kind: FieldKind.relation,
        required: true,
        relation: Section.sneakers,
      ),
      FieldSpec(
        name: 'customer',
        label: 'Клиент',
        kind: FieldKind.relation,
        required: true,
        relation: Section.customers,
      ),
      FieldSpec(
        name: 'rating',
        label: 'Оценка (1–5)',
        kind: FieldKind.number,
        required: true,
        validators: [intRange(1, 5)],
      ),
      FieldSpec(
        name: 'text',
        label: 'Текст отзыва',
        kind: FieldKind.multiline,
        validators: [maxLength(1000)],
      ),
    ],
  ),
};

/// Подпись записи для списков выбора: название, иначе идентификатор.
String labelOf(Section section, PbRecord r) => switch (section) {
  Section.brands ||
  Section.categories ||
  Section.series ||
  Section.sneakers => r.str('name'),
  Section.promotions => r.str('title'),
  Section.customers => '${r.str('lastName')} ${r.str('firstName')}'.trim(),
  Section.loyaltyCards => r.str('number'),
  Section.orders => r.str('number'),
  Section.reviews => r.str('id'),
};
