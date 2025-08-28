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

class HomeScreen extends StatefulWidget {
  final String username;
  const HomeScreen({super.key, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin,
        WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  // Core state variables
  bool _isSaldoVisible = false;
  int _currentIndex = 0;
  Map<String, dynamic> _santriData = {};
  Map<String, dynamic> _previousData = {};
  bool _isLoading = true;
  String _errorMessage = '';
  List<String> _notifications = [];

  // Controllers
  late AnimationController _animationController;
  late AnimationController _shimmerController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _shimmerAnimation;

  // Enhanced Notifications
  ValueNotifier<List<NotificationItem>>? _enhancedNotifications;
  int get _enhancedNotificationCount =>
      _enhancedNotifications?.value.where((n) => !n.isRead).length ?? 0;

  // Timers and utilities
  Timer? _dataTimer;
  Timer? _debounceTimer;
  MMKV? _mmkv;
  final _httpClient = http.Client();

  // Constants - Optimized for better performance
  static const Duration _pollingInterval = Duration(
    minutes: 5,
  ); // Increased from 3 minutes
  static const Duration _requestTimeout = Duration(
    seconds: 12,
  ); // Reduced from 20 seconds
  static const Duration _cacheValidDuration = Duration(
    minutes: 2,
  ); // Cache validity

  // Optimized CSV URLs with better error handling
  static const List<Map<String, String>> _csvSources = [
    {
      'url':
          'https://docs.google.com/spreadsheets/d/1BZbBczH2OY8SB2_1tDpKf_B8WvOyk8TJl4esfT-dgzw/export?format=csv&gid=1307491664',
      'name': 'Primary Data Source',
    },
    {
      'url':
          'https://docs.google.com/spreadsheets/d/1BZbBczH2OY8SB2_1tDpKf_B8WvOyk8TJl4esfT-dgzw/export?format=csv',
      'name': 'Secondary Data Source',
    },
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shimmerController.stop();
    _animationController.dispose();
    _shimmerController.dispose();
    _dataTimer?.cancel();
    _debounceTimer?.cancel();
    _httpClient.close();

    // Cleanup enhanced notifications service
    GoogleSheetsMonitorService.cleanupForUser(widget.username);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkCacheAndRefresh();
    } else if (state == AppLifecycleState.paused) {
      _dataTimer?.cancel();
    }
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400), // Reduced from 600ms
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1200), // Reduced from 1500ms
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(
          begin: const Offset(0.0, 0.2), // Reduced from 0.3
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutQuart, // Changed from easeOutCubic
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

      // Load cached data first for immediate display
      await _loadCachedData();

      // Initialize enhanced notifications service
      unawaited(_initializeNotifications());

      // Check if cache is still valid, if not fetch new data
      await _checkCacheAndRefresh();

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

  Future<void> _initializeNotifications() async {
    try {
      await GoogleSheetsMonitorService.initializeForUser(widget.username);
      _enhancedNotifications =
          GoogleSheetsMonitorService.getNotificationsForUser(widget.username);
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
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
      final timestampKey = 'last_update_${widget.username}';

      final cachedData = _mmkv!.decodeString(cachedDataKey) ?? '';
      final lastUpdate = _mmkv!.decodeInt(timestampKey) ?? 0;

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

        // Check cache age
        final cacheAge = DateTime.now().millisecondsSinceEpoch - lastUpdate;
        debugPrint(
          'Cache age: ${Duration(milliseconds: cacheAge).inMinutes} minutes',
        );
      }

      // Load notifications
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

  Future<void> _checkCacheAndRefresh() async {
    if (_mmkv == null) return;

    final timestampKey = 'last_update_${widget.username}';
    final lastUpdate = _mmkv!.decodeInt(timestampKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // If cache is older than valid duration, fetch new data
    if (now - lastUpdate > _cacheValidDuration.inMilliseconds) {
      await _fetchSantriData(silent: _santriData.isNotEmpty);
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
    // Debounce rapid requests
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      await _performDataFetch(silent: silent);
    });
  }

  Future<void> _performDataFetch({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isLoading = true);
      if (!_shimmerController.isAnimating) {
        _shimmerController.repeat();
      }
    }

    debugPrint(
      '🌐 Starting optimized data fetch for username: ${widget.username}',
    );

    // Quick connectivity check with reduced timeout
    try {
      final result = await InternetAddress.lookup('dns.google').timeout(
        const Duration(seconds: 3), // Reduced from 5 seconds
      );
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        throw Exception('No internet connection');
      }
    } catch (e) {
      debugPrint('❌ Internet connectivity check failed: $e');
      await _handleFetchError('Tidak ada koneksi internet', silent);
      return;
    }

    // Try CSV sources with improved error handling
    for (int sourceIndex = 0; sourceIndex < _csvSources.length; sourceIndex++) {
      final source = _csvSources[sourceIndex];
      debugPrint('🔗 Trying ${source['name']}: ${source['url']}');

      try {
        final response = await _httpClient
            .get(Uri.parse(source['url']!), headers: _getOptimizedHeaders())
            .timeout(_requestTimeout);

        debugPrint('📡 Response Status: ${response.statusCode}');

        if (response.statusCode == 200 && response.body.isNotEmpty) {
          // Quick validation
          if (_isValidCSVContent(response.body)) {
            final newData = await _processCSVResponse(response.body);
            if (newData.isNotEmpty) {
              debugPrint(
                '✅ Data parsing successful for user: ${widget.username}',
              );
              await _processNewData(newData);
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('❌ Error with ${source['name']}: $e');
        if (e.toString().contains('400')) {
          // Skip other sources if getting 400 errors
          debugPrint('⚠️ HTTP 400 detected, trying fallback methods directly');
          break;
        }
      }
    }

    debugPrint('⚠️ All CSV sources failed, trying fallback methods...');
    await _tryFallbackMethods(silent);
  }

  Map<String, String> _getOptimizedHeaders() {
    return {
      'User-Agent':
          'Mozilla/5.0 (Android 12; Mobile; rv:109.0) Gecko/109.0 Firefox/109.0',
      'Accept': 'text/csv,text/plain,*/*;q=0.8',
      'Accept-Language': 'id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7',
      'Accept-Encoding': 'gzip, deflate',
      'Connection': 'keep-alive',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
      'DNT': '1',
    };
  }

  bool _isValidCSVContent(String content) {
    if (content.length < 10) return false;
    if (content.toLowerCase().contains('<html>')) return false;
    if (content.toLowerCase().contains('error')) return false;
    if (!content.contains(',') && !content.contains(';')) return false;
    return true;
  }

  Future<Map<String, dynamic>> _processCSVResponse(String csvContent) async {
    try {
      // Process CSV in isolate for better performance with large data
      final csvData = const CsvToListConverter().convert(csvContent);

      if (csvData.isEmpty) {
        debugPrint('❌ CSV data is empty');
        return {};
      }

      return _parseCSVData(csvData);
    } catch (e) {
      debugPrint('❌ CSV processing error: $e');
      return {};
    }
  }

  Map<String, dynamic> _parseCSVData(List<List<dynamic>> csvData) {
    try {
      final headers = csvData[0]
          .map((e) => e.toString().toLowerCase().trim().replaceAll(' ', '_'))
          .toList();

      debugPrint('📊 Processed headers: $headers');

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
        debugPrint('❌ NISN column not found in headers: $headers');
        return {};
      }

      // Optimize search by checking rows more efficiently
      for (int i = 1; i < csvData.length; i++) {
        final row = csvData[i];
        if (row.length > nisnIndex) {
          final csvNisn = row[nisnIndex]?.toString().trim() ?? '';
          if (_isMatchingUser(widget.username, csvNisn)) {
            debugPrint('✅ Match found for user: ${widget.username} at row $i');
            return _extractUserData(row, headers);
          }
        }
      }

      debugPrint('❌ No matching user found for: ${widget.username}');
      return {};
    } catch (e) {
      debugPrint('❌ CSV parse error: $e');
      return {};
    }
  }

  Future<void> _tryFallbackMethods(bool silent) async {
    try {
      debugPrint('🔄 Trying DataFetcher fallback...');
      final dataFetcher = DataFetcher();
      final fallbackData = await dataFetcher
          .fetchSantriData(widget.username)
          .timeout(const Duration(seconds: 10));

      if (fallbackData.isNotEmpty) {
        debugPrint('✅ Fallback data fetcher successful');
        await _processNewData(fallbackData);
        return;
      }
    } catch (fallbackError) {
      debugPrint('❌ Fallback fetch error: $fallbackError');
    }

    await _handleFetchError('Semua sumber data gagal diakses', silent);
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
      ], 'Santri'),
      'saldo': _formatSaldo(
        _getFieldValue(row, headers, [
          'saldo',
          'balance',
          'uang',
          'money',
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
      ], 'Sedang Dipondok'),
      'jumlah_hafalan': _getFieldValue(row, headers, [
        'hafalan',
        'memorization',
        'jumlah_hafalan',
      ], '0'),
      'absensi': _getFieldValue(row, headers, [
        'absensi',
        'attendance',
        'kehadiran',
      ], 'Belum dimulai'),
      'poin_pelanggaran': _getFieldValue(row, headers, [
        'poin',
        'penalty',
        'pelanggaran',
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
          onPressed: () => setState(() => _currentIndex = 1),
        ),
      ),
    );
  }

  Future<void> _saveData(Map<String, dynamic> data) async {
    if (_mmkv == null) return;

    try {
      final dataKey = 'santri_${widget.username}';
      final notificationsKey = 'notifications_${widget.username}';
      final timestampKey = 'last_update_${widget.username}';

      await Future.wait([
        Future(() => _mmkv!.encodeString(dataKey, json.encode(data))),
        Future(
          () => _mmkv!.encodeString(
            notificationsKey,
            json.encode(_notifications),
          ),
        ),
        Future(
          () => _mmkv!.encodeInt(
            timestampKey,
            DateTime.now().millisecondsSinceEpoch,
          ),
        ),
      ]);

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
    } else if (error.toString().contains('400')) {
      errorMessage = 'Server sedang bermasalah';
    }

    if (mounted) {
      if (_santriData.isEmpty) {
        setState(() {
          _santriData = _getDefaultData();
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

  Map<String, dynamic> _getDefaultData() {
    return {
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
  }

  void _toggleSaldoVisibility() {
    setState(() {
      _isSaldoVisible = !_isSaldoVisible;
    });
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
      debugPrint('🚪 Starting optimized logout process...');

      _dataTimer?.cancel();
      _debounceTimer?.cancel();

      await GoogleSheetsMonitorService.cleanupForUser(widget.username);
      await LoginPreferences.clearAllUserData(widget.username);

      if (_mmkv != null) {
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
      }

      if (mounted) {
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
            transitionDuration: const Duration(milliseconds: 250),
          ),
        );
      }

      debugPrint('✅ Optimized logout process completed');
    } catch (e) {
      debugPrint('💥 Logout error: $e');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    }
  }

  Future<void> _showLogoutDialog() async {
    final screenSize = MediaQuery.of(context).size;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: max(20, screenSize.width * 0.1),
            vertical: max(20, screenSize.height * 0.15),
          ),
          child: Container(
            padding: EdgeInsets.all(screenSize.width * 0.06),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(screenSize.width * 0.04),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout,
                    size: screenSize.width * 0.1,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: screenSize.height * 0.025),
                Text(
                  "Keluar Aplikasi",
                  style: TextStyle(
                    fontSize: screenSize.width * 0.04,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: screenSize.height * 0.03),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: screenSize.height * 0.015,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: BorderSide(color: Colors.grey),
                        ),
                        child: Text(
                          "Batal",
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: screenSize.width * 0.035,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: screenSize.width * 0.04),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _handleLogout();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(
                            vertical: screenSize.height * 0.015,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          "Keluar",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenSize.width * 0.035,
                          ),
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

  void _showTopUpDialog() {
    TopUpDialog.show(
      context: context,
      currentBalance: _santriData['saldo'] ?? '0',
      nisn: widget.username,
      namaSantri: _santriData['nama'],
    );
  }

  void _showEnhancedNotificationDialog() {
    EnhancedNotificationDialog.show(
      context: context,
      username: widget.username,
      onClearAll: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Future<void> _handleRefresh() async {
    await _fetchSantriData();
    if (_enhancedNotifications != null) {
      unawaited(GoogleSheetsMonitorService.forceCheckForUser(widget.username));
    }
  }

  void _onBottomNavTap(int index) {
    switch (index) {
      case 0:
        setState(() => _currentIndex = 0);
        break;
      case 1:
        setState(() => _currentIndex = 1);
        break;
      case 2:
        setState(() => _currentIndex = 2);
        break;
      case 3:
        _showLogoutDialog();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _isLoading && _santriData.isEmpty
                ? _buildLoadingState(screenSize)
                : _buildMainContent(screenSize),
            _buildEnhancedNotificationPage(screenSize),
            PaymentPage(
              username: widget.username,
              studentName: _santriData['nama'] ?? 'Santri',
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(screenSize),
    );
  }

  Widget _buildBottomNavigationBar(Size screenSize) {
    return Container(
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
        selectedFontSize: screenSize.width * 0.028,
        unselectedFontSize: screenSize.width * 0.025,
        elevation: 0,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: _buildNotificationIcon(),
            activeIcon: _buildNotificationIcon(active: true),
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
    );
  }

  Widget _buildNotificationIcon({bool active = false}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(active ? Icons.notifications_active : Icons.notifications),
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
              constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
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
    );
  }

  Widget _buildMainContent(Size screenSize) {
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
                  padding: EdgeInsets.fromLTRB(
                    screenSize.width * 0.04,
                    screenSize.width * 0.04,
                    screenSize.width * 0.04,
                    0,
                  ),
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
                  padding: EdgeInsets.all(screenSize.width * 0.05),
                  child: Column(
                    children: [
                      if (_errorMessage.isNotEmpty) ...[
                        _buildErrorBanner(screenSize),
                        SizedBox(height: screenSize.height * 0.02),
                      ],
                      QuickActions(nisn: widget.username),
                      SizedBox(height: screenSize.height * 0.03),
                      _buildReportSection(),
                      SizedBox(height: screenSize.height * 0.025),
                      _buildStudentInfo(),
                      SizedBox(height: screenSize.height * 0.025),
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

  Widget _buildEnhancedNotificationPage(Size screenSize) {
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
                SizedBox(width: screenSize.width * 0.03),
                Flexible(
                  child: Text(
                    'Notifikasi ($unreadCount baru)',
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontWeight: FontWeight.bold,
                      fontSize: screenSize.width * 0.045,
                    ),
                  ),
                ),
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
                      fontSize: screenSize.width * 0.032,
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
            return _buildEmptyNotifications(screenSize);
          }
          return _buildEnhancedNotificationList(notifications, screenSize);
        },
      ),
    );
  }

  Widget _buildEmptyNotifications(Size screenSize) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(screenSize.width * 0.08),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none,
              size: screenSize.width * 0.16,
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: screenSize.height * 0.03),
          Text(
            'Tidak ada notifikasi',
            style: TextStyle(
              fontSize: screenSize.width * 0.045,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: screenSize.height * 0.01),
          Text(
            'Perubahan data akan muncul di sini',
            style: TextStyle(
              fontSize: screenSize.width * 0.035,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedNotificationList(
    List<NotificationItem> notifications,
    Size screenSize,
  ) {
    return RefreshIndicator(
      color: Colors.red[400],
      onRefresh: _handleRefresh,
      child: ListView.separated(
        padding: EdgeInsets.all(screenSize.width * 0.04),
        itemCount: notifications.length,
        separatorBuilder: (_, __) =>
            SizedBox(height: screenSize.height * 0.015),
        itemBuilder: (context, index) =>
            _buildNotificationItem(notifications[index], screenSize),
      ),
    );
  }

  Widget _buildNotificationItem(
    NotificationItem notification,
    Size screenSize,
  ) {
    return Container(
      padding: EdgeInsets.all(screenSize.width * 0.04),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.white : Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead ? Colors.grey[200]! : Colors.blue[200]!,
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
              padding: EdgeInsets.all(screenSize.width * 0.02),
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
                size: screenSize.width * 0.05,
              ),
            ),
            SizedBox(width: screenSize.width * 0.03),
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
                          margin: EdgeInsets.only(
                            right: screenSize.width * 0.02,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[400],
                            shape: BoxShape.circle,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: screenSize.width * 0.035,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      Text(
                        _formatTimestamp(notification.timestamp),
                        style: TextStyle(
                          fontSize: screenSize.width * 0.028,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenSize.height * 0.005),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: screenSize.width * 0.032,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: screenSize.height * 0.005),
                  Text(
                    'Sumber: ${notification.sheetName}',
                    style: TextStyle(
                      fontSize: screenSize.width * 0.028,
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

  Widget _buildLoadingState(Size screenSize) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              screenSize.width * 0.04,
              screenSize.width * 0.04,
              screenSize.width * 0.04,
              0,
            ),
            child: _buildHeaderShimmer(screenSize),
          ),
          Padding(
            padding: EdgeInsets.all(screenSize.width * 0.05),
            child: Column(
              children: [
                _buildQuickActionsShimmer(screenSize),
                SizedBox(height: screenSize.height * 0.03),
                _buildReportShimmer(screenSize),
                SizedBox(height: screenSize.height * 0.025),
                _buildStudentInfoShimmer(screenSize),
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
                  stops: const [0.0, 0.5, 1.0],
                  transform: GradientRotation(_shimmerAnimation.value * 0.3),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderShimmer(Size screenSize) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: screenSize.width * 0.05,
        horizontal: screenSize.width * 0.06,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(screenSize.width * 0.06),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildShimmerContainer(
                width: screenSize.width * 0.14,
                height: screenSize.width * 0.14,
                borderRadius: 16,
              ),
              SizedBox(width: screenSize.width * 0.05),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShimmerContainer(
                      width: screenSize.width * 0.3,
                      height: screenSize.width * 0.035,
                      borderRadius: 6,
                    ),
                    SizedBox(height: screenSize.height * 0.005),
                    _buildShimmerContainer(
                      width: screenSize.width * 0.45,
                      height: screenSize.width * 0.05,
                      borderRadius: 8,
                    ),
                    SizedBox(height: screenSize.height * 0.003),
                    _buildShimmerContainer(
                      width: screenSize.width * 0.35,
                      height: screenSize.width * 0.035,
                      borderRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: screenSize.height * 0.035),
          Container(
            padding: EdgeInsets.all(screenSize.width * 0.055),
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
                        width: screenSize.width * 0.25,
                        height: screenSize.width * 0.032,
                        borderRadius: 6,
                      ),
                      SizedBox(height: screenSize.height * 0.01),
                      _buildShimmerContainer(
                        width: screenSize.width * 0.4,
                        height: screenSize.width * 0.065,
                        borderRadius: 10,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: screenSize.width * 0.04),
                _buildShimmerContainer(
                  width: screenSize.width * 0.09,
                  height: screenSize.width * 0.09,
                  borderRadius: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsShimmer(Size screenSize) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenSize.width * 0.05),
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
          _buildShimmerContainer(
            width: screenSize.width * 0.3,
            height: screenSize.width * 0.05,
            borderRadius: 10,
          ),
          SizedBox(height: screenSize.height * 0.02),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              4,
              (index) => Column(
                children: [
                  _buildShimmerContainer(
                    width: screenSize.width * 0.125,
                    height: screenSize.width * 0.125,
                    borderRadius: screenSize.width * 0.0625,
                  ),
                  SizedBox(height: screenSize.height * 0.01),
                  _buildShimmerContainer(
                    width: screenSize.width * 0.15,
                    height: screenSize.width * 0.03,
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

  Widget _buildReportShimmer(Size screenSize) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenSize.width * 0.05),
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
          _buildShimmerContainer(
            width: screenSize.width * 0.25,
            height: screenSize.width * 0.05,
            borderRadius: 10,
          ),
          SizedBox(height: screenSize.height * 0.02),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildShimmerContainer(
                      width: double.infinity,
                      height: screenSize.width * 0.04,
                      borderRadius: 8,
                    ),
                    SizedBox(height: screenSize.height * 0.01),
                    _buildShimmerContainer(
                      width: screenSize.width * 0.2,
                      height: screenSize.width * 0.06,
                      borderRadius: 12,
                    ),
                  ],
                ),
              ),
              SizedBox(width: screenSize.width * 0.04),
              Expanded(
                child: Column(
                  children: [
                    _buildShimmerContainer(
                      width: double.infinity,
                      height: screenSize.width * 0.04,
                      borderRadius: 8,
                    ),
                    SizedBox(height: screenSize.height * 0.01),
                    _buildShimmerContainer(
                      width: screenSize.width * 0.2,
                      height: screenSize.width * 0.06,
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

  Widget _buildStudentInfoShimmer(Size screenSize) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenSize.width * 0.05),
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
          _buildShimmerContainer(
            width: screenSize.width * 0.3,
            height: screenSize.width * 0.05,
            borderRadius: 10,
          ),
          SizedBox(height: screenSize.height * 0.02),
          ...List.generate(
            4,
            (index) => Padding(
              padding: EdgeInsets.only(bottom: screenSize.height * 0.015),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildShimmerContainer(
                    width: screenSize.width * 0.25,
                    height: screenSize.width * 0.04,
                    borderRadius: 8,
                  ),
                  _buildShimmerContainer(
                    width: screenSize.width * 0.2,
                    height: screenSize.width * 0.04,
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

  Widget _buildErrorBanner(Size screenSize) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenSize.width * 0.04),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.amber[700],
            size: screenSize.width * 0.055,
          ),
          SizedBox(width: screenSize.width * 0.03),
          Expanded(
            child: Text(
              _errorMessage,
              style: TextStyle(
                color: Colors.amber[800],
                fontSize: screenSize.width * 0.035,
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
