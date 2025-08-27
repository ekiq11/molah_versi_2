import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:mmkv/mmkv.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Import custom components
import 'package:molahv2/dialogs/topup_dialog.dart';
import 'package:molahv2/dialogs/notification_dialog.dart';
import 'package:molahv2/screens/pembayaran.dart';
import 'package:molahv2/utils/fetcher_data.dart';
import 'package:molahv2/login.dart';
import 'package:molahv2/utils/login_preferences.dart';
import 'widgets/quick_actions.dart';
import 'widgets/report_section.dart';
import 'widgets/student_info.dart';
import 'widgets/header_widget.dart';
// Import service monitoring

// ==================== MMKV LoginPreferences for HomeScreen ====================

class HomeScreen extends StatefulWidget {
  final String username;
  const HomeScreen({super.key, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  bool _isSaldoVisible = false;

  // Bottom Navigation - Updated untuk 4 tabs
  int _currentIndex = 0;

  void _toggleSaldoVisibility() {
    setState(() {
      _isSaldoVisible = !_isSaldoVisible;
    });
  }

  // Animation
  late AnimationController _animationController;
  late AnimationController _shimmerController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _shimmerAnimation;

  // Data states
  Map<String, dynamic> _santriData = {};
  Map<String, dynamic> _previousData = {};
  bool _isLoading = true;
  String _errorMessage = '';

  // Enhanced Notifications - menggunakan service baru
  ValueNotifier<List<NotificationItem>>? _enhancedNotifications;
  int get _enhancedNotificationCount =>
      _enhancedNotifications?.value.where((n) => !n.isRead).length ?? 0;

  // Legacy notifications untuk backward compatibility
  List<String> _notifications = [];

  Timer? _dataTimer;
  static const Duration _pollingInterval = Duration(minutes: 3);

  static const List<String> _csvUrls = [
    'https://docs.google.com/spreadsheets/d/1BZbBczH2OY8SB2_1tDpKf_B8WvOyk8TJl4esfT-dgzw/export?format=csv&gid=1307491664',
    'https://docs.google.com/spreadsheets/d/1BZbBczH2OY8SB2_1tDpKf_B8WvOyk8TJl4esfT-dgzw/export?format=csv',
  ];

  static const Map<String, String> _fieldNames = {
    'saldo': 'Saldo',
    'status_izin': 'Status Perizinan',
    'jumlah_hafalan': 'Jumlah Hafalan',
    'absensi': 'Absensi',
    'poin_pelanggaran': 'Poin Pelanggaran',
    'reward': 'Reward',
    'lembaga': 'Lembaga',
    'izin_terakhir': 'Izin Terakhir',
  };

  MMKV? _mmkv;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _shimmerController.stop();
    _animationController.dispose();
    _shimmerController.dispose();
    _dataTimer?.cancel();

    // Cleanup enhanced notifications service
    GoogleSheetsMonitorService.cleanupForUser(widget.username);

    super.dispose();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeApp() async {
    try {
      _initializeAnimation();
      await _initializeMMKV();

      // Initialize enhanced notifications service
      await GoogleSheetsMonitorService.initializeForUser(widget.username);
      _enhancedNotifications =
          GoogleSheetsMonitorService.getNotificationsForUser(widget.username);

      await _loadCachedData();
      await _fetchSantriData();
      _startPolling();
    } catch (e) {
      debugPrint('Error initializing app: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat data';
        });
      }
    }
  }

  Future<void> _initializeMMKV() async {
    try {
      MMKV.initialize();
      _mmkv = MMKV.defaultMMKV();
      debugPrint('✅ MMKV initialized in HomeScreen');
    } catch (e) {
      debugPrint('❌ Error initializing MMKV in HomeScreen: $e');
      _mmkv = null;
    }
  }

  Future<void> _loadCachedData() async {
    if (_mmkv == null) return;

    try {
      final cachedDataKey = 'santri_${widget.username}';
      final cachedData = _mmkv!.decodeString(cachedDataKey) ?? '';

      if (cachedData.isNotEmpty) {
        final decodedData = json.decode(cachedData) as Map<String, dynamic>;
        _previousData = Map<String, dynamic>.from(decodedData);

        if (mounted) {
          setState(() {
            _santriData = Map<String, dynamic>.from(_previousData);
            _isLoading = false;
          });
        }
        _animationController.forward();
      }

      // Load legacy notifications untuk backward compatibility
      final notificationsKey = 'notifications_${widget.username}';
      final cachedNotificationsStr =
          _mmkv!.decodeString(notificationsKey) ?? '';

      if (cachedNotificationsStr.isNotEmpty) {
        try {
          final cachedNotifications =
              json.decode(cachedNotificationsStr) as List<dynamic>;
          _notifications = cachedNotifications
              .map((e) => e.toString())
              .toList();
        } catch (e) {
          debugPrint('Error parsing cached notifications: $e');
        }
      }

      if (_santriData.isEmpty && _isLoading) {
        _shimmerController.repeat();
      }
    } catch (e) {
      debugPrint('Error loading cached data from MMKV: $e');
      if (_isLoading) {
        _shimmerController.repeat();
      }
    }
  }

  void _startPolling() {
    _dataTimer?.cancel();
    _dataTimer = Timer.periodic(_pollingInterval, (_) {
      if (mounted) {
        _fetchSantriData(silent: true);
      }
    });
  }

  Future<void> _fetchSantriData({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isLoading = true);
      if (!_shimmerController.isAnimating) {
        _shimmerController.repeat();
      }
    }

    print('🌐 Starting data fetch for username: ${widget.username}');

    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(Duration(seconds: 5));
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        throw Exception('No internet connection');
      }
    } catch (e) {
      print('❌ Internet connectivity check failed: $e');
      await _handleFetchError('Tidak ada koneksi internet', silent);
      return;
    }

    for (int urlIndex = 0; urlIndex < _csvUrls.length; urlIndex++) {
      final csvUrl = _csvUrls[urlIndex];
      print('🔗 Trying CSV URL ${urlIndex + 1}: $csvUrl');

      try {
        final response = await http
            .get(
              Uri.parse(csvUrl),
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                'Accept': 'text/csv,application/csv,text/plain,*/*',
                'Accept-Language': 'en-US,en;q=0.9,id;q=0.8',
                'Accept-Encoding': 'gzip, deflate, br',
                'Connection': 'keep-alive',
                'Cache-Control': 'no-cache',
                'Pragma': 'no-cache',
              },
            )
            .timeout(const Duration(seconds: 20));

        print('📡 Response Status: ${response.statusCode}');
        print('📡 Response Headers: ${response.headers}');
        print('📄 Response Body Length: ${response.body.length}');

        if (response.statusCode == 200 && response.body.isNotEmpty) {
          if (response.body.toLowerCase().contains('error') ||
              response.body.toLowerCase().contains('<html>')) {
            print('⚠️ Invalid CSV content detected, trying next URL...');
            continue;
          }

          print(
            '📄 CSV Preview (first 200 chars): ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...',
          );

          final csvData = const CsvToListConverter().convert(response.body);

          if (csvData.isNotEmpty) {
            print('📊 CSV parsed successfully: ${csvData.length} rows');
            print('📊 CSV headers: ${csvData[0]}');

            final newData = _parseCSV(csvData);

            if (newData.isNotEmpty) {
              print('✅ Data parsing successful for user: ${widget.username}');
              await _processNewData(newData);
              return;
            } else {
              print('⚠️ No data found for username: ${widget.username}');
            }
          } else {
            print('⚠️ CSV data is empty');
          }
        } else {
          print(
            '❌ Invalid response - Status: ${response.statusCode}, Body length: ${response.body.length}',
          );
        }
      } catch (e) {
        print('❌ Error with URL ${urlIndex + 1}: $e');
      }
    }

    print('⚠️ All CSV URLs failed, trying fallback methods...');
    await _tryFallbackMethods(silent);
  }

  Future<void> _tryFallbackMethods(bool silent) async {
    try {
      print('🔄 Trying DataFetcher fallback...');
      final dataFetcher = DataFetcher();
      final fallbackData = await dataFetcher.fetchSantriData(widget.username);

      if (fallbackData.isNotEmpty) {
        print('✅ Fallback data fetcher successful');
        await _processNewData(fallbackData);
        return;
      }
    } catch (fallbackError) {
      print('❌ Fallback fetch error: $fallbackError');
    }

    await _handleFetchError('Semua sumber data gagal diakses', silent);
  }

  Map<String, dynamic> _parseCSV(List<List<dynamic>> csvData) {
    try {
      if (csvData.isEmpty) {
        print('❌ CSV data is empty');
        return {};
      }

      final headers = csvData[0]
          .map((e) => e.toString().toLowerCase().trim().replaceAll(' ', '_'))
          .toList();

      print('📊 Processed headers: $headers');

      final nisnIndex = _findColumnIndex(headers, [
        'nisn',
        'no_induk',
        'id',
        'student_id',
        'nomor_induk',
        'kode_santri',
        'username',
        'user_id',
        'santri_id',
      ]);

      if (nisnIndex == -1) {
        print('❌ NISN column not found in headers: $headers');
        return {};
      }

      print('✅ NISN column found at index: $nisnIndex');

      for (int i = 1; i < csvData.length; i++) {
        final row = csvData[i];

        if (row.length > nisnIndex) {
          final csvNisn = row[nisnIndex]?.toString().trim() ?? '';

          print(
            '🔍 Checking row $i: CSV NISN="$csvNisn", Target="${widget.username}"',
          );

          if (_isMatchingUser(widget.username, csvNisn)) {
            print('✅ Match found for user: ${widget.username}');
            return _extractUserData(row, headers);
          }
        }
      }

      print('❌ No matching user found for: ${widget.username}');
      return {};
    } catch (e) {
      print('❌ CSV parse error: $e');
      return {};
    }
  }

  bool _isMatchingUser(String targetUsername, String csvValue) {
    if (targetUsername.isEmpty || csvValue.isEmpty) return false;

    final cleanTarget = targetUsername.toLowerCase().trim();
    final cleanCsv = csvValue.toLowerCase().trim();

    if (cleanTarget == cleanCsv) return true;

    final numericTarget = cleanTarget.replaceAll(RegExp(r'[^0-9]'), '');
    final numericCsv = cleanCsv.replaceAll(RegExp(r'[^0-9]'), '');

    if (numericTarget.isNotEmpty && numericCsv.isNotEmpty) {
      final normalizedTarget = numericTarget.replaceAll(RegExp(r'^0+'), '');
      final normalizedCsv = numericCsv.replaceAll(RegExp(r'^0+'), '');

      if (normalizedTarget.isNotEmpty && normalizedCsv.isNotEmpty) {
        return normalizedTarget == normalizedCsv;
      }
    }

    if (cleanTarget.length > 3 && cleanCsv.length > 3) {
      return cleanTarget.contains(cleanCsv) || cleanCsv.contains(cleanTarget);
    }

    return false;
  }

  Map<String, dynamic> _extractUserData(
    List<dynamic> row,
    List<String> headers,
  ) {
    return {
      'nisn': widget.username,
      'nama': _getFieldValue(row, headers, [
        'nama',
        'name',
        'student_name',
        'nama_santri',
        'nama_lengkap',
      ], 'Santri'),
      'saldo': _formatSaldo(
        _getFieldValue(row, headers, [
          'saldo',
          'balance',
          'uang',
          'money',
          'tabungan',
        ], '0'),
      ),
      'kelas': _getFieldValue(row, headers, [
        'kelas',
        'class',
        'tingkat',
        'level',
      ], '-'),
      'asrama': _getFieldValue(row, headers, [
        'asrama',
        'dormitory',
        'dorm',
        'kamar',
      ], '-'),
      'status_izin': _getFieldValue(row, headers, [
        'status_izin',
        'izin',
        'permission',
        'status',
      ], 'Sedang Dipondok'),
      'jumlah_hafalan': _getFieldValue(row, headers, [
        'hafalan',
        'memorization',
        'jumlah_hafalan',
        'juz',
      ], '0 JUZ'),
      'absensi': _getFieldValue(row, headers, [
        'absensi',
        'attendance',
        'kehadiran',
      ], 'Belum dimulai'),
      'poin_pelanggaran': _getFieldValue(row, headers, [
        'poin',
        'penalty',
        'pelanggaran',
        'violation',
      ], '0'),
      'reward': _getFieldValue(row, headers, [
        'reward',
        'bonus',
        'hadiah',
      ], '0'),
      'lembaga': _getFieldValue(row, headers, [
        'lembaga',
        'institution',
        'sekolah',
      ], '-'),
      'izin_terakhir': _getFieldValue(row, headers, [
        'izin_terakhir',
        'last_permission',
        'terakhir_izin',
      ], '-'),
    };
  }

  int _findColumnIndex(List<String> headers, List<String> possibleNames) {
    for (final name in possibleNames) {
      for (int i = 0; i < headers.length; i++) {
        if (headers[i].contains(name) || name.contains(headers[i])) {
          return i;
        }
      }
    }
    return -1;
  }

  String _getFieldValue(
    List<dynamic> row,
    List<String> headers,
    List<String> fieldNames,
    String defaultValue,
  ) {
    final index = _findColumnIndex(headers, fieldNames);

    if (index >= 0 && index < row.length) {
      final value = row[index]?.toString().trim() ?? '';
      return value.isNotEmpty ? value : defaultValue;
    }

    return defaultValue;
  }

  String _formatSaldo(String saldo) {
    if (saldo.startsWith('Rp')) return saldo;

    final clean = saldo.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.isEmpty) return '0';

    final number = int.tryParse(clean) ?? 0;
    final formatted = number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return formatted;
  }

  Future<void> _processNewData(Map<String, dynamic> newData) async {
    final hasChanges = _checkChanges(newData);

    if (_shimmerController.isAnimating) {
      _shimmerController.stop();
    }

    if (mounted) {
      setState(() {
        _santriData = Map<String, dynamic>.from(newData);
        _isLoading = false;
        _errorMessage = '';
      });

      if (!_animationController.isCompleted) {
        _animationController.forward();
      }
    }

    if (hasChanges && mounted) {
      _showUpdateSnackBar();
    }

    await _saveData(newData);
  }

  bool _checkChanges(Map<String, dynamic> newData) {
    if (_previousData.isEmpty) {
      _previousData = Map<String, dynamic>.from(newData);
      return false;
    }

    List<String> changes = [];
    for (final entry in _fieldNames.entries) {
      final oldValue = _previousData[entry.key]?.toString() ?? '';
      final newValue = newData[entry.key]?.toString() ?? '';

      if (oldValue != newValue && oldValue.isNotEmpty) {
        changes.add('${entry.value}: $oldValue → $newValue');
      }
    }

    if (changes.isNotEmpty) {
      _notifications.addAll(changes);
      if (_notifications.length > 20) {
        _notifications = _notifications.sublist(_notifications.length - 20);
      }
      _previousData = Map<String, dynamic>.from(newData);
      return true;
    }
    return false;
  }

  void _showUpdateSnackBar() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Data berhasil diperbarui'),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Lihat',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _currentIndex = 1;
            });
          },
        ),
      ),
    );
  }

  Future<void> _saveData(Map<String, dynamic> data) async {
    if (_mmkv == null) return;

    try {
      final dataKey = 'santri_${widget.username}';
      _mmkv!.encodeString(dataKey, json.encode(data));

      final notificationsKey = 'notifications_${widget.username}';
      _mmkv!.encodeString(notificationsKey, json.encode(_notifications));

      final timestampKey = 'last_update_${widget.username}';
      _mmkv!.encodeInt(timestampKey, DateTime.now().millisecondsSinceEpoch);

      debugPrint('✅ Data saved to MMKV successfully');
    } catch (e) {
      debugPrint('❌ Error saving data to MMKV: $e');
    }
  }

  Future<void> _handleFetchError(dynamic error, bool silent) async {
    debugPrint('❌ Fetch error: $error');

    if (_shimmerController.isAnimating) {
      _shimmerController.stop();
    }

    String errorMessage = 'Gagal memuat data';

    if (error.toString().contains('internet') ||
        error.toString().contains('connection')) {
      errorMessage = 'Tidak ada koneksi internet';
    } else if (error.toString().contains('timeout')) {
      errorMessage = 'Koneksi timeout, coba lagi nanti';
    } else if (error.toString().contains('sumber data')) {
      errorMessage = 'Sumber data sedang tidak tersedia';
    }

    if (mounted) {
      if (_santriData.isEmpty) {
        setState(() {
          _santriData = {
            'nisn': widget.username,
            'nama': 'Data tidak ditemukan',
            'saldo': '0',
            'status_izin': 'Sedang Dipondok',
            'jumlah_hafalan': '0 JUZ',
            'absensi': 'Belum dimulai',
            'kelas': '-',
            'asrama': '-',
            'poin_pelanggaran': '0',
            'reward': '0',
            'lembaga': '-',
            'izin_terakhir': '-',
          };
          _isLoading = false;
          _errorMessage = silent ? '' : errorMessage;
        });
        _animationController.forward();
      } else {
        setState(() {
          _errorMessage = silent
              ? ''
              : 'Menggunakan data tersimpan - $errorMessage';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _clearNotifications() async {
    setState(() => _notifications.clear());

    if (_mmkv != null) {
      try {
        final notificationsKey = 'notifications_${widget.username}';
        _mmkv!.encodeString(notificationsKey, json.encode([]));
      } catch (e) {
        debugPrint('Error clearing notifications in MMKV: $e');
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      debugPrint('🚪 Starting MMKV logout process...');

      _dataTimer?.cancel();
      debugPrint('✅ Timer cancelled');

      // Cleanup enhanced notifications service
      await GoogleSheetsMonitorService.cleanupForUser(widget.username);

      await LoginPreferences.clearAllUserData(widget.username);
      debugPrint('📱 MMKV Clear data executed');

      if (_mmkv != null) {
        debugPrint(
          '⚠️ LoginPreferences clear failed, trying direct MMKV method...',
        );

        try {
          final keysToRemove = [
            'user_logged_in',
            'user_username',
            'user_data_json',
            'user_login_time',
            'santri_${widget.username}',
            'notifications_${widget.username}',
            'last_update_${widget.username}',
            'notifications_enhanced_${widget.username}',
          ];

          for (final key in keysToRemove) {
            if (_mmkv!.containsKey(key)) {
              _mmkv!.removeValue(key);
            }
          }

          debugPrint('🗑️ Direct MMKV clear completed');
        } catch (e) {
          debugPrint('❌ Error during direct MMKV logout: $e');
        }
      }

      await Future.delayed(Duration(milliseconds: 200));
      final isStillLoggedIn = await LoginPreferences.isLoggedIn();
      debugPrint(
        '🔍 MMKV Logout verification - still logged in: $isStillLoggedIn',
      );

      if (mounted) {
        debugPrint('🔐 Navigating to LoginScreen');
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, _) => LoginScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(-1.0, 0.0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  );
                },
            transitionDuration: Duration(milliseconds: 300),
          ),
        );
      }

      debugPrint('✅ MMKV Logout process completed');
    } catch (e) {
      debugPrint('💥 MMKV Logout error: $e');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    }
  }

  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: max(20, MediaQuery.of(context).size.width * 0.1),
            vertical: max(20, MediaQuery.of(context).size.height * 0.15),
          ),
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon logout
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.logout, size: 40, color: Colors.red),
                ),
                SizedBox(height: 20),

                // Judul
                Text(
                  "Keluar Aplikasi",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),

                // Pesan konfirmasi
                Text(
                  "Apakah Anda yakin ingin keluar dari akun ${widget.username}?",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                SizedBox(height: 24),

                // Tombol aksi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Tombol batal
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: BorderSide(color: Colors.grey),
                        ),
                        child: Text(
                          "Batal",
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),

                    // Tombol logout
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Tutup dialog
                          _handleLogout(); // Jalankan proses logout
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          "Keluar",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Panggil fungsi ini sebagai ganti langsung memanggil _handleLogout()
  // Misalnya, dari sebuah tombol logout

  void _showTopUpDialog() {
    TopUpDialog.show(
      context: context,
      currentBalance: _santriData['saldo'] ?? '0',
      nisn: widget.username,
    );
  }

  void _showEnhancedNotificationDialog() {
    EnhancedNotificationDialog.show(
      context: context,
      username: widget.username,
      onClearAll: () {
        // Refresh UI setelah clear notifications
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Future<void> _handleRefresh() async {
    await _fetchSantriData();
    // Force check enhanced notifications
    await GoogleSheetsMonitorService.forceCheckForUser(widget.username);
  }

  void _onBottomNavTap(int index) {
    switch (index) {
      case 0:
        // Home tab
        setState(() {
          _currentIndex = 0;
        });
        break;
      case 1:
        // Notification tab
        setState(() {
          _currentIndex = 1;
        });
        break;
      case 2:
        // Payment tab - NEW
        setState(() {
          _currentIndex = 2;
        });
        break;
      case 3:
        // Logout
        _showLogoutDialog();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            // Home Tab
            _isLoading && _santriData.isEmpty
                ? _buildLoadingState()
                : _buildMainContent(),
            // Notification Tab - Enhanced
            _buildEnhancedNotificationPage(),
            // Payment Tab - NEW
            PaymentPage(
              username: widget.username,
              studentName: _santriData['nama'] ?? 'Santri',
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex > 2 ? 0 : _currentIndex,
          onTap: _onBottomNavTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.red[600],
          unselectedItemColor: Colors.grey[500],
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications),
                  if (_enhancedNotificationCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          '$_enhancedNotificationCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              activeIcon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_active),
                  if (_enhancedNotificationCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          '$_enhancedNotificationCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Notifikasi',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.payment),
              activeIcon: Icon(Icons.payment),
              label: 'Pembayaran',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.logout, color: Colors.grey),
              activeIcon: Icon(Icons.logout, color: Colors.red[600]),
              label: 'Keluar',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          color: Colors.red[400],
          onRefresh: _handleRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: CombinedHeader(
                    santriData: _santriData,
                    notificationCount: _enhancedNotificationCount,
                    onNotificationTap: _showEnhancedNotificationDialog,
                    onLogoutTap: _showLogoutDialog,
                    saldo: _santriData['saldo'] ?? '0',
                    onTopUpTap: _showTopUpDialog,
                    isSaldoVisible: _isSaldoVisible,
                    onToggleSaldoVisibility: _toggleSaldoVisibility,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (_errorMessage.isNotEmpty) ...[
                        _buildErrorBanner(),
                        const SizedBox(height: 16),
                      ],
                      QuickActions(nisn: widget.username),
                      const SizedBox(height: 24),
                      _buildReportSection(),
                      const SizedBox(height: 20),
                      _buildStudentInfo(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedNotificationPage() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: ValueListenableBuilder<List<NotificationItem>>(
          valueListenable: _enhancedNotifications ?? ValueNotifier([]),
          builder: (context, notifications, child) {
            final unreadCount = notifications.where((n) => !n.isRead).length;
            return Row(
              children: [
                Icon(Icons.notifications_active, color: Colors.red[600]),
                const SizedBox(width: 12),
                Text('Notifikasi ($unreadCount baru)'),
              ],
            );
          },
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        centerTitle: false,
        actions: [
          ValueListenableBuilder<List<NotificationItem>>(
            valueListenable: _enhancedNotifications ?? ValueNotifier([]),
            builder: (context, notifications, child) {
              if (notifications.isNotEmpty) {
                return TextButton(
                  onPressed: () async {
                    await GoogleSheetsMonitorService.clearAllNotificationsForUser(
                      widget.username,
                    );
                    if (mounted) setState(() {});
                  },
                  child: Text(
                    'Hapus Semua',
                    style: TextStyle(
                      color: Colors.red[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<List<NotificationItem>>(
        valueListenable: _enhancedNotifications ?? ValueNotifier([]),
        builder: (context, notifications, child) {
          if (notifications.isEmpty) {
            return _buildEmptyNotifications();
          }
          return _buildEnhancedNotificationList(notifications);
        },
      ),
    );
  }

  Widget _buildEmptyNotifications() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Tidak ada notifikasi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Perubahan data akan muncul di sini',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedNotificationList(List<NotificationItem> notifications) {
    return RefreshIndicator(
      color: Colors.red[400],
      onRefresh: _handleRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: notification.isRead ? Colors.white : Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: notification.isRead
                    ? Colors.grey[200]!
                    : Colors.blue[200]!,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: InkWell(
              onTap: () {
                GoogleSheetsMonitorService.markAsReadForUser(
                  widget.username,
                  notification.id,
                );
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: notification.isRead
                          ? Colors.grey[100]
                          : Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      notification.isRead ? Icons.info_outline : Icons.info,
                      color: notification.isRead
                          ? Colors.grey[600]
                          : Colors.blue[600],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (!notification.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                margin: EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.blue[400],
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                            Text(
                              _formatTimestamp(notification.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.message,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sumber: ${notification.sheetName}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Baru saja';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}j';
    } else {
      return '${difference.inDays}h';
    }
  }

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _buildHeaderShimmer(),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildQuickActionsShimmer(),
                const SizedBox(height: 24),
                _buildReportShimmer(),
                const SizedBox(height: 20),
                _buildStudentInfoShimmer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerContainer({
    required double width,
    required double height,
    double borderRadius = 8,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: Colors.grey[300],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: AnimatedBuilder(
          animation: _shimmerAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.grey[300]!,
                    Colors.grey[100]!,
                    Colors.grey[300]!,
                  ],
                  stops: [0.0, 0.5, 1.0],
                  transform: GradientRotation(_shimmerAnimation.value * 0.3),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderShimmer() {
    final screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 360;

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 20 : 24,
        horizontal: isSmallScreen ? 20 : 24,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildShimmerContainer(
                width: isSmallScreen ? 50 : 56,
                height: isSmallScreen ? 50 : 56,
                borderRadius: 16,
              ),
              SizedBox(width: isSmallScreen ? 16 : 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShimmerContainer(
                      width: 120,
                      height: isSmallScreen ? 13 : 14,
                      borderRadius: 6,
                    ),
                    const SizedBox(height: 4),
                    _buildShimmerContainer(
                      width: 180,
                      height: isSmallScreen ? 18 : 20,
                      borderRadius: 8,
                    ),
                    const SizedBox(height: 2),
                    _buildShimmerContainer(
                      width: 140,
                      height: isSmallScreen ? 13 : 14,
                      borderRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 24 : 28),
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 18 : 22),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildShimmerContainer(
                        width: 100,
                        height: isSmallScreen ? 12 : 13,
                        borderRadius: 6,
                      ),
                      const SizedBox(height: 8),
                      _buildShimmerContainer(
                        width: 160,
                        height: isSmallScreen ? 22 : 26,
                        borderRadius: 10,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _buildShimmerContainer(
                  width: isSmallScreen ? 32 : 36,
                  height: isSmallScreen ? 32 : 36,
                  borderRadius: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsShimmer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShimmerContainer(width: 120, height: 20, borderRadius: 10),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              4,
              (index) => Column(
                children: [
                  _buildShimmerContainer(
                    width: 50,
                    height: 50,
                    borderRadius: 25,
                  ),
                  const SizedBox(height: 8),
                  _buildShimmerContainer(
                    width: 60,
                    height: 12,
                    borderRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportShimmer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShimmerContainer(width: 100, height: 20, borderRadius: 10),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildShimmerContainer(
                      width: double.infinity,
                      height: 16,
                      borderRadius: 8,
                    ),
                    const SizedBox(height: 8),
                    _buildShimmerContainer(
                      width: 80,
                      height: 24,
                      borderRadius: 12,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _buildShimmerContainer(
                      width: double.infinity,
                      height: 16,
                      borderRadius: 8,
                    ),
                    const SizedBox(height: 8),
                    _buildShimmerContainer(
                      width: 80,
                      height: 24,
                      borderRadius: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentInfoShimmer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShimmerContainer(width: 120, height: 20, borderRadius: 10),
          const SizedBox(height: 16),
          ...List.generate(
            4,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildShimmerContainer(
                    width: 100,
                    height: 16,
                    borderRadius: 8,
                  ),
                  _buildShimmerContainer(
                    width: 80,
                    height: 16,
                    borderRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber[700], size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage,
              style: TextStyle(
                color: Colors.amber[800],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportSection() {
    return ReportSection(santriData: _santriData);
  }

  Widget _buildStudentInfo() {
    return StudentInfo(santriData: _santriData);
  }
}
