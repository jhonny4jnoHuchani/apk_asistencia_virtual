import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

// ============================================
// GUIA DE USO - MODO PRACTICO
// ============================================
// Reemplaza a guia_demo_screen.dart (que se conserva como referencia).
// La guia recorre el marcado real paso a paso usando las mismas pantallas
// de la app (tarjeta de horario y camara de marcado) con una clase de
// ejemplo, sin enviar nada al servidor.

// Etapas del recorrido, en el orden en que se muestran
enum EtapaGuia {
  intro,
  tarjeta,
  verificaciones,
  fotoFrontal,
  fotoGesto,
  fotoConstancia,
  salida,
  consejos,
  fin,
}

class GuiaPracticaScreen extends StatefulWidget {
  const GuiaPracticaScreen({super.key});

  @override
  State<GuiaPracticaScreen> createState() => _GuiaPracticaScreenState();
}

class _GuiaPracticaScreenState extends State<GuiaPracticaScreen> {
  EtapaGuia _etapa = EtapaGuia.intro;

  static const Color _primaryColor = Color(0xFF4A6CF7);
  static const Color _warningColor = Color(0xFFF59E0B);
  static const Color _darkColor = Color(0xFF1A2B4A);

  int get _numeroPaso => _etapa.index + 1;
  int get _totalPasos => EtapaGuia.values.length;
  bool get _esPrimera => _etapa == EtapaGuia.values.first;
  bool get _esUltima => _etapa == EtapaGuia.values.last;

  void _siguiente() {
    if (_esUltima) return;
    setState(() => _etapa = EtapaGuia.values[_etapa.index + 1]);
  }

  void _anterior() {
    if (_esPrimera) return;
    setState(() => _etapa = EtapaGuia.values[_etapa.index - 1]);
  }

  // Igual que en la guia anterior: marca la guia como vista y va al Home
  Future<void> _finalizar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ya_vio_tutorial', true);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Guía de uso',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: _warningColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _finalizar,
            child: const Text(
              'Saltar',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildBanner(),
            _buildProgreso(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [_buildContenidoEtapa()],
              ),
            ),
            _buildNavegacion(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Banner de modo practica
  // ─────────────────────────────────────────────────────────────
  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      color: _warningColor.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.school_rounded, color: _warningColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'MODO PRÁCTICA: los datos son de ejemplo y no se registra ninguna asistencia.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade900,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Indicador "Paso X de N"
  // ─────────────────────────────────────────────────────────────
  Widget _buildProgreso() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paso $_numeroPaso de $_totalPasos',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _numeroPaso / _totalPasos,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(_primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Contenido de cada etapa
  //  (por ahora un texto que indica en que fase se implementa)
  // ─────────────────────────────────────────────────────────────
  Widget _buildContenidoEtapa() {
    switch (_etapa) {
      case EtapaGuia.intro:
        return _buildTextoEtapa(
          Icons.waving_hand_rounded,
          'Bienvenido a la guía',
          'Vas a practicar un marcado completo con una clase de ejemplo, '
              'usando las mismas pantallas de la app. Nada se envía al servidor.',
        );
      case EtapaGuia.tarjeta:
        return _buildTextoEtapa(
          Icons.calendar_today_rounded,
          'Tu tarjeta de horario',
          'Pendiente (Fase 2): tarjeta real con una clase de ejemplo.',
        );
      case EtapaGuia.verificaciones:
        return _buildTextoEtapa(
          Icons.fingerprint_rounded,
          'Huella y GPS',
          'Pendiente (Fase 3): verificación real de huella y GPS.',
        );
      case EtapaGuia.fotoFrontal:
        return _buildTextoEtapa(
          Icons.face_rounded,
          'Foto 1: frontal',
          'Pendiente (Fase 4): cámara real, foto frontal.',
        );
      case EtapaGuia.fotoGesto:
        return _buildTextoEtapa(
          Icons.pan_tool_rounded,
          'Foto 2: gesto',
          'Pendiente (Fase 4): cámara real, gesto al azar.',
        );
      case EtapaGuia.fotoConstancia:
        return _buildTextoEtapa(
          Icons.photo_camera_rounded,
          'Foto 3: constancia del aula',
          'Pendiente (Fase 4): cámara trasera, foto del aula.',
        );
      case EtapaGuia.salida:
        return _buildTextoEtapa(
          Icons.logout_rounded,
          'Marcar salida',
          'Pendiente (Fase 5): diálogo real de confirmación de salida.',
        );
      case EtapaGuia.consejos:
        return _buildTextoEtapa(
          Icons.lightbulb_rounded,
          'Consejos',
          'Pendiente (Fase 6): errores comunes y cómo evitarlos.',
        );
      case EtapaGuia.fin:
        return _buildTextoEtapa(
          Icons.check_circle_rounded,
          '¡Listo!',
          'Ya conoces todo el proceso de marcado.',
        );
    }
  }

  Widget _buildTextoEtapa(IconData icono, String titulo, String descripcion) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icono, size: 48, color: _primaryColor),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _darkColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              descripcion,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Botones Anterior / Siguiente
  // ─────────────────────────────────────────────────────────────
  Widget _buildNavegacion() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          if (!_esPrimera)
            Expanded(
              child: OutlinedButton(
                onPressed: _anterior,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Anterior'),
              ),
            ),
          if (!_esPrimera) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _esUltima ? _finalizar : _siguiente,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                _esUltima ? 'Ir a mi horario' : 'Siguiente',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
