import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/errors.dart';
import '../models/validators.dart';
import '../router.dart';
import '../state/auth_notifier.dart';

/// Регистрация покупателя. Роль «клиент» и карточку покупателя назначает сервер.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

final _passwordRule = pattern(
  RegExp(r'^(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$'),
  'Не короче 8 знаков, с цифрой и спецсимволом',
);

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _formError;

  /// Ошибки 422 от сервера по именам полей.
  Map<String, String> _serverErrors = {};

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _formError = null;
      _serverErrors = {};
    });
    final auth = context.read<AuthNotifier>();
    try {
      await auth.register(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      context.go(homeFor(auth.role));
    } on ValidationException catch (e) {
      setState(() {
        _serverErrors = e.errors;
        _formError = e.message;
      });
    } on AppException catch (e) {
      setState(() => _formError = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Текст ошибки поля: сначала от сервера, потом проверка на клиенте.
  String? Function(String?) _check(
    String field,
    String? Function(String?) rule,
  ) {
    return (value) => _serverErrors[field] ?? rule(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _field(
                    _first,
                    'firstName',
                    'Имя',
                    combine([
                      requiredField('Введите имя'),
                      minLength(2),
                      maxLength(50),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _field(
                    _last,
                    'lastName',
                    'Фамилия',
                    combine([
                      requiredField('Введите фамилию'),
                      minLength(2),
                      maxLength(50),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _field(
                    _email,
                    'email',
                    'Почта',
                    combine([requiredField('Введите почту'), email()]),
                    keyboard: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    _phone,
                    'phone',
                    'Телефон',
                    combine([requiredField('Введите телефон'), phone()]),
                    keyboard: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    _password,
                    'password',
                    'Пароль',
                    combine([requiredField('Введите пароль'), _passwordRule]),
                    obscure: true,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirm,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Повторите пароль',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v != _password.text ? 'Пароли не совпадают' : null,
                  ),
                  if (_formError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _formError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Зарегистрироваться'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Уже есть аккаунт? Войти'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String name,
    String label,
    String? Function(String?) rule, {
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    return TextFormField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: _check(name, rule),
    );
  }
}
