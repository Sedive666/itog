import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/errors.dart';
import '../data/records_api.dart';
import 'app_scaffold.dart';
import 'status_pages.dart';

/// Сводный отчёт: выручка, заказы по статусам, выручка по брендам (диаграмма), мало на складе.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<RecordsApi>().statsSummary();
  }

  void _load() {
    setState(() => _future = context.read<RecordsApi>().statsSummary());
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Отчёт',
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final e = snap.error;
            return StateView(
              loading: false,
              error: e is AppException ? e : const ServerException(),
              isEmpty: false,
              onRetry: _load,
              child: const SizedBox.shrink(),
            );
          }
          final data = snap.data ?? const {};
          final ordersTotal = (data['ordersTotal'] as num?)?.toInt() ?? 0;
          if (ordersTotal == 0) {
            return StateView(
              loading: false,
              error: null,
              isEmpty: true,
              emptyText:
                  'Заказов пока нет: отчёт появится после первой продажи.',
              onRetry: _load,
              child: const SizedBox.shrink(),
            );
          }
          return _Report(data: data, onRefresh: _load);
        },
      ),
    );
  }
}

class _Report extends StatelessWidget {
  const _Report({required this.data, required this.onRefresh});

  final Map<String, dynamic> data;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final brands = [
      for (final b in (data['byBrand'] as List? ?? const []))
        (
          name: '${(b as Map)['brand']}',
          revenue: ((b)['revenue'] as num?)?.toDouble() ?? 0,
        ),
    ];
    final statuses = [
      for (final s in (data['byStatus'] as List? ?? const []))
        (
          status: '${(s as Map)['status']}',
          count: ((s)['count'] as num?)?.toInt() ?? 0,
        ),
    ];
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Tile(label: 'Выручка, ₽', value: _money(data['revenue'])),
            _Tile(label: 'Заказов всего', value: '${data['ordersTotal'] ?? 0}'),
            _Tile(
              label: 'Без отменённых',
              value: '${data['ordersActive'] ?? 0}',
            ),
            _Tile(
              label: 'Мало на складе',
              value: '${data['lowStock'] ?? 0}',
              hint: 'не больше 2 пар',
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Выручка по брендам', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 240,
          child: brands.isEmpty
              ? const Center(child: Text('Нет данных'))
              : CustomPaint(
                  painter: _BarChartPainter(
                    bars: [
                      for (final b in brands) (label: b.name, value: b.revenue),
                    ],
                    barColor: theme.colorScheme.primary,
                    textColor: theme.colorScheme.onSurface,
                  ),
                  size: Size.infinite,
                ),
        ),
        const SizedBox(height: 24),
        Text('Заказы по статусам', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final s in statuses)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(s.status),
            trailing: Text('${s.count}'),
          ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Обновить'),
          ),
        ),
      ],
    );
  }

  static String _money(Object? v) {
    final n = (v as num?)?.toInt() ?? 0;
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              if (hint != null)
                Text(hint!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Столбчатая диаграмма без внешних пакетов: подписи снизу, значения сверху.
class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.bars,
    required this.barColor,
    required this.textColor,
  });

  final List<({String label, double value})> bars;
  final Color barColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final maxValue = bars
        .map((b) => b.value)
        .fold<double>(0, (a, b) => b > a ? b : a);
    const labelHeight = 40.0;
    const topPad = 20.0;
    final chartHeight = size.height - labelHeight - topPad;
    final slot = size.width / bars.length;
    final barWidth = (slot * 0.5).clamp(12.0, 80.0);
    final paint = Paint()..color = barColor;

    for (var i = 0; i < bars.length; i++) {
      final b = bars[i];
      final h = maxValue == 0 ? 0.0 : chartHeight * (b.value / maxValue);
      final x = slot * i + (slot - barWidth) / 2;
      final top = topPad + chartHeight - h;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, barWidth, h),
          const Radius.circular(4),
        ),
        paint,
      );
      _text(
        canvas,
        '${b.value.round()}',
        Offset(slot * i, top - 16),
        slot,
        textColor,
        11,
      );
      _text(
        canvas,
        b.label,
        Offset(slot * i, topPad + chartHeight + 6),
        slot,
        textColor,
        11,
        maxLines: 2,
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    double width,
    Color color,
    double size, {
    int maxLines = 1,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: width);
    tp.paint(canvas, Offset(at.dx + (width - tp.width) / 2, at.dy));
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.bars != bars || old.barColor != barColor;
}
