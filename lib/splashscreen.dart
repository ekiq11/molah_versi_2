// splashscreen.dart - Fixed Version
import 'package:flutter/material.dart';
import 'package:molahv2/home.dart';
import 'package:molahv2/login.dart';
import 'package:molahv2/utils/login_preferences.dart';
import 'package:mmkv/mmkv.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;

  String _statusMessage = 'Memulai aplikasi...';

  @override
  void initState() {
    super.initState();
    _initAnimations();

    // Debug: Check MMKV status immediately
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final mmkv = MMKV.defaultMMKV();
        print('🔍 MMKV Debug - All keys: ${mmkv?.allKeys}');
        print('🔍 MMKV Debug - Count: ${mmkv?.count}');
      } catch (e) {
        print('❌ MMKV Debug error: $e');
      }
    });

    _initializeApp();
  }

  void _initAnimations() {
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _logoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _textAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      _textController.forward();
    });
  }

  // Di dalam class _SplashScreenState
  Future<void> _debugMMKVState() async {
    try {
      final mmkv = MMKV.defaultMMKV();
      if (mmkv == null) {
        print('❌ MMKV instance is null in debug');
        return;
      }

      print('🔍 MMKV DEBUG - All keys: ${mmkv.allKeys}');
      print('🔍 MMKV DEBUG - Total count: ${mmkv.count}');

      // Check semua key login
      final keys = [
        'user_logged_in',
        'user_username',
        'user_login_time',
        'user_data_json',
      ];
      for (final key in keys) {
        if (mmkv.containsKey(key)) {
          if (key == 'user_logged_in') {
            final value = mmkv.decodeBool(key, defaultValue: false);
            print('🔍 MMKV DEBUG - $key: $value');
          } else {
            final value = mmkv.decodeString(key) ?? 'NULL';
            print('🔍 MMKV DEBUG - $key: "$value"');
          }
        } else {
          print('🔍 MMKV DEBUG - $key: NOT FOUND');
        }
      }
    } catch (e) {
      print('❌ MMKV debug error: $e');
    }
  }

  Future<void> _initializeApp() async {
    try {
      _updateStatus('Menginisialisasi aplikasi...');

      // Tunggu minimal 2 detik untuk animasi dan inisialisasi
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      _updateStatus('Memeriksa status login...');
      await _debugMMKVState();
      // Gunakan LoginPreferences yang sudah ada
      final isLoggedIn = await LoginPreferences.isLoggedIn();
      final username = await LoginPreferences.getUsername();

      debugPrint(
        '🔍 Login check result: isLoggedIn=$isLoggedIn, username="$username"',
      );

      if (!mounted) return;

      if (isLoggedIn && username != null && username.isNotEmpty) {
        _updateStatus('Selamat datang kembali, $username!');
        await Future.delayed(const Duration(milliseconds: 800));

        if (mounted) {
          _navigateToHome(username);
        }
      } else {
        _updateStatus('Silakan login...');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          _navigateToLogin();
        }
      }
    } catch (e) {
      debugPrint('💥 Initialization error: $e');
      if (mounted) {
        _navigateToLogin();
      }
    }
  }

  void _updateStatus(String message) {
    if (mounted) {
      setState(() {
        _statusMessage = message;
      });
      debugPrint('📱 Status: $message');
    }
  }

  void _navigateToHome(String username) {
    debugPrint('🏠 Navigating to HomeScreen for: $username');

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen(username: username)),
    );
  }

  void _navigateToLogin() {
    debugPrint('🔐 Navigating to LoginScreen');

    if (!mounted) return;

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen()));
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE53E3E), Color(0xFFD53F8C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _logoAnimation,
                  builder: (context, child) => Transform.scale(
                    scale: _logoAnimation.value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.school,
                        size: 50,
                        color: Color(0xFFE53E3E),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedBuilder(
                  animation: _textAnimation,
                  builder: (context, child) => Opacity(
                    opacity: _textAnimation.value,
                    child: Column(
                      children: const [
                        Text(
                          'MOLAH',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Aplikasi Monitoring Santri',
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusMessage,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Text(
                    'MOLAH v1.0.0 - Powered by Pizab',
                    style: TextStyle(fontSize: 10, color: Colors.white54),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
