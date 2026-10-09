import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/errors.dart';

import '../router.dart';
import '../state/auth_notifier.dart';

/// Экран отказа: адрес открыт, но раздел недоступен роли.
class ForbiddenScreen extends StatelessWidget {
  const ForbiddenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthNotifier>().role;
    return _InfoPage(
      icon: Icons.lock_outline,
      title: 'Доступ запрещён',
      text: 'Этот раздел недоступен роли «${role?.title ?? 'гость'}».',
      buttonText: 'На главную',
      onPressed: () => context.go(homeFor(role)),
    );
  }
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthNotifier>().role;
    return _InfoPage(
      icon: Icons.search_off,
      title: 'Страница не найдена',
      text: 'Такого адреса нет. Проверьте ссылку или вернитесь на главную.',
      buttonText: 'На главную',
      onPressed: () => context.go(homeFor(role)),
    );
  }
}

class _InfoPage extends StatelessWidget {
  const _InfoPage({
    required this.icon,
    required this.title,
    required this.text,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String text;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 56),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(text, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: onPressed, child: Text(buttonText)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Четыре состояния данных: загрузка, ошибка с повтором, пусто, данные.
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.loading,
    required this.error,
    required this.isEmpty,
    required this.onRetry,
    required this.child,
    this.emptyText = 'Ничего не найдено.',
    this.onReset,
  });

  final bool loading;
  final AppException? error;
  final bool isEmpty;
  final VoidCallback onRetry;
  final Widget child;
  final String emptyText;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return _Message(
        icon: Icons.cloud_off_outlined,
        text: error!.message,
        actionLabel: 'Повторить',
        onAction: onRetry,
      );
    }
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (isEmpty) {
      return _Message(
        icon: Icons.inbox_outlined,
        text: emptyText,
        actionLabel: onReset == null ? null : 'Сбросить условия',
        onAction: onReset,
      );
    }
    return child;
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
