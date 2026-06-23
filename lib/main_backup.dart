import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import 'pages/choferhome.dart';
import 'pages/comprashome.dart';
import 'pages/logged.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase solo en plataformas no-web
  if (!kIsWeb) {
    // ATENCIÓN: Debes reemplazar estos valores con los de tu proyecto de Supabase
    await Supabase.initialize(
      url: 'https://suwcqdlxnmfcvmlnzizl.supabase.co',
      anonKey: 'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
    );
  }

  runApp(const MyApp());
}

final _router = GoRouter(
  initialLocation: '/choferHome',
  routes: [
    GoRoute(
      path: '/choferHome',
      name: 'ChoferHome',
      builder: (context, state) => const ChoferHomeWidget(),
    ),
    GoRoute(
      path: '/comprasHome',
      name: 'ComprasHome',
      builder: (context, state) => const ComprasHomeWidget(),
    ),
    GoRoute(
      path: '/logged',
      name: 'Logged',
      builder: (context, state) => const LoggedWidget(),
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Geo Logistica',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A5D23)),
        useMaterial3: true,
      ),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
