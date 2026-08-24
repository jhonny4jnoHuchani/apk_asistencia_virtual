import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/auth_provider.dart';
import 'providers/horario_provider.dart';
import 'screens/login_screen.dart';
import 'screens/cambio_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/registro_facial_screen.dart';
import 'screens/guia_demo_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HorarioProvider()),
      ],
      child: MaterialApp(
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
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

// ============================================
// PANTALLA SPLASH - Verifica autenticación
// ============================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _verificarAutenticacion();
  }

  Future<void> _verificarAutenticacion() async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

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

    // Verificar si ya vio el tutorial
    final prefs = await SharedPreferences.getInstance();
    final yaVioTutorial = prefs.getBool('ya_vio_tutorial') ?? false;

    if (!yaVioTutorial) {
      // Primera vez → mostrar guía demo
      _irA(const GuiaDemoScreen());
    } else {
      // Ya sabe usar la app → ir directo al Home
      _irA(const HomeScreen());
    }
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.school,
                size: 60,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Asistencia Docente',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sistema de control de asistencia',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}