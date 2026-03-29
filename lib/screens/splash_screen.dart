import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final bool isFirstLaunch;
  final String userName;
  final VoidCallback onDone;

  const SplashScreen({
    required this.isFirstLaunch,
    required this.userName,
    required this.onDone,
    super.key,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();

    Timer(const Duration(milliseconds: 1800), widget.onDone);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final greeting = widget.isFirstLaunch
        ? 'Welcome to WildPath'
        : widget.userName.isNotEmpty
            ? 'Welcome back, ${widget.userName}'
            : 'Welcome back';

    final subtitle = widget.isFirstLaunch
        ? 'Your camping trip planner'
        : _timeGreeting();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [WildPathColors.forest, WildPathColors.moss],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Text.rich(TextSpan(
                    text: 'Wild',
                    style: WildPathTypography.display(
                      fontSize: 48,
                      color: Colors.white,
                      letterSpacing: -1.0,
                    ),
                    children: [
                      TextSpan(
                        text: 'Path',
                        style: WildPathTypography.display(
                          fontSize: 48,
                          fontStyle: FontStyle.italic,
                          color: WildPathColors.fern,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ],
                  )),
                  const SizedBox(height: 24),
                  Text(
                    greeting,
                    style: WildPathTypography.body(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: WildPathTypography.body(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _timeGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
