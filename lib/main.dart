import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

import 'providers/auth_provider.dart';
import 'providers/horario_provider.dart';
import 'screens/login_screen.dart';
import 'screens/cambio_password_screen.dart';
import 'screens/registro_facial_screen.dart';
import 'screens/guia_practica_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'deep_link_state.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  await NotificationService().init();
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

    // 1) App cerrada
    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('INITIAL LINK: $initialUri');
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Error getInitialLink: $e');
    }

    // 2) App en foreground/background
    _linkSub = _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('STREAM LINK: $uri');
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('Deep link stream error: $err');
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('=== DEEP LINK RECIBIDO ===');
    debugPrint('  scheme : ${uri.scheme}');
    debugPrint('  host   : ${uri.host}');
    debugPrint('  path   : ${uri.path}');
    debugPrint('  query  : ${uri.queryParameters}');

    if (uri.scheme != 'asistencia') {
      debugPrint('Esquema no soportado: ${uri.scheme}');
      return;
    }

    final esResetPassword =
        uri.host == 'reset-password' || uri.path.contains('reset-password');

    if (!esResetPassword) {
      debugPrint('Ruta no reconocida: ${uri.host}${uri.path}');
      return;
    }

    // Normalizamos claves por si viene &amp;
    final params = <String, String>{};
    uri.queryParameters.forEach((key, value) {
      final keyLimpia =
          key.replaceAll('amp;', '').replaceAll('&amp;', '').trim();
      params[keyLimpia] = value;
    });

    debugPrint('  params normalizados: $params');

    final token = params['token'];
    final emailRaw = params['email'];
    final email = emailRaw != null ? Uri.decodeComponent(emailRaw) : null;

    if (token == null || token.isEmpty || email == null || email.isEmpty) {
      debugPrint('Deep link sin token o email válido');
      return;
    }

    // Guardamos el link para que el Splash decida
    DeepLinkState.pendingUri = uri;
    DeepLinkState.pendingArgs = {'token': token, 'email': email};

    // Si el splash ya pasó y la app está abierta, navegamos directo
    if (DeepLinkState.deepLinkHandled) {
      debugPrint('App ya iniciada, navegando directo a /reset-password');
      _navigatorKey.currentState?.pushNamed(
        '/reset-password',
        arguments: {'token': token, 'email': email},
      );
    }
  }

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
        supportedLocales: const [
          Locale('es'),
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4A6CF7),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        initialRoute: '/',
        onGenerateRoute: (settings) {
          if (settings.name == '/') {
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          }
          if (settings.name == '/login') {
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
          if (settings.name == '/forgot-password') {
            return MaterialPageRoute(
              builder: (_) => const ForgotPasswordScreen(),
            );
          }
          if (settings.name == '/reset-password') {
            final args = settings.arguments as Map<String, String>?;
            if (args != null &&
                args['token'] != null &&
                args['email'] != null) {
              return MaterialPageRoute(
                builder: (_) => ResetPasswordScreen(
                  token: args['token']!,
                  email: args['email']!,
                ),
              );
            }
            // Si no hay token/email -> va a login (tu requisito)
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
          return MaterialPageRoute(builder: (_) => const SplashScreen());
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _verificarAutenticacion();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _slideAnimation = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _verificarAutenticacion() async {
    await Future.delayed(const Duration(milliseconds: 1800));

    if (!mounted) return;

    // ====== LOGICA QUE PEDISTE ======
    // 1. Si HAY link de reset password -> ir a reset password screen
    if (DeepLinkState.pendingArgs != null) {
      final args = DeepLinkState.pendingArgs!;
      DeepLinkState.deepLinkHandled = true;

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(
            token: args['token']!,
            email: args['email']!,
            fromRegistration: false,
          ),
        ),
        (route) => false,
      );
      DeepLinkState.clear();
      return;
    }

    // 2. Si NO hay link -> flujo normal -> ir a login / home
    final authProvider = context.read<AuthProvider>();
    final isAuth = await authProvider.checkAuthStatus();

    if (!mounted) return;

    if (isAuth) {
      _navegarSegunEstado(authProvider);
    } else {
      _irA(const LoginScreen());
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

    final destino = await pantallaTrasLogin(authProvider.user?.id);
    if (!mounted) return;
    _irA(destino);
  }

  void _irA(Widget pantalla) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => pantalla),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFE8EEFF),
              Colors.white,
              const Color(0xFFF0F4FF),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4A6CF7).withOpacity(0.25),
                          blurRadius: 40,
                          spreadRadius: 8,
                          offset: const Offset(0, 20),
                        ),
                        BoxShadow(
                          color: const Color(0xFF4A6CF7).withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: Image.asset(
                        'assets/icon/icon.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF4A6CF7),
                                  Color(0xFF6C63FF),
                                  Color(0xFF8B5CF6),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(36),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.school_rounded,
                                size: 70,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      const Text(
                        'Asistencia Docente',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A2B4A),
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              const Color(0xFF4A6CF7).withOpacity(0.08),
                              const Color(0xFF6C63FF).withOpacity(0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFF4A6CF7).withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          'Sistema de control de asistencia',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF4A6CF7),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Column(
                        children: [
                          const SizedBox(
                            height: 44,
                            width: 44,
                            child: CircularProgressIndicator(
                              strokeWidth: 3.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF4A6CF7),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Cargando...',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade500,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 50),
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: Tween<double>(begin: 0.0, end: 0.6)
                          .animate(
                            CurvedAnimation(
                              parent: _animationController,
                              curve: const Interval(0.4, 1.0,
                                  curve: Curves.easeOut),
                            ),
                          )
                          .value,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Versión 3.0.0',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '© 2026 Asistencia Virtual Pro',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey.shade400,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
