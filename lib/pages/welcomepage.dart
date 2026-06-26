import '../flutter_flow/flutter_flow_widgets.dart';
import '../flutter_flow/flutter_flow_theme.dart';
import 'dart:math';
import '../index.dart';
import 'package:flutter/material.dart';
import '../backend/design_tokens.dart';
import '../main.dart' show supabaseReady;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import 'welcome_page_model.dart';
export 'welcome_page_model.dart';

class WelcomePageWidget extends StatefulWidget {
  const WelcomePageWidget({super.key});

  static String routeName = 'WelcomePage';
  static String routePath = '/WelcomePage';

  @override
  State<WelcomePageWidget> createState() => _WelcomePageWidgetState();
}

class _WelcomePageWidgetState extends State<WelcomePageWidget> with TickerProviderStateMixin {
  late WelcomePageModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isSplashActive = true;
  bool _supabaseReady = false;
  double _progressValue = 0.0;
  late AnimationController _breathingController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => WelcomePageModel());

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    )..addStatusListener((status) {
        if (!_isSplashActive) return;
        if (status == AnimationStatus.completed) {
          _breathingController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _breathingController.forward();
        }
      });
    _breathingController.forward();

    _animateProgress();

    supabaseReady.future.then((_) async {
      if (mounted) {
        setState(() => _supabaseReady = true);
        final prefs = await SharedPreferences.getInstance();
        final keep = prefs.getBool('keep_session') ?? false;
        final userId = prefs.getString('user_id');
        final role = prefs.getString('user_puesto') ?? '';
        
        if (keep && userId != null && userId.isNotEmpty) {
          print('WelcomePage: Sesión activa detectada. Rol: $role. Redirigiendo...');
          if (mounted) {
            if (role.toLowerCase().contains('chofer')) {
              context.go('/choferHome');
            } else {
              context.go('/home');
            }
          }
        }
      }
    });
  }

  void _animateProgress() async {
    const totalDuration = Duration(milliseconds: 700);
    const interval = Duration(milliseconds: 50);
    final steps = totalDuration.inMilliseconds ~/ interval.inMilliseconds;

    for (int i = 0; i <= steps; i++) {
      await Future.delayed(interval);
      if (!mounted) return;
      setState(() {
        _progressValue = i / steps;
      });
    }

    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      setState(() {
        _isSplashActive = false;
      });
      _breathingController.animateTo(0.0, duration: const Duration(milliseconds: 500));
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: DesignTokens.surfaceLow,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final bool isDesktop = constraints.maxWidth >= 1024;
            
            return Stack(
              children: [
                // Background transition
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    color: _isSplashActive ? DesignTokens.surface : DesignTokens.surfaceLow,
                  ),
                ),
                // Honeycomb Pattern Background
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: _isSplashActive ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeIn,
                    child: CustomPaint(
                      painter: HoneycombPainter(
                        color: theme.primary.withOpacity(0.03),
                      ),
                    ),
                  ),
                ),
                // Main Content
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isDesktop ? 480 : double.infinity,
                          ),
                          child: isDesktop && !_isSplashActive
                              ? Container(
                                  padding: const EdgeInsets.all(40),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: DesignTokens.primary.withOpacity(0.04),
                                        blurRadius: 24,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: _buildWelcomeContent(theme, isDesktop),
                                )
                              : _buildWelcomeContent(theme, isDesktop),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWelcomeContent(FlutterFlowTheme theme, bool isDesktop) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo Container with breathing scaling
        ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: _isSplashActive ? 180 : (isDesktop ? 120 : 150),
            height: _isSplashActive ? 180 : (isDesktop ? 120 : 150),
            decoration: const BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.primary.withOpacity(_isSplashActive ? 0.05 : 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo_Geologistica_Verde.png',
                      height: 160,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),

        // Golden Progress Indicator
        AnimatedOpacity(
          opacity: _isSplashActive ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: _isSplashActive
              ? Column(
                  children: [
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 150,
                      height: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _progressValue,
                          backgroundColor: DesignTokens.secondary.withOpacity(0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(DesignTokens.secondary),
                        ),
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),

        // Brand details & texts
        AnimatedOpacity(
          opacity: _isSplashActive ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          child: _isSplashActive
              ? const SizedBox.shrink()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'GeoLogística',
                      style: theme.displayLarge.override(
                        fontFamily: 'Manrope',
                        color: theme.primary,
                        fontSize: isDesktop ? 38 : 44,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'TECNOLOGÍA Y LOGÍSTICA APÍCOLA',
                      textAlign: TextAlign.center,
                      style: theme.labelSmall.override(
                        fontFamily: 'Work Sans',
                        color: theme.secondary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        fontSize: isDesktop ? 9 : 10,
                      ),
                    ),
                  ],
                ),
        ),
        
        if (!_isSplashActive) ...[
          const SizedBox(height: 60),
          // Premium Button
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.primary.withOpacity(0.15),
                  blurRadius: 25,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _supabaseReady
                  ? () => GoRouter.of(context).pushNamed('Login')
                  : null,
              style: DesignTokens.secondaryButtonStyle.copyWith(
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              child: _supabaseReady
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.login_rounded, size: 18),
                        const SizedBox(width: 12),
                        Text(
                          'INICIAR',
                          style: theme.titleSmall.override(
                            fontFamily: 'Manrope',
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

class HoneycombPainter extends CustomPainter {
  final Color color;
  HoneycombPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const double radius = 30.0;
    const double height = radius * 2;
    const double width = radius * 1.732;

    for (double y = 0; y < size.height + height; y += height * 0.75) {
      bool offset = (y / (height * 0.75)).floor() % 2 != 0;
      for (double x = 0; x < size.width + width; x += width) {
        double currentX = x + (offset ? width / 2 : 0);
        _drawHexagon(canvas, paint, currentX, y, radius);
      }
    }
  }

  void _drawHexagon(Canvas canvas, Paint paint, double x, double y, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      double angle = (30 + 60 * i) * 3.14159 / 180;
      double px = x + r * cos(angle);
      double py = y + r * sin(angle);
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
