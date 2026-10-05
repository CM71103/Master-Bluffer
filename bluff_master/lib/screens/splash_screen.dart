import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();
    _timer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) Navigator.pushReplacementNamed(context, '/auth');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Center(
        child: FadeTransition(
          opacity: _anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.7, end: 1).animate(
              CurvedAnimation(parent: _anim, curve: Curves.elasticOut),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.theater_comedy, size: 120, color: kPrimary),
                SizedBox(height: 24),
                Text('PARTY\nBLUFFING',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.1)),
                Text('GAME',
                    style: TextStyle(
                        fontSize: 36, fontWeight: FontWeight.w900, color: kAccent)),
                SizedBox(height: 32),
                SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
