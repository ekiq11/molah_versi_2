// main.dart
import 'package:flutter/material.dart';
import 'package:mmkv/mmkv.dart';
import 'splashscreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await MMKV.initialize(); // ✅ Ini harus selesai dulu
    print("✅ MMKV initialized di main.dart");
  } catch (e) {
    print("❌ MMKV gagal init: $e");
  }

  // ✅ Hanya jalankan app setelah MMKV siap
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MOLAH',
      theme: ThemeData(primarySwatch: Colors.red),
      home: SplashScreen(), // langsung splash
      debugShowCheckedModeBanner: false,
    );
  }
}
