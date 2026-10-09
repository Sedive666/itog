import 'package:go_router/go_router.dart';

import 'core/permissions.dart';
import 'state/auth_notifier.dart';
import 'ui/form_screen.dart';
import 'ui/list_screen.dart';
import 'ui/login_screen.dart';
import 'ui/register_screen.dart';
import 'ui/stats_screen.dart';
import 'ui/status_pages.dart';

/// Главный раздел роли: куда попадает пользователь с «/».
String homeFor(Role? role) => switch (role) {
  Role.admin => '/stats',
  Role.manager => '/orders',
  Role.client => '/sneakers',
  null => '/login',
};

/// Правила доступа к адресам. Единственная точка, где решается, куда пустить пользователя.
/// Недоступный раздел ведёт на экран отказа, неизвестный адрес — на 404.
String? guardRedirect({required Role? role, required Uri uri}) {
  final path = uri.path;
  final segments = uri.pathSegments;

  if (role == null) {
    if (publicPaths.contains(path)) return null;
    return path == '/'
        ? '/login'
        : '/login?from=${Uri.encodeComponent(uri.toString())}';
  }
  if (publicPaths.contains(path)) return homeFor(role);
  if (path == '/' || path.isEmpty) return homeFor(role);
  if (path == '/forbidden' || path == '/not-found') return null;

  if (segments.first == 'stats') {
    return segments.length == 1 && canSeeStats(role) ? null : '/forbidden';
  }

  final section = Section.fromPath('/${segments.first}');
  if (section == null) return '/not-found';

  if (segments.length == 1) {
    return can(role, section, Op.read) ? null : '/forbidden';
  }
  if (segments.length == 2 && segments[1] == 'new') {
    return can(role, section, Op.create) ? null : '/forbidden';
  }
  if (segments.length == 3 && segments[2] == 'edit') {
    return can(role, section, Op.edit) ? null : '/forbidden';
  }
  return '/not-found';
}

Section _sectionOf(String segment) =>
    Section.fromPath('/$segment') ?? Section.sneakers;

GoRouter createRouter(AuthNotifier auth, {String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: auth,
    redirect: (context, state) =>
        guardRedirect(role: auth.role, uri: state.uri),
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            LoginScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(path: '/stats', builder: (context, state) => const StatsScreen()),
      GoRoute(
        path: '/forbidden',
        builder: (context, state) => const ForbiddenScreen(),
      ),
      GoRoute(
        path: '/not-found',
        builder: (context, state) => const NotFoundScreen(),
      ),
      GoRoute(
        path: '/:section',
        builder: (context, state) => ListScreen(
          section: _sectionOf(state.pathParameters['section']!),
          params: state.uri.queryParameters,
        ),
      ),
      GoRoute(
        path: '/:section/new',
        builder: (context, state) =>
            FormScreen(section: _sectionOf(state.pathParameters['section']!)),
      ),
      GoRoute(
        path: '/:section/:id/edit',
        builder: (context, state) => FormScreen(
          section: _sectionOf(state.pathParameters['section']!),
          id: state.pathParameters['id'],
        ),
      ),
    ],
    errorBuilder: (context, state) => const NotFoundScreen(),
  );
}
