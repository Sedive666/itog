import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'data/records_api.dart';
import 'router.dart';
import 'state/auth_notifier.dart';
import 'state/lookups.dart';

/// Корень приложения: провайдеры состояния, тема и маршрутизатор.
class ShoeStoreApp extends StatefulWidget {
  const ShoeStoreApp({
    super.key,
    required this.auth,
    required this.api,
    this.initialLocation = '/',
  });

  final AuthNotifier auth;
  final RecordsApi api;
  final String initialLocation;

  @override
  State<ShoeStoreApp> createState() => _ShoeStoreAppState();
}

class _ShoeStoreAppState extends State<ShoeStoreApp> {
  late final _router = createRouter(
    widget.auth,
    initialLocation: widget.initialLocation,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final providers = <SingleChildWidget>[
      ChangeNotifierProvider<AuthNotifier>.value(value: widget.auth),
      Provider<RecordsApi>.value(value: widget.api),
      ChangeNotifierProxyProvider<AuthNotifier, Lookups>(
        create: (_) => Lookups(widget.api),
        update: (_, auth, previous) => previous!..bindUser(auth.user?.id),
      ),
    ];
    return MultiProvider(
      providers: providers,
      child: MaterialApp.router(
        title: 'Магазин кроссовок',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
          useMaterial3: true,
          inputDecorationTheme: const InputDecorationTheme(isDense: false),
        ),
        routerConfig: _router,
      ),
    );
  }
}
