import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

import 'providers/auth_provider.dart';
import 'providers/horario_provider.dart';
import 'screens/login_screen.dart';
import 'screens/cambio_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/registro_facial_screen.dart';
import 'screens/guia_demo_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;

  bool _deepLinkHandled = false; // Empieza en false
  Uri? _lastHandledUri;
  DateTime? _lastHandledTime;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // 1) Link inicial
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('INITIAL LINK: $initialUri');
        _deepLinkHandled = true;
        // Dar tiempo a que MaterialApp monte
        Future.delayed(const Duration(milliseconds: 300),
            () => _handleDeepLink(initialUri));
      }
    } catch (e) {
      debugPrint('Error getInitialLink: $e');
    }

    // 2) Links en foreground
    _linkSub = _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('STREAM LINK: $uri');
        _deepLinkHandled = true;
        _handleDeepLink(uri);
      },
      onError: (err) => debugPrint('Deep link stream error: $err'),
    );
  }

  void _handleDeepLink(Uri uri) {
    // Deduplicar
    final now = DateTime.now();
    if (_lastHandledUri?.toString() == uri.toString() &&
        _lastHandledTime != null &&
        now.difference(_lastHandledTime!).inMilliseconds < 1500) {
      return;
    }
    _lastHandledUri = uri;
    _lastHandledTime = now;

    if (_navigating) return;
    _navigating = true;

    debugPrint(
        '=== DEEP LINK RECIBIDO === scheme:${uri.scheme} host:${uri.host} path:${uri.path}');

    if (uri.scheme != 'asistencia') {
      _navigating = false;
      return;
    }

    // 🔑 CORRECCIÓN 1: Tu XML usa host="app" y path="/reset-password"
    final esResetPassword =
        (uri.host == 'app' && uri.path.startsWith('/reset-password')) ||
            (uri.host == 'reset-password');

    if (!esResetPassword) {
      _navigating = false;
      return;
    }

    final params = <String, String>{};
    uri.queryParameters.forEach((key, value) {
      params[key.replaceAll('amp;', '').trim()] = value;
    });

    final token = params['token'];
    final email = params['email'];

    if (token == null || token.isEmpty || email == null || email.isEmpty) {
      _navigating = false;
      return;
    }

    _navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/reset-password',
      (route) => false,
      arguments: {'token': token, 'email': email},
    ).whenComplete(() => _navigating = false);
  }

  bool get deepLinkHandled => _deepLinkHandled;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HorarioProvider()),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Asistencia Docente',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('es')],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A6CF7)),
          useMaterial3: true,
        ),
        initialRoute: '/',
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/':
              return MaterialPageRoute(
                  builder: (_) =>
                      SplashScreen(hasPendingDeepLink: () => _deepLinkHandled));
            case '/login':
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            case '/forgot-password':
              return MaterialPageRoute(
                  builder: (_) => const ForgotPasswordScreen());
            case '/reset-password':
              final args = settings.arguments as Map<String, String>?;
              if (args?['token'] != null && args?['email'] != null) {
                return MaterialPageRoute(
                    builder: (_) => ResetPasswordScreen(
                        token: args!['token']!, email: args['email']!));
              }
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            case '/home':
              return MaterialPageRoute(builder: (_) => const HomeScreen());
            default:
              return MaterialPageRoute(
                  builder: (_) =>
                      SplashScreen(hasPendingDeepLink: () => _deepLinkHandled));
          }
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  final bool Function()? hasPendingDeepLink;
  const SplashScreen({super.key, this.hasPendingDeepLink});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Timer? _navTimer;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..forward();

    // 🔑 CORRECCIÓN 2: Timeout de seguridad. Si en 2.2s no pasó nada, fuerza login
    _navTimer = Timer(const Duration(milliseconds: 2200), _checkAndNavigate);
  }

  Future<void> _checkAndNavigate() async {
    if (!mounted || _isNavigating) return;

    // Si llegó deep link, no hacer nada
    if (widget.hasPendingDeepLink?.call() ?? false) {
      debugPrint('Splash: deep link detectado');
      return;
    }

    setState(() => _isNavigating = true);

    // 🔑 CORRECCIÓN 3: Usar microtask para asegurar que Provider ya cargó
    await Future.microtask(() {});
    final authProvider = context.read<AuthProvider>();
    final isAuth = await authProvider.checkAuthStatus();

    if (!mounted) return;
    if (widget.hasPendingDeepLink?.call() ?? false) return;

    if (isAuth) {
      await _navegarSegunEstado(authProvider);
    } else {
      _irA(const LoginScreen()); // 🔑 Aquí siempre cae si es primera vez
    }
  }

  Future<void> _navegarSegunEstado(AuthProvider authProvider) async {
    if (authProvider.necesitaCambiarPassword) {
      _irA(const CambioPasswordScreen());
      return;
    }
    if (authProvider.necesitaRegistroFacial) {
      _irA(const RegistroFacialScreen());
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final yaVioTutorial = prefs.getBool('ya_vio_tutorial') ?? false;
    _irA(yaVioTutorial ? const HomeScreen() : const GuiaDemoScreen());
  }

  void _irA(Widget pantalla) {
    if (!mounted || _isNavigating) return;
    if (widget.hasPendingDeepLink?.call() ?? false) return;

    _isNavigating = true;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => pantalla));
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFFE8EEFF), Colors.white]),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/icon/icon.png',
                  width: 120,
                  height: 120,
                  errorBuilder: (_, __, ___) => const Icon(Icons.school,
                      size: 80, color: Color(0xFF4A6CF7))),
              const SizedBox(height: 24),
              const Text('Asistencia Docente',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 40),
              const CircularProgressIndicator(color: Color(0xFF4A6CF7)),
            ],
          ),
        ),
      ),
    );
  }
}
