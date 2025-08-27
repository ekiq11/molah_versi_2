import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:molahv2/home.dart';
import 'package:molahv2/utils/login_preferences.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';

// ==================== Login Screen ====================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showPassword = false;

  // CSV URLs
  static const String SPREADSHEET_ID =
      '1BZbBczH2OY8SB2_1tDpKf_B8WvOyk8TJl4esfT-dgzw';
  static const String SHEET_ID = '1307491664';
  static const String csvUrl =
      'https://docs.google.com/spreadsheets/d/$SPREADSHEET_ID/export?format=csv&gid=$SHEET_ID';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ✅ Initialize app and check MMKV health
  Future<void> _initializeApp() async {
    try {
      // Check MMKV health first
      final isHealthy = await LoginPreferences.checkHealth();
      if (!isHealthy) {
        print('⚠️ MMKV health check failed, but continuing...');
      }

      // Check existing login
      await _checkExistingLogin();
    } catch (e) {
      print('❌ Error initializing app: $e');
    }
  }

  // ✅ CHECK EXISTING LOGIN - Updated for MMKV
  Future<void> _checkExistingLogin() async {
    try {
      final isLoggedIn = await LoginPreferences.isLoggedIn();

      if (isLoggedIn) {
        final username = await LoginPreferences.getUsername();

        if (username != null && mounted) {
          print('✅ User already logged in: $username');

          // Navigate to home screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => HomeScreen(username: username)),
          );
        }
      }
    } catch (e) {
      print('❌ Error checking existing login: $e');
    }
  }

  // Validate credentials method (same as original)
  Future<Map<String, dynamic>?> _validateCredentials(
    String username,
    String password,
  ) async {
    try {
      print(
        '🔍 Memvalidasi kredensial: username="$username", password="$password"',
      );

      // Mode testing tetap
      if (username == "123456" && password == "123456") {
        print('✅ MODE TEST: Menggunakan kredensial test');
        return {'nisn': 'test', 'nama': 'Test User', 'nis': 'test'};
      }

      // Cek koneksi internet
      try {
        final result = await InternetAddress.lookup('google.com');
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          throw Exception('Tidak ada koneksi internet');
        }
      } catch (e) {
        throw Exception('Tidak ada koneksi internet');
      }

      print('🌐 Mengambil data dari: $csvUrl');

      final response = await http
          .get(
            Uri.parse(csvUrl),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'Accept': '*/*',
            },
          )
          .timeout(const Duration(seconds: 15));

      print('📡 Status respons HTTP: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('Gagal mengambil data. Status: ${response.statusCode}');
      }

      if (response.body.isEmpty) {
        throw Exception('Data kosong dari server');
      }

      print('📄 Panjang data CSV: ${response.body.length} karakter');

      // Parse CSV
      final csvData = const CsvToListConverter().convert(response.body);
      print('📊 CSV berhasil diparsing: ${csvData.length} baris');

      if (csvData.isEmpty) {
        throw Exception('Data CSV kosong');
      }

      // Tampilkan header untuk debugging
      final headers = csvData[0]
          .map((e) => e.toString().toLowerCase().trim())
          .toList();
      print('📊 Header CSV ditemukan: $headers');

      // Cari kolom NISN dan NIS dengan lebih fleksibel
      int nisnIndex = -1;
      int nisIndex = -1;

      // Pattern untuk mencari kolom NISN
      final nisnPatterns = [
        'nisn',
        'no_induk',
        'id',
        'student_id',
        'nomor_induk',
        'kode_santri',
      ];
      for (final pattern in nisnPatterns) {
        nisnIndex = headers.indexWhere((h) => h.contains(pattern));
        if (nisnIndex != -1) {
          print(
            '✅ Kolom NISN ditemukan di index $nisnIndex dengan pattern: $pattern',
          );
          break;
        }
      }

      // Pattern untuk mencari kolom NIS (password)
      final nisPatterns = ['nis', 'password', 'pass', 'pwd', 'kode', 'pin'];
      for (final pattern in nisPatterns) {
        nisIndex = headers.indexWhere((h) => h.contains(pattern));
        if (nisIndex != -1) {
          print(
            '✅ Kolom NIS ditemukan di index $nisIndex dengan pattern: $pattern',
          );
          break;
        }
      }

      // Fallback: gunakan index default jika tidak ditemukan
      if (nisnIndex == -1) {
        nisnIndex = 0; // Kolom pertama
        print(
          '⚠️ Kolom NISN tidak ditemukan, menggunakan kolom pertama (index 0)',
        );
      }

      if (nisIndex == -1) {
        nisIndex = 2; // Kolom ketiga
        print(
          '⚠️ Kolom NIS tidak ditemukan, menggunakan kolom ketiga (index 2)',
        );
      }

      // Cari kolom nama
      int namaIndex = -1;
      final namaPatterns = ['nama', 'name', 'student_name', 'nama_santri'];
      for (final pattern in namaPatterns) {
        namaIndex = headers.indexWhere((h) => h.contains(pattern));
        if (namaIndex != -1) {
          print('✅ Kolom nama ditemukan di index $namaIndex');
          break;
        }
      }

      if (namaIndex == -1) {
        namaIndex = 1; // Kolom kedua sebagai fallback
        print(
          '⚠️ Kolom nama tidak ditemukan, menggunakan kolom kedua (index 1)',
        );
      }

      print(
        '📊 Menggunakan index: NISN=$nisnIndex, NIS=$nisIndex, Nama=$namaIndex',
      );

      // Cari kredensial yang cocok
      for (int i = 1; i < csvData.length; i++) {
        final row = csvData[i];

        // Pastikan baris memiliki kolom yang cukup
        if (row.length <= max(max(nisnIndex, nisIndex), namaIndex)) {
          continue;
        }

        final csvNisn = row[nisnIndex]?.toString().trim() ?? '';
        final csvNis = row[nisIndex]?.toString().trim() ?? '';
        final csvNama = row[namaIndex]?.toString().trim() ?? '';

        print(
          '🔍 Baris $i - NISN: "$csvNisn", NIS: "$csvNis", Nama: "$csvNama"',
        );

        // Validasi kredensial dengan matching yang lebih fleksibel
        if (_isMatchingCredentials(username, csvNisn) &&
            _isMatchingCredentials(password, csvNis)) {
          print('✅ Kredensial cocok ditemukan untuk: $csvNama');
          return {
            'nisn': csvNisn.isNotEmpty ? csvNisn : username,
            'nama': csvNama.isNotEmpty ? csvNama : 'Santri',
            'nis': csvNis.isNotEmpty ? csvNis : password,
          };
        }
      }

      print(
        '❌ Kredensial tidak ditemukan dalam ${csvData.length - 1} baris data',
      );
      return null;
    } catch (e) {
      print('❌ Error saat validasi kredensial: $e');
      rethrow;
    }
  }

  // Method matching kredensial yang diperbaiki
  bool _isMatchingCredentials(String input, String csvValue) {
    if (input.isEmpty || csvValue.isEmpty) return false;

    final cleanInput = input.trim().toLowerCase();
    final cleanCsv = csvValue.trim().toLowerCase();

    // Exact match (case insensitive)
    if (cleanInput == cleanCsv) {
      print('✅ Exact match: "$cleanInput" == "$cleanCsv"');
      return true;
    }

    // Numeric match (hilangkan leading zeros dan spasi)
    final numericInput = cleanInput.replaceAll(RegExp(r'[^0-9]'), '');
    final numericCsv = cleanCsv.replaceAll(RegExp(r'[^0-9]'), '');

    if (numericInput.isNotEmpty && numericCsv.isNotEmpty) {
      // Hilangkan leading zeros untuk perbandingan numerik
      final normalizedInput = numericInput.replaceAll(RegExp(r'^0+'), '');
      final normalizedCsv = numericCsv.replaceAll(RegExp(r'^0+'), '');

      if (normalizedInput.isNotEmpty &&
          normalizedCsv.isNotEmpty &&
          normalizedInput == normalizedCsv) {
        print('✅ Numeric match: "$normalizedInput" == "$normalizedCsv"');
        return true;
      }
    }

    // Partial match untuk kasus tertentu
    if (cleanInput.contains(cleanCsv) || cleanCsv.contains(cleanInput)) {
      final lengthDiff = (cleanInput.length - cleanCsv.length).abs();
      if (lengthDiff <= 2) {
        // Toleransi perbedaan 2 karakter
        print('✅ Partial match: "$cleanInput" ~= "$cleanCsv"');
        return true;
      }
    }

    return false;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      print(
        '🔐 Mencoba login untuk: username="$username", password="$password"',
      );

      final userData = await _validateCredentials(username, password);

      if (userData != null) {
        print('✅ Login berhasil untuk: ${userData['nama']}');

        // Tampilkan pesan sukses
        _showMessage('Login berhasil!', isError: false);

        // Simpan data login ke MMKV
        final saveSuccess = await LoginPreferences.saveLoginData(
          username: username,
          userData: userData,
        );

        print('📱 Status penyimpanan MMKV: $saveSuccess');

        // Tunggu sebentar untuk UX
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          print('🏠 Navigasi ke HomeScreen dengan username: $username');
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => HomeScreen(username: username)),
            (route) => false,
          );
        }
      } else {
        print('❌ Kredensial tidak valid');
        _showMessage(
          'NISN atau NIS tidak valid! Periksa kembali data Anda.',
          isError: true,
        );
      }
    } catch (e) {
      print('❌ Error login: $e');
      String errorMessage = 'Terjadi kesalahan sistem!';

      if (e.toString().contains('internet') ||
          e.toString().contains('connection')) {
        errorMessage = 'Tidak ada koneksi internet! Periksa koneksi Anda.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Koneksi timeout! Coba lagi dalam beberapa saat.';
      } else if (e.toString().contains('format') ||
          e.toString().contains('parse')) {
        errorMessage = 'Format data tidak valid! Hubungi administrator.';
      }

      _showMessage(errorMessage, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6B6B), Color(0xFFE53E3E), Color(0xFFD53F8C)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Hero(
                    tag: 'app_logo',
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(40),
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
                        size: 40,
                        color: Color(0xFFE53E3E),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'MOLAH',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const Text(
                    'Monitoring Santri',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 40),
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Masuk ke Akun',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3748),
                              ),
                            ),
                            const SizedBox(height: 30),
                            // NISN Field - Numeric Input Only
                            TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                labelText: 'Username',
                                hintText: 'Masukkan Username',
                                prefixIcon: const Icon(
                                  Icons.badge,
                                  color: Color(0xFFE53E3E),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE53E3E),
                                    width: 2,
                                  ),
                                ),
                              ),
                              keyboardType:
                                  TextInputType.number, // Numeric keyboard
                              inputFormatters: [
                                FilteringTextInputFormatter
                                    .digitsOnly, // Only digits
                                LengthLimitingTextInputFormatter(
                                  12,
                                ), // Max 12 digits
                              ],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Username tidak boleh kosong';
                                }
                                if (value.trim().length < 6) {
                                  return 'Username minimal 6 digit';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // NIS Field - Numeric Input Only
                            TextFormField(
                              controller: _passwordController,
                              obscureText: !_showPassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                hintText: 'Masukkan Password',
                                prefixIcon: const Icon(
                                  Icons.key_outlined,
                                  color: Color(0xFFE53E3E),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Color(0xFFE53E3E),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _showPassword = !_showPassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE53E3E),
                                    width: 2,
                                  ),
                                ),
                              ),
                              keyboardType:
                                  TextInputType.number, // Numeric keyboard
                              inputFormatters: [
                                FilteringTextInputFormatter
                                    .digitsOnly, // Only digits
                                LengthLimitingTextInputFormatter(
                                  10,
                                ), // Max 10 digits
                              ],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Password tidak boleh kosong';
                                }
                                if (value.trim().length < 4) {
                                  return 'Password minimal 4 digit';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE53E3E),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 3,
                                ),
                                child: _isLoading
                                    ? const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text('Memuat...'),
                                        ],
                                      )
                                    : const Text(
                                        'Masuk',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: Colors.blue,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Masukkan nomor NISN sebagai username dan NIS sebagai password (hanya angka)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'MOLAH v1.0.0 - Powered by Pizab',
                    style: TextStyle(fontSize: 10, color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
