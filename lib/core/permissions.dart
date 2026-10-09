/// Роли и права. Все разрешения записаны в одной таблице: по ней проверяются
/// маршруты, пункты меню и кнопки. Права ролей разные, не вложенные.
enum Role {
  client('Покупатель'),
  manager('Менеджер'),
  admin('Администратор');

  const Role(this.title);
  final String title;

  static Role? parse(String? value) {
    for (final r in Role.values) {
      if (r.name == value) return r;
    }
    return null;
  }
}

/// Разделы приложения; имя совпадает с коллекцией PocketBase.
enum Section {
  sneakers,
  brands,
  series,
  categories,
  promotions,
  customers,
  loyaltyCards,
  orders,
  reviews;

  /// Имя коллекции в PocketBase.
  String get collection => switch (this) {
    Section.loyaltyCards => 'loyalty_cards',
    _ => name,
  };

  static Section? fromPath(String path) {
    for (final s in Section.values) {
      if (path == '/${s.name}' || path == '/${_kebab(s)}') return s;
    }
    return null;
  }

  static String _kebab(Section s) => switch (s) {
    Section.loyaltyCards => 'loyalty-cards',
    _ => s.name,
  };

  /// Путь раздела в адресной строке.
  String get path => '/${_kebab(this)}';
}

/// Операции над записями и служебные права.
enum Op {
  read,
  create,
  edit,
  softDelete,
  bulkDelete,
  restore,
  hardDelete,
  viewDeleted,
  stats,
  export,
}

/// Что может каждая роль в каждом разделе.
const Map<Role, Map<Section, Set<Op>>> _matrix = {
  Role.client: {
    Section.sneakers: {Op.read},
    Section.brands: {Op.read},
    Section.series: {Op.read},
    Section.categories: {Op.read},
    Section.orders: {Op.read},
    Section.loyaltyCards: {Op.read},
    Section.reviews: {Op.read, Op.create},
  },
  Role.manager: {
    Section.sneakers: {
      Op.read,
      Op.create,
      Op.edit,
      Op.softDelete,
      Op.bulkDelete,
      Op.export,
    },
    Section.brands: {
      Op.read,
      Op.create,
      Op.edit,
      Op.softDelete,
      Op.bulkDelete,
      Op.export,
    },
    Section.series: {
      Op.read,
      Op.create,
      Op.edit,
      Op.softDelete,
      Op.bulkDelete,
      Op.export,
    },
    Section.categories: {
      Op.read,
      Op.create,
      Op.edit,
      Op.softDelete,
      Op.bulkDelete,
      Op.export,
    },
    Section.promotions: {
      Op.read,
      Op.create,
      Op.edit,
      Op.softDelete,
      Op.bulkDelete,
      Op.export,
    },
    Section.customers: {
      Op.read,
      Op.create,
      Op.edit,
      Op.softDelete,
      Op.bulkDelete,
      Op.export,
    },
    Section.loyaltyCards: {
      Op.read,
      Op.create,
      Op.edit,
      Op.softDelete,
      Op.bulkDelete,
    },
    Section.orders: {
      Op.read,
      Op.create,
      Op.edit,
      Op.softDelete,
      Op.bulkDelete,
      Op.export,
    },
    Section.reviews: {Op.read, Op.export},
  },
  Role.admin: {
    Section.sneakers: {
      Op.read,
      Op.restore,
      Op.hardDelete,
      Op.viewDeleted,
      Op.export,
    },
    Section.brands: {
      Op.read,
      Op.restore,
      Op.hardDelete,
      Op.viewDeleted,
      Op.export,
    },
    Section.series: {
      Op.read,
      Op.restore,
      Op.hardDelete,
      Op.viewDeleted,
      Op.export,
    },
    Section.categories: {
      Op.read,
      Op.restore,
      Op.hardDelete,
      Op.viewDeleted,
      Op.export,
    },
    Section.promotions: {
      Op.read,
      Op.restore,
      Op.hardDelete,
      Op.viewDeleted,
      Op.export,
    },
    Section.customers: {
      Op.read,
      Op.restore,
      Op.hardDelete,
      Op.viewDeleted,
      Op.export,
    },
    Section.loyaltyCards: {Op.read, Op.restore, Op.hardDelete, Op.viewDeleted},
    Section.orders: {
      Op.read,
      Op.restore,
      Op.hardDelete,
      Op.viewDeleted,
      Op.export,
    },
    Section.reviews: {
      Op.read,
      Op.restore,
      Op.hardDelete,
      Op.viewDeleted,
      Op.export,
    },
  },
};

/// Разделы, видимые роли (для меню и проверки маршрута).
Iterable<Section> sectionsOf(Role? role) =>
    role == null ? const [] : _matrix[role]!.keys;

bool can(Role? role, Section section, Op op) {
  if (role == null) return false;
  return _matrix[role]?[section]?.contains(op) ?? false;
}

/// Отдельная статистика: сводка доступна менеджеру и администратору.
bool canSeeStats(Role? role) => role == Role.manager || role == Role.admin;

/// Публичные адреса, доступные без входа.
const publicPaths = {'/login', '/register'};
