import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'data/auth_api.dart';
import 'data/records_api.dart';
import 'state/auth_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Адреса без решётки: фильтры и страницы живут в обычном адресе, по ним можно поделиться ссылкой.
  usePathUrlStrategy();

  final prefs = await SharedPreferences.getInstance();
  // Клиент зависит от сессии, а сессия — от клиента; поэтому клиент берём через функцию.
  late final Dio dio;
  final auth = AuthNotifier(prefs, AuthApi(() => dio));
  dio = buildApiDio(auth);

  await auth.restore();
  runApp(ShoeStoreApp(auth: auth, api: PocketBaseApi(dio)));
}
