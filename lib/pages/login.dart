import '../backend/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/supabase_service.dart';
import 'dart:ui';
import 'dart:math';

class LoginWidget extends StatefulWidget {
  const LoginWidget({super.key});

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _keepSession = false;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_onFocusChange);
    _passwordFocusNode.addListener(_onFocusChange);
    _checkSavedSession();
  }

  void _onFocusChange() {
    if (_emailFocusNode.hasFocus || _passwordFocusNode.hasFocus) {
      SystemChannels.textInput.invokeMethod('TextInput.show');
    }
    setState(() {}); // Redraw to update active states if needed
  }

  Future<void> _checkSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final keep = prefs.getBool('keep_session') ?? false;
    final userId = prefs.getString('user_id');
    setState(() {
      _keepSession = keep;
    });
    if (keep && userId != null && userId.isNotEmpty) {
      print('LoginWidget: Sesión activa detectada en caché. Redirigiendo a /home');
      if (mounted) {
        context.go('/home');
      }
    }
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa email y contraseña'))
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SupabaseService().login(email, password);
      
      // Guardar preferencia de mantener sesión activa
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('keep_session', _keepSession);
      
      if (mounted) context.go('/home');
    } catch (error) {
      if (mounted) {
        String msg = error.toString().replaceAll('Exception:', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de acceso: $msg'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      body: Stack(
        children: [
          // Aislamiento de Redibujado: TechnicalGridPainter interactivo envuelto en su propio RepaintBoundary
          const Positioned.fill(
            child: RepaintBoundary(
              child: InteractiveTechnicalGrid(),
            ),
          ),
          // Contenido principal
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Aislamiento de Redibujado: La Card de Login en otro RepaintBoundary separado
                    RepaintBoundary(
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 420),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: const Color(0xFF08201A).withOpacity(0.05),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF08201A).withOpacity(0.08),
                              blurRadius: 40,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo hexagonal achicado a 80x80px
                            Container(
                              width: 80,
                              height: 80,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: DesignTokens.primary.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/logo_Geologistica_Verde.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            // Identidad y cabecera en tipografía Manrope
                            const Text(
                              'GeoLogística',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: DesignTokens.primary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'COMMAND CENTER',
                              style: TextStyle(
                                fontFamily: 'Work Sans',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: DesignTokens.onSurfaceVariant,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Formulario
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Username Label
                                const Text(
                                  'USERNAME / ID',
                                  style: TextStyle(
                                    fontFamily: 'Work Sans',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: DesignTokens.onSurfaceVariant,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Username Field
                                TextField(
                                  controller: _emailController,
                                  focusNode: _emailFocusNode,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(
                                      Icons.person_outline_rounded,
                                      color: DesignTokens.primary.withOpacity(_emailFocusNode.hasFocus ? 0.8 : 0.4),
                                      size: 20,
                                    ),
                                    hintText: 'Ingrese su usuario',
                                    hintStyle: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: DesignTokens.primary.withOpacity(0.3),
                                    ),
                                    filled: true,
                                    fillColor: DesignTokens.surfaceLow,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                    focusedBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(color: Color(0xFFFDBE49), width: 2.0),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(12.0),
                                        topRight: Radius.circular(12.0),
                                      ),
                                    ),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: DesignTokens.outline.withOpacity(0.3), width: 1.5),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(12.0),
                                        topRight: Radius.circular(12.0),
                                      ),
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: DesignTokens.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Password Label + Recover
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'PASSWORD',
                                      style: TextStyle(
                                        fontFamily: 'Work Sans',
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: DesignTokens.onSurfaceVariant,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Contacte al administrador para recuperar sus credenciales.'),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'Recuperar',
                                        style: TextStyle(
                                          fontFamily: 'Work Sans',
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: DesignTokens.secondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Password Field
                                TextField(
                                  controller: _passwordController,
                                  focusNode: _passwordFocusNode,
                                  obscureText: _obscurePassword,
                                  keyboardType: TextInputType.visiblePassword,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _isLoading ? null : _signIn(),
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(
                                      Icons.lock_outline_rounded,
                                      color: DesignTokens.primary.withOpacity(_passwordFocusNode.hasFocus ? 0.8 : 0.4),
                                      size: 20,
                                    ),
                                    hintText: '••••••••',
                                    hintStyle: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: DesignTokens.primary.withOpacity(0.3),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: DesignTokens.primary.withOpacity(0.4),
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    filled: true,
                                    fillColor: DesignTokens.surfaceLow,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                    focusedBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(color: Color(0xFFFDBE49), width: 2.0),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(12.0),
                                        topRight: Radius.circular(12.0),
                                      ),
                                    ),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: DesignTokens.outline.withOpacity(0.3), width: 1.5),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(12.0),
                                        topRight: Radius.circular(12.0),
                                      ),
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: DesignTokens.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Mantener sesión activa Checkbox
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _keepSession,
                                    activeColor: DesignTokens.primary,
                                    checkColor: Colors.white,
                                    side: BorderSide(
                                      color: DesignTokens.outline.withOpacity(0.8),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _keepSession = val ?? false;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Mantener sesión activa',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: DesignTokens.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            // Botón Ingresar
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _signIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: DesignTokens.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  textStyle: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text('INGRESAR'),
                                          SizedBox(width: 8),
                                          Icon(Icons.arrow_forward_rounded, size: 18),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            // Módulo Biométrico
                            GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('El acceso biométrico requiere configuración previa en el dispositivo.'),
                                  ),
                                );
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.fingerprint_rounded,
                                    size: 32,
                                    color: DesignTokens.primary.withOpacity(0.6),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'LOGIN BIOMÉTRICO',
                                    style: TextStyle(
                                      fontFamily: 'Work Sans',
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: DesignTokens.onSurfaceVariant,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.go('/'),
                      child: const Text(
                        'VOLVER',
                        style: TextStyle(
                          fontFamily: 'Work Sans',
                          fontWeight: FontWeight.w800,
                          color: DesignTokens.primary,
                          letterSpacing: 1.0,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Footer corporativo
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.transparent,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '© 2024 GEOLOGÍSTICA APIARY OPERATIONS.',
                    style: TextStyle(
                      fontFamily: 'Work Sans',
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF859E96),
                      letterSpacing: 0.5,
                    ),
                  ),
                  Row(
                    children: [
                      const _PulsingDot(),
                      SizedBox(width: 6),
                      Text(
                        'SYSTEM ONLINE',
                        style: TextStyle(
                          fontFamily: 'Work Sans',
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF859E96),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget Stateful para el fondo reticulado interactivo con brillo
class InteractiveTechnicalGrid extends StatefulWidget {
  const InteractiveTechnicalGrid({super.key});

  @override
  State<InteractiveTechnicalGrid> createState() => _InteractiveTechnicalGridState();
}

class _InteractiveTechnicalGridState extends State<InteractiveTechnicalGrid> {
  Offset _mousePos = Offset.zero;
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (e) => setState(() {
        _hovering = true;
      }),
      onExit: (e) => setState(() {
        _hovering = false;
      }),
      onHover: (e) {
        setState(() {
          _mousePos = e.localPosition;
        });
      },
      child: CustomPaint(
        painter: TechnicalGridPainter(
          mousePosition: _mousePos,
          isHovering: _hovering,
        ),
      ),
    );
  }
}

// Painter para dibujar la cuadrícula técnica de puntos con degradado radial interactivo
class TechnicalGridPainter extends CustomPainter {
  final Offset mousePosition;
  final bool isHovering;

  TechnicalGridPainter({
    required this.mousePosition,
    required this.isHovering,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dibujar el brillo radial si está en hovering
    if (isHovering) {
      final radialPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment(
            (mousePosition.dx / size.width) * 2 - 1,
            (mousePosition.dy / size.height) * 2 - 1,
          ),
          radius: 0.35,
          colors: [
            const Color(0xFFFDBE49).withOpacity(0.06), // Honey Gold muy sutil
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), radialPaint);
    }

    // 2. Dibujar la cuadrícula técnica de puntos
    final gridPaint = Paint()
      ..color = const Color(0xFF08201A).withOpacity(0.04)
      ..style = PaintingStyle.fill;

    const spacing = 32.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, gridPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant TechnicalGridPainter oldDelegate) {
    return oldDelegate.mousePosition != mousePosition ||
        oldDelegate.isHovering != isHovering;
  }
}

// Widget Stateful para el punto verde pulsante
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.greenAccent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
