import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/metro_brand_header.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _progressController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _slideUp;
  late final Animation<double> _progressAnim;
  Timer? _navigateTimer;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideUp = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );
    _progressAnim = CurvedAnimation(parent: _progressController, curve: Curves.easeInOut);

    _fadeController.forward();
    _progressController.forward();

    _navigateTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      final isAuth = context.read<AuthProvider>().isAuthenticated;
      context.go(isAuth ? '/' : '/login');
    });
  }

  @override
  void dispose() {
    _navigateTimer?.cancel();
    _fadeController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/splash_bg.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF001F3F), Color(0xFF003366)],
                  ),
                ),
              );
            },
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.25, 0.55, 0.85, 1.0],
                colors: [
                  const Color(0xFF0A1628).withValues(alpha: 0.2),
                  Colors.transparent,
                  AppColors.primary.withValues(alpha: 0.3),
                  AppColors.primary.withValues(alpha: 0.85),
                  const Color(0xFF001B3D).withValues(alpha: 0.98),
                ],
              ),
            ),
          ),
          SafeArea(
            child: AnimatedBuilder(
              animation: _fadeController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeIn.value,
                  child: Transform.translate(
                    offset: Offset(0, _slideUp.value),
                    child: child,
                  ),
                );
              },
              child: Column(
                children: [
                  const Spacer(flex: 4),
                  const MetroBrandHeader(
                    logoWidth: 104,
                    titleWidth: 104,
                    titleFontSize: 9.5,
                    titleLetterSpacing: 1.7,
                    titleExtraWidth: 0,
                    titleColor: Color(0xFF003B8F),
                  ),
                  const Spacer(flex: 3),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.25),
                    child: AnimatedBuilder(
                      animation: _progressAnim,
                      builder: (context, child) {
                        return Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: _progressAnim.value,
                                backgroundColor: Colors.white.withValues(alpha: 0.08),
                                color: Colors.white.withValues(alpha: 0.6),
                                minHeight: 3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Sistem hazırlanıyor...',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
