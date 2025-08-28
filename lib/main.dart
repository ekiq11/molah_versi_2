// ====================
// 1. MAIN.DART - Perbaikan Inisialisasi
// ====================
import 'package:flutter/material.dart';
import 'package:mmkv/mmkv.dart';
import 'splashscreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 App starting...');

  try {
    await MMKV.initialize();
    print('✅ MMKV initialized successfully');

    // Test MMKV immediately
    final mmkv = MMKV.defaultMMKV();
    mmkv?.encodeBool('startup_test', true);
    final test = mmkv?.decodeBool('startup_test', defaultValue: false);
    print('🔍 MMKV startup test: $test');
  } catch (e) {
    print('❌ MMKV init failed: $e');
  }

  print('🚀 Running app...');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MOLAH',
      theme: ThemeData(primarySwatch: Colors.red),
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
