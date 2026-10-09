import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/errors.dart';
import '../core/permissions.dart';
import '../data/auth_api.dart';
import '../models/record.dart';

/// Сессия пользователя. Хранится в shared_preferences, поэтому переживает перезагрузку страницы.
class AuthNotifier extends ChangeNotifier implements SessionTokens {
  AuthNotifier(this._prefs, this._api, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SharedPreferences _prefs;
  final AuthApi _api;
  final DateTime Function() _clock;

  static const _kToken = 'auth_token';
  static const _kUser = 'auth_user';
  static const _kLoginAt = 'auth_login_at';

  String? _token;
  PbRecord? _user;
  DateTime? _loginAt;
  String? _endReason;
  Future<bool>? _refreshing;

  @override
  String? get accessToken => _token;

  PbRecord? get user => _user;
  Role? get role => Role.parse(_user?.str('role'));
  bool get isSignedIn => _token != null && _user != null;
  String? get endReason => _endReason;

  /// Момент окончания сессии: вход + максимальная длительность.
  DateTime? get sessionEndsAt => _loginAt?.add(sessionMaxDuration);

  /// Восстановление после перезагрузки. Истёкшую сессию сбрасывает, остальные проверяет на сервере.
  Future<void> restore() async {
    final token = _prefs.getString(_kToken);
    final userJson = _prefs.getString(_kUser);
    final loginAt = DateTime.tryParse(_prefs.getString(_kLoginAt) ?? '');
    if (token == null || userJson == null) return;

    if (loginAt == null || _clock().difference(loginAt) >= sessionMaxDuration) {
      await _clear('Сессия завершена: истёк максимальный срок работы');
      return;
    }

    _token = token;
    _loginAt = loginAt;
    try {
      _user = PbRecord.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    } on Object {
      await _clear(null);
      return;
    }
    try {
      final fresh = await _api.refresh();
      await _save(fresh.token, fresh.user, loginAt: loginAt);
    } on UnauthorizedException {
      await _clear('Сессия истекла. Войдите снова.');
    } on AppException {
      // Сервера нет: остаёмся в сессии, список покажет ошибку сети.
    }
    notifyListeners();
  }

  Future<void> login(String identity, String password) async {
    final result = await _api.login(identity, password);
    _endReason = null;
    await _save(result.token, result.user, loginAt: _clock());
    notifyListeners();
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    await _api.register(
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      password: password,
    );
    await login(email, password);
  }

  Future<void> logout({String? reason}) => _clear(reason);

  /// Вход без сети: только для тестов интерфейса.
  @visibleForTesting
  void debugSignIn(PbRecord user, {String token = 'test-token'}) {
    _token = token;
    _user = user;
    _loginAt = _clock();
    notifyListeners();
  }

  /// Автоматическое обновление токена при 401. Параллельные запросы ждут одно обновление.
  @override
  Future<bool> refreshSession() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    try {
      final fresh = await _api.refresh();
      await _save(fresh.token, fresh.user, loginAt: _loginAt);
      return true;
    } on UnauthorizedException {
      await _clear('Сессия истекла. Войдите снова.');
      return false;
    } on AppException {
      return false;
    }
  }

  Future<void> _save(String token, PbRecord user, {DateTime? loginAt}) async {
    _token = token;
    _user = user;
    _loginAt = loginAt ?? _loginAt ?? _clock();
    await _prefs.setString(_kToken, token);
    await _prefs.setString(_kUser, jsonEncode(user.data));
    await _prefs.setString(_kLoginAt, _loginAt!.toIso8601String());
    notifyListeners();
  }

  Future<void> _clear(String? reason) async {
    _token = null;
    _user = null;
    _loginAt = null;
    _endReason = reason;
    await _prefs.remove(_kToken);
    await _prefs.remove(_kUser);
    await _prefs.remove(_kLoginAt);
    notifyListeners();
  }
}
