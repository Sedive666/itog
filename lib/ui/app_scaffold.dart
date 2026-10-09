import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../core/permissions.dart';
import '../data/catalog.dart';
import '../state/auth_notifier.dart';

class NavItem {
  const NavItem(this.path, this.label, this.icon);
  final String path;
  final String label;
  final IconData icon;
}

const _icons = <Section, IconData>{
  Section.sneakers: Icons.directions_run,
  Section.brands: Icons.sell_outlined,
  Section.series: Icons.layers_outlined,
  Section.categories: Icons.category_outlined,
  Section.promotions: Icons.local_offer_outlined,
  Section.customers: Icons.people_outline,
  Section.loyaltyCards: Icons.card_membership_outlined,
  Section.orders: Icons.receipt_long_outlined,
  Section.reviews: Icons.rate_review_outlined,
};

/// Пункты меню только для разделов, доступных роли.
List<NavItem> navItemsFor(Role? role) {
  final items = <NavItem>[];
  for (final s in Section.values) {
    if (!sectionsOf(role).contains(s)) continue;
    items.add(NavItem(s.path, catalog[s]!.title, _icons[s]!));
  }
  if (canSeeStats(role)) {
    items.add(const NavItem('/stats', 'Отчёт', Icons.bar_chart));
  }
  return items;
}

/// Общая оболочка: меню по роли, адаптивная навигация, имя пользователя и выход.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
  });

  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final items = navItemsFor(auth.role);
    final location = GoRouterState.of(context).uri.path;
    final layout = layoutOf(MediaQuery.sizeOf(context).width);
    final selected = items.indexWhere((i) => location.startsWith(i.path));
    final userName = auth.user?.str('lastName') ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...actions,
          // На узком экране имя уходит в подсказку кнопки выхода, иначе не хватает места.
          if (layout != Layout.compact)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    '${auth.role?.title ?? ''}${userName.isEmpty ? '' : ', $userName'}',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: layout == Layout.compact
                ? 'Выйти (${auth.role?.title ?? ''}${userName.isEmpty ? '' : ', $userName'})'
                : 'Выйти',
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: Row(
        children: [
          if (layout.showsRail)
            NavigationRail(
              extended: layout.index >= Layout.expanded.index,
              selectedIndex: selected < 0 ? null : selected,
              labelType: layout.index >= Layout.expanded.index
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              onDestinationSelected: (i) => context.go(items[i].path),
              destinations: [
                for (final i in items)
                  NavigationRailDestination(
                    icon: Icon(i.icon),
                    label: Text(i.label),
                  ),
              ],
            ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: layout == Layout.large
                      ? maxContentWidth
                      : double.infinity,
                ),
                child: body,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: layout.showsRail
          ? null
          : _BottomNav(items: items, selected: selected),
    );
  }
}

/// Нижняя панель на узком экране: первые четыре раздела и «Ещё» со всем остальным.
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.items, required this.selected});

  final List<NavItem> items;
  final int selected;

  static const _slots = 4;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final overflow = items.length > _slots + 1;
    final visible = overflow ? items.take(_slots).toList() : items;
    final selectedInVisible = selected >= 0 && selected < visible.length;

    return NavigationBar(
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      selectedIndex: selectedInVisible
          ? selected
          : (overflow ? visible.length : 0),
      onDestinationSelected: (i) {
        if (overflow && i == visible.length) {
          _showMore(context);
        } else {
          context.go(visible[i].path);
        }
      },
      destinations: [
        for (final i in visible)
          NavigationDestination(icon: Icon(i.icon), label: i.label),
        if (overflow)
          const NavigationDestination(
            icon: Icon(Icons.more_horiz),
            label: 'Ещё',
          ),
      ],
    );
  }

  void _showMore(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final i in items)
              ListTile(
                leading: Icon(i.icon),
                title: Text(i.label),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.go(i.path);
                },
              ),
          ],
        ),
      ),
    );
  }
}
