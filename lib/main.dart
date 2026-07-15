import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'pages/recolecciones_page.dart';
import 'pages/pesajes_page.dart';
import 'pages/distribuciones_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'pages/vehiculo_detalle_page.dart';
import 'pages/productos_page.dart';
import 'pages/vehiculos_page.dart';
import 'pages/necesidades_page.dart';
import 'pages/rutas_page.dart';
import 'pages/viajes_page.dart';
import 'pages/viaje_detalle.dart';
import 'pages/ruta_detalle.dart';
import 'pages/paradadetalle.dart';
import 'pages/pesajesitem.dart';
import 'pages/remito_page.dart';
import 'pages/homepage.dart';
import 'pages/choferhome.dart';
import 'pages/gerentehome.dart';
import 'pages/welcomepage.dart';
import 'pages/login.dart';
import 'pages/logged.dart';
import 'pages/comprashome.dart';
import 'pages/depositohome.dart';
import 'pages/planificar_viaje.dart';
import 'pages/apicultores_page.dart';
import 'pages/gastos_page.dart';
import 'pages/remitos_lista_page.dart';
import 'pages/agregar_pesaje.dart';
import 'pages/cargas_page.dart';
import 'pages/carga_detalle.dart';
import 'pages/remito_carga_page.dart';
import 'pages/reportes_page.dart';
import 'pages/trazabilidad_page.dart';
import 'pages/configuracion_page.dart';
import 'pages/perfil_usuario.dart';

// Completer global para que WelcomePage pueda esperar a que Supabase esté listo
import 'dart:async';

final Completer<void> supabaseReady = Completer<void>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Verificación de sesión persistente (Mantener sesión activa)
  try {
    final prefs = await SharedPreferences.getInstance();
    final keep = prefs.getBool('keep_session') ?? false;
    if (!keep) {
      await prefs.remove('user_id');
      await prefs.remove('user_email');
      await prefs.remove('user_nombre');
      await prefs.remove('user_apellido');
      await prefs.remove('user_puesto');
      print('Main: keep_session es falso o nulo. Sesión temporal limpia al inicio.');
    } else {
      print('Main: keep_session es verdadero. Conservando sesión activa.');
    }
  } catch (e) {
    print('Main: Error al verificar keep_session en inicio: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  // Inicializar Hive
  try {
    if (kIsWeb) {
      Hive.init('');
    } else {
      final dir = await getApplicationDocumentsDirectory();
      Hive.init(dir.path);
    }
    await Hive.openBox('viajes_cache');
    await Hive.openBox('apicultores_cache');
    await Hive.openBox('productos_cache');
    await Hive.openBox('pesajes_cache');
    await Hive.openBox('sync_queue');
    await Hive.openBox('sync_errors');
    print('Main: Hive inicializado correctamente');
  } catch (e) {
    print('Main: Error al inicializar Hive: $e');
  }

  // Lanzar la app inmediatamente para que el splash se vea al instante
  runApp(const MyApp());

  // Inicializar Supabase en paralelo (no bloquea el hilo de UI)
  Future(() async {
    try {
      const String supabaseUrl = String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://suwcqdlxnmfcvmlnzizl.supabase.co',
      );
      const String supabaseAnonKey = String.fromEnvironment(
        'SUPABASE_KEY',
        defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
      );

      print('Main: Inicializando Supabase...');
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      print('Main: Supabase OK');

      // Locale en segundo plano
      initializeDateFormatting('es_AR', null);

      supabaseReady.complete();
    } catch (e) {
      print('Main: Error en inicialización: $e');
      supabaseReady.complete();
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GeoLogística',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'AR'),
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      locale: const Locale('es', 'AR'),
      theme: ThemeData(
        fontFamily: 'Inter',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: FadePageTransitionsBuilder(),
            TargetPlatform.iOS: FadePageTransitionsBuilder(),
            TargetPlatform.windows: FadePageTransitionsBuilder(),
            TargetPlatform.macOS: FadePageTransitionsBuilder(),
            TargetPlatform.linux: FadePageTransitionsBuilder(),
          },
        ),
      ),
    );
  }
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'WelcomePage',
      builder: (context, state) => const WelcomePageWidget(),
    ),
    GoRoute(
      path: '/login',
      name: 'Login',
      builder: (context, state) => const LoginWidget(),
    ),
    GoRoute(
      path: '/logged',
      name: 'Logged',
      builder: (context, state) => const LoggedWidget(),
    ),
    GoRoute(
      path: '/home',
      name: 'HomePage',
      builder: (context, state) => const HomePageWidget(),
    ),
    GoRoute(
      path: '/choferHome',
      name: 'choferHome',
      builder: (context, state) => const ChoferHomeWidget(),
    ),
    GoRoute(
      path: '/gerenteHome',
      name: 'gerenteHome',
      builder: (context, state) => const GerenteHomeWidget(),
    ),
    GoRoute(
      path: '/comprasHome',
      name: 'comprasHome',
      builder: (context, state) => const ComprasHomeWidget(),
    ),
    GoRoute(
      path: '/depositoHome',
      name: 'depositoHomePage',
      builder: (context, state) => DepositohomeWidget(
        initialTab: state.uri.queryParameters['tab'],
      ),
    ),
    GoRoute(
      path: '/necesidades',
      name: 'NecesidadesPage',
      builder: (context, state) => const NecesidadesPageWidget(),
    ),
    GoRoute(
      path: '/planificarViaje',
      name: 'PlanificarViaje',
      builder: (context, state) {
        final editId = state.uri.queryParameters['editId'];
        return PlanificarViajeWidget(editId: editId);
      },
    ),
    GoRoute(
      path: '/viajedetalle',
      name: 'ViajeDetalle',
      builder: (context, state) {
        final viajeId = state.uri.queryParameters['viajeId'] ?? '';
        return ViajeDetalleWidget(viajeId: viajeId);
      },
    ),
    GoRoute(
      path: '/rutadetalle',
      name: 'RutaDetalle',
      builder: (context, state) {
        final viajeId = state.uri.queryParameters['viajeId'] ?? '';
        return RutaDetalleWidget(viajeId: viajeId);
      },
    ),
    GoRoute(
      path: '/paradaDetalle',
      name: 'paradaDetalle',
      builder: (context, state) {
        final paradaId = state.uri.queryParameters['paradaId'] ?? '';
        return ParadaDetalleWidget(paradaId: paradaId);
      },
    ),
    GoRoute(
      path: '/pesajes',
      name: 'Pesajes',
      builder: (context, state) => const PesajesPageWidget(),
    ),
    GoRoute(
      path: '/pesajesItem',
      name: 'pesajesItem',
      builder: (context, state) {
        final paradaId = state.uri.queryParameters['paradaId'] ?? '';
        final paradaItemId = state.uri.queryParameters['paradaItemId'];
        return PesajesItemWidget(paradaId: paradaId, paradaItemId: paradaItemId);
      },
    ),
    GoRoute(
      path: '/remito',
      name: 'RemitoPage',
      builder: (context, state) {
        final params = state.uri.queryParameters;
        return RemitoPageWidget(
          paradaId: params['paradaId'] ?? '',
          receptorTipo: params['receptorTipo'],
          receptorNombre: params['receptorNombre'],
          receptorDni: params['receptorDni'],
        );
      },
    ),
    GoRoute(
      path: '/rutas',
      name: 'rutasPage',
      builder: (context, state) => const RutasPageWidget(),
    ),
    GoRoute(
      name: ViajesPageWidget.routeName,
      path: ViajesPageWidget.routePath,
      builder: (context, state) => ViajesPageWidget(
        initialEstado: state.uri.queryParameters['estado'],
      ),
    ),
    GoRoute(
      path: '/recolecciones',
      name: 'recoleccionesPage',
      builder: (context, state) => const RecoleccionesPageWidget(),
    ),
    GoRoute(
      path: '/distribuciones',
      name: 'distribucionesPage',
      builder: (context, state) => const DistribucionesPageWidget(),
    ),
    GoRoute(
      path: '/vehiculos',
      name: 'VehiculosPage',
      builder: (context, state) => const VehiculosPageWidget(),
    ),
    GoRoute(
      path: '/vehiculoDetalle',
      name: 'VehiculoDetalle',
      builder: (context, state) {
        final vehiculoId = state.uri.queryParameters['id'];
        return VehiculoDetalleWidget(vehiculoId: vehiculoId);
      },
    ),
    GoRoute(
      path: '/productos',
      name: 'ProductosPage',
      builder: (context, state) => const ProductosPageWidget(),
    ),
    GoRoute(
      path: '/apicultores',
      name: 'ApicultoresPage',
      builder: (context, state) => const ApicultoresPageWidget(),
    ),
    GoRoute(
      path: '/gastos',
      name: 'GastosPage',
      builder: (context, state) => const GastosPageWidget(),
    ),
    GoRoute(
      path: '/remitosLista',
      name: 'RemitosListaPage',
      builder: (context, state) => const RemitosListaPageWidget(),
    ),
    GoRoute(
      path: '/agregarPesaje',
      name: 'AgregarPesaje',
      builder: (context, state) {
        // Acepta params por extra (desde context.push) o por queryParameters (URL directa)
        final extra = state.extra as Map<String, dynamic>?;
        final params = state.uri.queryParameters;
        return AgregarPesajeWidget(
          paradaId: extra?['paradaId']?.toString() ?? params['paradaId'] ?? '',
          viajeId: extra?['viajeId']?.toString() ?? params['viajeId'],
          viajeCode: extra?['viajeCode']?.toString() ?? params['viajeCode'] ?? 'V-S/N',
          apicultorNombre: extra?['apicultorNombre']?.toString() ?? params['apicultorNombre'] ?? 'S/D',
          localidad: extra?['localidad']?.toString() ?? params['localidad'] ?? 'S/D',
          apicultorId: extra?['apicultorId']?.toString() ?? params['apicultorId'],
        );
      },
    ),
    GoRoute(
      path: '/cargas',
      name: 'CargasPage',
      builder: (context, state) => const CargasPageWidget(),
    ),
    GoRoute(
      path: '/cargaDetalle',
      name: 'CargaDetalle',
      builder: (context, state) {
        final id = state.uri.queryParameters['id'];
        final isNew = state.uri.queryParameters['new'] == 'true';
        return CargaDetalleWidget(cargaId: id, isNew: isNew);
      },
    ),
    GoRoute(
      path: '/remito_carga',
      name: 'RemitoCargaPage',
      builder: (context, state) {
        final cargaId = state.uri.queryParameters['cargaId'] ?? '';
        return RemitoCargaPageWidget(cargaId: cargaId);
      },
    ),
    GoRoute(
      path: '/reportes',
      name: 'ReportesPage',
      builder: (context, state) => const ReportesPage(),
    ),
    GoRoute(
      path: '/trazabilidad',
      name: 'TrazabilidadPage',
      builder: (context, state) => const TrazabilidadPage(),
    ),
    GoRoute(
      path: '/configuracion',
      name: 'ConfiguracionPage',
      builder: (context, state) => const ConfiguracionPage(),
    ),
    GoRoute(
      path: '/perfil',
      name: 'choferHome',
      builder: (context, state) => const ChoferHomeWidget(),
    ),
    GoRoute(
      path: '/gerenteHome',
      name: 'gerenteHome',
      builder: (context, state) => const GerenteHomeWidget(),
    ),
    GoRoute(
      path: '/comprasHome',
      name: 'comprasHome',
      builder: (context, state) => const ComprasHomeWidget(),
    ),
    GoRoute(
      path: '/depositoHome',
      name: 'depositoHomePage',
      builder: (context, state) => DepositohomeWidget(
        initialTab: state.uri.queryParameters['tab'],
      ),
    ),
    GoRoute(
      path: '/necesidades',
      name: 'NecesidadesPage',
      builder: (context, state) => const NecesidadesPageWidget(),
    ),
    GoRoute(
      path: '/planificarViaje',
      name: 'PlanificarViaje',
      builder: (context, state) {
        final editId = state.uri.queryParameters['editId'];
        return PlanificarViajeWidget(editId: editId);
      },
    ),
    GoRoute(
      path: '/viajedetalle',
      name: 'ViajeDetalle',
      builder: (context, state) {
        final viajeId = state.uri.queryParameters['viajeId'] ?? '';
        return ViajeDetalleWidget(viajeId: viajeId);
      },
    ),
    GoRoute(
      path: '/rutadetalle',
      name: 'RutaDetalle',
      builder: (context, state) {
        final viajeId = state.uri.queryParameters['viajeId'] ?? '';
        return RutaDetalleWidget(viajeId: viajeId);
      },
    ),
    GoRoute(
      path: '/paradaDetalle',
      name: 'paradaDetalle',
      builder: (context, state) {
        final paradaId = state.uri.queryParameters['paradaId'] ?? '';
        return ParadaDetalleWidget(paradaId: paradaId);
      },
    ),
    GoRoute(
      path: '/pesajes',
      name: 'Pesajes',
      builder: (context, state) => const PesajesPageWidget(),
    ),
    GoRoute(
      path: '/pesajesItem',
      name: 'pesajesItem',
      builder: (context, state) {
        final paradaId = state.uri.queryParameters['paradaId'] ?? '';
        final paradaItemId = state.uri.queryParameters['paradaItemId'];
        return PesajesItemWidget(paradaId: paradaId, paradaItemId: paradaItemId);
      },
    ),
    GoRoute(
      path: '/remito',
      name: 'RemitoPage',
      builder: (context, state) {
        final params = state.uri.queryParameters;
        return RemitoPageWidget(
          paradaId: params['paradaId'] ?? '',
          receptorTipo: params['receptorTipo'],
          receptorNombre: params['receptorNombre'],
          receptorDni: params['receptorDni'],
        );
      },
    ),
    GoRoute(
      path: '/rutas',
      name: 'rutasPage',
      builder: (context, state) => const RutasPageWidget(),
    ),
    GoRoute(
      name: ViajesPageWidget.routeName,
      path: ViajesPageWidget.routePath,
      builder: (context, state) => ViajesPageWidget(
        initialEstado: state.uri.queryParameters['estado'],
      ),
    ),
    GoRoute(
      path: '/recolecciones',
      name: 'recoleccionesPage',
      builder: (context, state) => const RecoleccionesPageWidget(),
    ),
    GoRoute(
      path: '/distribuciones',
      name: 'distribucionesPage',
      builder: (context, state) => const DistribucionesPageWidget(),
    ),
    GoRoute(
      path: '/vehiculos',
      name: 'VehiculosPage',
      builder: (context, state) => const VehiculosPageWidget(),
    ),
    GoRoute(
      path: '/vehiculoDetalle',
      name: 'VehiculoDetalle',
      builder: (context, state) {
        final vehiculoId = state.uri.queryParameters['id'];
        return VehiculoDetalleWidget(vehiculoId: vehiculoId);
      },
    ),
    GoRoute(
      path: '/productos',
      name: 'ProductosPage',
      builder: (context, state) => const ProductosPageWidget(),
    ),
    GoRoute(
      path: '/apicultores',
      name: 'ApicultoresPage',
      builder: (context, state) => const ApicultoresPageWidget(),
    ),
    GoRoute(
      path: '/gastos',
      name: 'GastosPage',
      builder: (context, state) => const GastosPageWidget(),
    ),
    GoRoute(
      path: '/remitosLista',
      name: 'RemitosListaPage',
      builder: (context, state) => const RemitosListaPageWidget(),
    ),
    GoRoute(
      path: '/agregarPesaje',
      name: 'AgregarPesaje',
      builder: (context, state) {
        // Acepta params por extra (desde context.push) o por queryParameters (URL directa)
        final extra = state.extra as Map<String, dynamic>?;
        final params = state.uri.queryParameters;
        return AgregarPesajeWidget(
          paradaId: extra?['paradaId']?.toString() ?? params['paradaId'] ?? '',
          viajeId: extra?['viajeId']?.toString() ?? params['viajeId'],
          viajeCode: extra?['viajeCode']?.toString() ?? params['viajeCode'] ?? 'V-S/N',
          apicultorNombre: extra?['apicultorNombre']?.toString() ?? params['apicultorNombre'] ?? 'S/D',
          localidad: extra?['localidad']?.toString() ?? params['localidad'] ?? 'S/D',
          apicultorId: extra?['apicultorId']?.toString() ?? params['apicultorId'],
        );
      },
    ),
    GoRoute(
      path: '/cargas',
      name: 'CargasPage',
      builder: (context, state) => const CargasPageWidget(),
    ),
    GoRoute(
      path: '/cargaDetalle',
      name: 'CargaDetalle',
      builder: (context, state) {
        final id = state.uri.queryParameters['id'];
        final isNew = state.uri.queryParameters['new'] == 'true';
        return CargaDetalleWidget(cargaId: id, isNew: isNew);
      },
    ),
    GoRoute(
      path: '/remito_carga',
      name: 'RemitoCargaPage',
      builder: (context, state) {
        final cargaId = state.uri.queryParameters['cargaId'] ?? '';
        return RemitoCargaPageWidget(cargaId: cargaId);
      },
    ),
    GoRoute(
      path: '/reportes',
      name: 'ReportesPage',
      builder: (context, state) => const ReportesPage(),
    ),
    GoRoute(
      path: '/trazabilidad',
      name: 'TrazabilidadPage',
      builder: (context, state) => const TrazabilidadPage(),
    ),
    GoRoute(
      path: '/configuracion',
      name: 'ConfiguracionPage',
      builder: (context, state) => const ConfiguracionPage(),
    ),
    GoRoute(
      path: '/perfil',
      name: 'PerfilUsuarioPage',
      builder: (context, state) => const PerfilUsuarioPage(),
    ),
  ],
);
class FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadePageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(opacity: animation, child: child);
  }
}