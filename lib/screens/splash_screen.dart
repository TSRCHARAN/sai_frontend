import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  bool _isDarkMode = true;

  // Theme Getters
  Color get _bgStart => _isDarkMode ? const Color(0xFF0B0F19) : const Color(0xFFDCE0E5);
  Color get _bgEnd => _isDarkMode ? const Color(0xFF111625) : const Color(0xFFEDF0F2);
  Color get _iconColor => _isDarkMode ? const Color(0xFF00F3FF) : const Color(0xFF2563EB);
  Color get _textColor => _isDarkMode ? Colors.white : const Color(0xFF1E293B);

  late AnimationController _controller;
  late Animation<Offset> _logoSlide;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    
    // 1. Initial guess from system
    var brightness = PlatformDispatcher.instance.platformBrightness;
    _isDarkMode = brightness == Brightness.dark;

    // 2. Load saved preference
    _loadTheme();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Faster animation (1s)
    );

    // Logo slides in from the Left
    _logoSlide = Tween<Offset>(
      begin: const Offset(-2.0, 0.0), 
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutExpo, 
    ));

    // Text slides in from the Right
    _textSlide = Tween<Offset>(
      begin: const Offset(2.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutExpo,
    ));

    _controller.forward();

    // Wait for animation (1.0s) + pause (0.5s) = 1.5s total before flying
    Timer(const Duration(milliseconds: 1500), () {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 1000),
          pageBuilder: (_, __, ___) => const ChatScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    });
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted && prefs.containsKey('isDarkMode')) {
      setState(() {
        _isDarkMode = prefs.getBool('isDarkMode') ?? true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bgStart, _bgEnd],
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SlideTransition(
                position: _logoSlide,
                child: Hero(
                  tag: 'sai_logo',
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset("assets/icon/app_icon.png", fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              SlideTransition(
                position: _textSlide,
                child: Hero(
                  tag: 'sai_text',
                  child: Material(
                    color: Colors.transparent,
                    child: Text(
                      "S.AI",
                      style: GoogleFonts.orbitron(
                        color: _textColor,
                        fontSize: 32, // Larger in splash
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
