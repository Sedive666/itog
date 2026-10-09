/// Точки перелома. Все числа лежат здесь; виджеты спрашивают `layoutOf(width)`.
enum Layout {
  /// до 600: одна колонка, карточки, нижняя панель.
  compact,

  /// 600–1023: боковая полоса со значками, карточки в две колонки.
  medium,

  /// 1024–1439: таблицы, боковая полоса с подписями.
  expanded,

  /// от 1440: то же, содержимое ограничено шириной.
  large;

  bool get showsTable => index >= Layout.expanded.index;
  bool get showsRail => index >= Layout.medium.index;
  int get cardColumns => this == Layout.compact ? 1 : 2;
}

const double compactMax = 600;
const double mediumMax = 1024;
const double expandedMax = 1440;
const double maxContentWidth = 1400;

Layout layoutOf(double width) {
  if (width < compactMax) return Layout.compact;
  if (width < mediumMax) return Layout.medium;
  if (width < expandedMax) return Layout.expanded;
  return Layout.large;
}
