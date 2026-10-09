import 'record.dart';

/// Страница списка из ответа PocketBase: {page, perPage, totalItems, totalPages, items}.
class PageResult {
  const PageResult({
    required this.items,
    required this.page,
    required this.perPage,
    required this.totalItems,
    required this.totalPages,
  });

  factory PageResult.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = raw is List
        ? raw.whereType<Map<String, dynamic>>().map(PbRecord.fromJson).toList()
        : <PbRecord>[];
    return PageResult(
      items: items,
      page: _int(json['page'], 1),
      perPage: _int(json['perPage'], items.length),
      totalItems: _int(json['totalItems'], items.length),
      totalPages: _int(json['totalPages'], 1),
    );
  }

  factory PageResult.empty(int perPage) => PageResult(
    items: const [],
    page: 1,
    perPage: perPage,
    totalItems: 0,
    totalPages: 1,
  );

  final List<PbRecord> items;
  final int page;
  final int perPage;
  final int totalItems;
  final int totalPages;

  bool get hasPrevious => page > 1;
  bool get hasNext => page < totalPages;

  static int _int(Object? v, int fallback) => v is num ? v.toInt() : fallback;
}
