import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:mmkv/mmkv.dart';
import 'dart:convert';
import 'dart:async';

// Model untuk notifikasi yang terintegrasi
class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String sheetName;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic> changes;
  final String username;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.sheetName,
    required this.timestamp,
    this.isRead = false,
    required this.changes,
    required this.username,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'sheetName': sheetName,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'changes': changes,
      'username': username,
    };
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      sheetName: json['sheetName'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      isRead: json['isRead'] ?? false,
      changes: Map<String, dynamic>.from(json['changes'] ?? {}),
      username: json['username'] ?? '',
    );
  }

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      title: title,
      message: message,
      sheetName: sheetName,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      changes: changes,
      username: username,
    );
  }
}

// Enhanced Google Sheets Monitor Service yang terintegrasi dengan MMKV
class GoogleSheetsMonitorService {
  static MMKV? _mmkv;
  static Timer? _monitoringTimer;
  static final Map<String, ValueNotifier<List<NotificationItem>>>
  _userNotifications = {};
  static bool _isInitialized = false;
  static final Map<String, bool> _userInitialized = {};

  // Konfigurasi sheets - sesuai dengan HomeScreen
  static const List<Map<String, String>> _sheetConfigs = [
    {
      'url':
          'https://docs.google.com/spreadsheets/d/1BZbBczH2OY8SB2_1tDpKf_B8WvOyk8TJl4esfT-dgzw/export?format=csv&gid=1307491664',
      'name': 'Data Santri',
    },
    {
      'url':
          'https://docs.google.com/spreadsheets/d/1BZbBczH2OY8SB2_1tDpKf_B8WvOyk8TJl4esfT-dgzw/export?format=csv&gid=2071598361',
      'name': 'Data Keuangan',
    },
    {
      'url':
          'https://docs.google.com/spreadsheets/d/1BZbBczH2OY8SB2_1tDpKf_B8WvOyk8TJl4esfT-dgzw/export?format=csv&gid=1620978739',
      'name': 'Data Akademik',
    },
    {
      'url':
          'https://docs.google.com/spreadsheets/d/1nKsOxOHqi4fmJ9aR4ZpSUiePKVtZG03L2Qjc_iv5QmU/export?format=csv&gid=1962923536',
      'name': 'Data Perizinan',
    },
    {
      'url':
          'https://docs.google.com/spreadsheets/d/1nKsOxOHqi4fmJ9aR4ZpSUiePKVtZG03L2Qjc_iv5QmU/export?format=csv&gid=1156735988',
      'name': 'Data Absensi',
    },
    {
      'url':
          'https://docs.google.com/spreadsheets/d/1BZbBczH2OY8SB2_1tDpKf_B8WvOyk8TJl4esfT-dgzw/export?format=csv&gid=2012044980',
      'name': 'Riwayat Transaksi',
    },
  ];

  // Field mapping - sesuai dengan data santri di HomeScreen
  static const Map<String, String> _fieldNames = {
    'saldo': 'Saldo',
    'status_izin': 'Status Perizinan',
    'jumlah_hafalan': 'Jumlah Hafalan',
    'absensi': 'Absensi',
    'poin_pelanggaran': 'Poin Pelanggaran',
    'reward': 'Reward',
    'lembaga': 'Lembaga',
    'izin_terakhir': 'Izin Terakhir',
    'nama': 'Nama',
    'kelas': 'Kelas',
    'asrama': 'Asrama',
  };

  // Inisialisasi global MMKV
  static Future<void> _initializeMMKV() async {
    if (_mmkv == null && !_isInitialized) {
      try {
        MMKV.initialize();
        _mmkv = MMKV.defaultMMKV();
        _isInitialized = true;
        debugPrint('✅ GoogleSheetsMonitorService MMKV initialized');
      } catch (e) {
        debugPrint('❌ Error initializing MMKV: $e');
        throw e;
      }
    }
  }

  // Inisialisasi untuk user tertentu
  static Future<void> initializeForUser(String username) async {
    if (username.isEmpty) {
      debugPrint('❌ Username is empty, cannot initialize monitoring');
      return;
    }

    try {
      // Initialize MMKV first
      await _initializeMMKV();

      // Skip if already initialized for this user
      if (_userInitialized[username] == true) {
        debugPrint('⚠️ Already initialized for user: $username');
        return;
      }

      // Buat notifier untuk user ini jika belum ada
      if (!_userNotifications.containsKey(username)) {
        _userNotifications[username] = ValueNotifier<List<NotificationItem>>(
          [],
        );
      }

      // Load existing notifications first
      await _loadUserNotifications(username);

      // Load initial cache
      await _loadInitialCacheForUser(username);

      // Start monitoring
      _startMonitoringForUser(username);

      _userInitialized[username] = true;
      debugPrint(
        '✅ GoogleSheetsMonitorService initialized for user: $username',
      );
    } catch (e) {
      debugPrint(
        '❌ Error initializing GoogleSheetsMonitorService for $username: $e',
      );
      _userInitialized[username] = false;
    }
  }

  // Mendapatkan notifier untuk user tertentu
  static ValueNotifier<List<NotificationItem>>? getNotificationsForUser(
    String username,
  ) {
    return _userNotifications[username];
  }

  // Load cache awal untuk user tertentu dengan error handling yang lebih baik
  static Future<void> _loadInitialCacheForUser(String username) async {
    if (_mmkv == null || username.isEmpty) return;

    for (var config in _sheetConfigs) {
      try {
        final cacheKey = 'sheet_cache_${username}_${config['name']}';
        final existingCache = _mmkv!.decodeString(cacheKey);

        if (existingCache == null || existingCache.isEmpty) {
          debugPrint(
            '📥 Loading initial cache for ${config['name']} - $username',
          );

          final data = await _fetchSheetData(config['url']!);
          if (data.isEmpty) {
            debugPrint('⚠️ No data received for ${config['name']}');
            continue;
          }

          final cacheData = {
            'url': config['url'],
            'name': config['name'],
            'data': data,
            'lastUpdated': DateTime.now().toIso8601String(),
            'username': username,
          };

          // Khusus transaksi: ekstrak kode transaksi user
          if (config['name'] == 'Riwayat Transaksi') {
            final userTransactionIds = _extractUserTransactionIds(
              data,
              username,
            );
            cacheData['transactions'] = userTransactionIds;
            debugPrint(
              '💰 Found ${userTransactionIds.length} existing transactions for $username',
            );
          }

          _mmkv!.encodeString(cacheKey, jsonEncode(cacheData));
          debugPrint('✅ Initial cache saved for ${config['name']} - $username');
        } else {
          debugPrint(
            '📋 Cache already exists for ${config['name']} - $username',
          );
        }
      } catch (e) {
        debugPrint('❌ Error loading initial cache for ${config['name']}: $e');
      }
    }
  }

  // Helper function to extract user transaction IDs
  static List<String> _extractUserTransactionIds(
    List<List<dynamic>> data,
    String username,
  ) {
    if (data.length < 2) return [];

    try {
      final headers = data[0]
          .map((e) => e.toString().toLowerCase().trim())
          .toList();
      final nisnIndex = _findColumnIndex(headers, ['nisn']);
      final kodeIndex = _findColumnIndex(headers, [
        'kode transaksi',
        'kode_transaksi',
      ]);

      if (nisnIndex == -1 || kodeIndex == -1) return [];

      final userTransactionIds = <String>[];
      for (int i = 1; i < data.length; i++) {
        final row = data[i];
        if (row.length > nisnIndex &&
            _isMatchingUser(username, row[nisnIndex]?.toString() ?? '')) {
          final kode = row.length > kodeIndex
              ? row[kodeIndex]?.toString()
              : null;
          if (kode != null && kode.isNotEmpty) {
            userTransactionIds.add(kode);
          }
        }
      }
      return userTransactionIds;
    } catch (e) {
      debugPrint('❌ Error extracting transaction IDs: $e');
      return [];
    }
  }

  // Fetch data dari Google Sheets dengan retry mechanism
  static Future<List<List<dynamic>>> _fetchSheetData(
    String url, {
    int retryCount = 3,
  }) async {
    for (int attempt = 1; attempt <= retryCount; attempt++) {
      try {
        final response = await http
            .get(
              Uri.parse(url),
              headers: {
                'User-Agent': 'Mozilla/5.0 (compatible; FlutterApp/1.0)',
                'Accept': 'text/csv,application/csv,text/plain,*/*',
                'Cache-Control': 'no-cache',
              },
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          if (response.body.trim().isEmpty) {
            throw Exception('Empty response body');
          }

          final List<List<dynamic>> rows = const CsvToListConverter().convert(
            response.body,
            shouldParseNumbers:
                false, // Keep as strings to avoid parsing issues
          );

          if (rows.isEmpty) {
            throw Exception('No data rows found');
          }

          return rows;
        } else {
          throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          );
        }
      } catch (e) {
        debugPrint('❌ Attempt $attempt failed to fetch data: $e');
        if (attempt == retryCount) {
          throw Exception(
            'Failed to fetch data after $retryCount attempts: $e',
          );
        }
        // Wait before retry
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    return [];
  }

  // Mulai monitoring untuk user tertentu
  static void _startMonitoringForUser(
    String username, {
    Duration interval = const Duration(minutes: 3),
  }) {
    // Hanya satu timer global untuk semua user
    if (_monitoringTimer == null || !_monitoringTimer!.isActive) {
      _monitoringTimer?.cancel(); // Cancel any existing timer
      _monitoringTimer = Timer.periodic(interval, (timer) async {
        try {
          // Check untuk semua user yang aktif
          final activeUsers = _userNotifications.keys.toList();
          debugPrint(
            '🔄 Running scheduled check for ${activeUsers.length} users',
          );

          for (String activeUsername in activeUsers) {
            if (_userInitialized[activeUsername] == true) {
              await _checkForUpdatesForUser(activeUsername);
            }
          }
        } catch (e) {
          debugPrint('❌ Error in monitoring timer: $e');
        }
      });
      debugPrint(
        '✅ Started monitoring timer with ${interval.inMinutes} minutes interval',
      );
    }
  }

  // Check Transaksi dengan handling yang lebih baik
  static Future<void> _checkTransactionUpdates({
    required String username,
    required List<List<dynamic>> newData,
    required String cacheKey,
  }) async {
    try {
      if (newData.length < 2) {
        debugPrint('⚠️ Insufficient transaction data for $username');
        return;
      }

      final headers = newData[0]
          .map((e) => e.toString().toLowerCase().trim())
          .toList();
      final nisnIndex = _findColumnIndex(headers, ['nisn']);
      final kodeIndex = _findColumnIndex(headers, [
        'kode transaksi',
        'kode_transaksi',
      ]);
      final namaIndex = _findColumnIndex(headers, [
        'nama santri',
        'nama_santri',
        'nama',
      ]);
      final saldoIndex = _findColumnIndex(headers, [
        'sisa saldo',
        'sisa_saldo',
        'saldo',
      ]);
      final pemakaianIndex = _findColumnIndex(headers, [
        'pemakaian',
        'jumlah',
        'nominal',
      ]);
      final waktuIndex = _findColumnIndex(headers, [
        'timestamp',
        'waktu',
        'tanggal',
      ]);

      if (nisnIndex == -1 || kodeIndex == -1) {
        debugPrint('⚠️ Required columns not found for transaction monitoring');
        return;
      }

      // Filter transaksi user
      final userTransactions = <Map<String, String>>[];
      for (int i = 1; i < newData.length; i++) {
        final row = newData[i];
        if (row.length > nisnIndex &&
            _isMatchingUser(username, row[nisnIndex]?.toString() ?? '')) {
          userTransactions.add({
            'kode': row.length > kodeIndex
                ? (row[kodeIndex]?.toString() ?? '')
                : '',
            'nama': namaIndex >= 0 && row.length > namaIndex
                ? (row[namaIndex]?.toString() ?? '')
                : username,
            'saldo': saldoIndex >= 0 && row.length > saldoIndex
                ? (row[saldoIndex]?.toString() ?? '0')
                : '0',
            'pemakaian': pemakaianIndex >= 0 && row.length > pemakaianIndex
                ? (row[pemakaianIndex]?.toString() ?? '0')
                : '0',
            'waktu': waktuIndex >= 0 && row.length > waktuIndex
                ? (row[waktuIndex]?.toString() ?? '')
                : (row.length > 0 ? row[0]?.toString() ?? '' : ''),
          });
        }
      }

      if (userTransactions.isEmpty) {
        debugPrint('📊 No transactions found for user: $username');
        return;
      }

      // Ambil cache transaksi terakhir
      Set<String> knownTransactionIds = {};
      try {
        final cachedDataJson = _mmkv!.decodeString(cacheKey);
        if (cachedDataJson != null && cachedDataJson.isNotEmpty) {
          final cachedData = jsonDecode(cachedDataJson);
          final List<dynamic> cachedTransactions =
              cachedData['transactions'] ?? [];
          knownTransactionIds = cachedTransactions
              .map((e) => e.toString())
              .toSet();
        }
      } catch (e) {
        debugPrint('⚠️ Failed to parse transaction cache: $e');
      }

      // Cari transaksi baru
      final newTransactions = userTransactions
          .where(
            (tx) =>
                tx['kode']!.isNotEmpty &&
                !knownTransactionIds.contains(tx['kode']),
          )
          .toList();

      debugPrint(
        '💳 Found ${newTransactions.length} new transactions for $username',
      );

      if (newTransactions.isNotEmpty) {
        for (var tx in newTransactions) {
          final kode = tx['kode']!;
          final nominal = tx['pemakaian']!;
          final saldo = tx['saldo']!;
          final waktu = tx['waktu']!;

          final notification = NotificationItem(
            id: 'trans_${kode}_${username}_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Transaksi Baru',
            message:
                'Pemakaian: Rp${_formatCurrency(nominal)}\nSisa Saldo: Rp${_formatCurrency(saldo)}\nWaktu: $waktu',
            sheetName: 'Riwayat Transaksi',
            timestamp: DateTime.now(),
            changes: {
              'type': 'transaction',
              'amount': nominal,
              'balance': saldo,
              'time': waktu,
              'code': kode,
            },
            username: username,
          );

          await _addNotificationForUser(username, notification);
        }
      }

      // Update cache dengan semua transaction IDs
      final allTransactionIds = userTransactions
          .where((tx) => tx['kode']!.isNotEmpty)
          .map((tx) => tx['kode']!)
          .toSet()
          .toList();

      final updatedCacheData = {
        'url':
            'https://docs.google.com/spreadsheets/d/1BZbBczH2OY8SB2_1tDpKf_B8WvOyk8TJl4esfT-dgzw/export?format=csv&gid=2012044980',
        'name': 'Riwayat Transaksi',
        'data': newData,
        'transactions': allTransactionIds,
        'lastUpdated': DateTime.now().toIso8601String(),
        'username': username,
      };

      _mmkv!.encodeString(cacheKey, jsonEncode(updatedCacheData));
      debugPrint('✅ Transaction cache updated for $username');
    } catch (e) {
      debugPrint('❌ Error checking transaction updates: $e');
    }
  }

  // Format currency dengan handling null safety
  static String _formatCurrency(String value) {
    if (value.isEmpty) return '0';

    try {
      final cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');
      final number = int.tryParse(cleanValue) ?? 0;
      return number
          .toStringAsFixed(0)
          .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.');
    } catch (e) {
      return value;
    }
  }

  // Check perubahan untuk user tertentu dengan error handling yang lebih baik
  static Future<void> _checkForUpdatesForUser(String username) async {
    if (_mmkv == null || username.isEmpty) return;

    debugPrint('🔍 Checking updates for user: $username');

    for (var config in _sheetConfigs) {
      try {
        final cacheKey = 'sheet_cache_${username}_${config['name']}';

        // Fetch new data
        final newData = await _fetchSheetData(config['url']!);
        if (newData.length < 2) {
          debugPrint('⚠️ Insufficient data for ${config['name']}');
          continue;
        }

        if (config['name'] == 'Riwayat Transaksi') {
          await _checkTransactionUpdates(
            username: username,
            newData: newData,
            cacheKey: cacheKey,
          );
        } else {
          // Handle other sheet types
          await _checkRegularSheetUpdates(
            username: username,
            newData: newData,
            cacheKey: cacheKey,
            sheetConfig: config,
          );
        }
      } catch (e) {
        debugPrint('❌ Error checking updates for ${config['name']}: $e');
      }
    }
  }

  // Check regular sheet updates (non-transaction)
  static Future<void> _checkRegularSheetUpdates({
    required String username,
    required List<List<dynamic>> newData,
    required String cacheKey,
    required Map<String, String> sheetConfig,
  }) async {
    try {
      final cachedDataJson = _mmkv!.decodeString(cacheKey);
      if (cachedDataJson == null || cachedDataJson.isEmpty) {
        // No cache, save current data and return
        final cacheData = {
          'url': sheetConfig['url'],
          'name': sheetConfig['name'],
          'data': newData,
          'lastUpdated': DateTime.now().toIso8601String(),
          'username': username,
        };
        _mmkv!.encodeString(cacheKey, jsonEncode(cacheData));
        debugPrint(
          '📋 Initial cache created for ${sheetConfig['name']} - $username',
        );
        return;
      }

      final cachedData = jsonDecode(cachedDataJson);
      final oldData = List<List<dynamic>>.from(cachedData['data']);

      final userOldData = _findUserDataInSheet(oldData, username);
      final userNewData = _findUserDataInSheet(newData, username);

      if (userOldData.isNotEmpty && userNewData.isNotEmpty) {
        final changes = _compareUserData(userOldData, userNewData);

        if (changes.isNotEmpty) {
          final notification = NotificationItem(
            id: '${sheetConfig['name']}_${DateTime.now().millisecondsSinceEpoch}_$username',
            title: 'Perubahan ${sheetConfig['name']}',
            message: _formatUserChangesMessage(changes),
            sheetName: sheetConfig['name']!,
            timestamp: DateTime.now(),
            changes: changes,
            username: username,
          );

          await _addNotificationForUser(username, notification);
          debugPrint(
            '🔔 Added notification for ${sheetConfig['name']} changes',
          );
        }
      }

      // Update cache
      final updatedCacheData = {
        'url': sheetConfig['url'],
        'name': sheetConfig['name'],
        'data': newData,
        'lastUpdated': DateTime.now().toIso8601String(),
        'username': username,
      };
      _mmkv!.encodeString(cacheKey, jsonEncode(updatedCacheData));
    } catch (e) {
      debugPrint('❌ Error checking regular sheet updates: $e');
    }
  }

  // Mencari data user dalam sheet dengan error handling
  static Map<String, dynamic> _findUserDataInSheet(
    List<List<dynamic>> sheetData,
    String username,
  ) {
    if (sheetData.isEmpty || username.isEmpty) return {};

    try {
      final headers = sheetData[0]
          .map((e) => e.toString().toLowerCase().trim())
          .toList();
      final nisnIndex = _findColumnIndex(headers, [
        'nisn',
        'username',
        'id',
        'student_id',
      ]);

      if (nisnIndex == -1) {
        debugPrint('⚠️ No NISN column found in sheet');
        return {};
      }

      for (int i = 1; i < sheetData.length; i++) {
        final row = sheetData[i];
        if (row.length > nisnIndex) {
          final csvNisn = row[nisnIndex]?.toString().trim() ?? '';
          if (_isMatchingUser(username, csvNisn)) {
            return _extractUserData(row, headers);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error finding user data: $e');
    }

    return {};
  }

  // Helper functions yang diperbaiki
  static int _findColumnIndex(
    List<String> headers,
    List<String> possibleNames,
  ) {
    for (final name in possibleNames) {
      for (int i = 0; i < headers.length; i++) {
        final header = headers[i].toLowerCase().trim();
        final searchName = name.toLowerCase().trim();
        if (header == searchName ||
            header.contains(searchName) ||
            searchName.contains(header)) {
          return i;
        }
      }
    }
    return -1;
  }

  static bool _isMatchingUser(String targetUsername, String csvValue) {
    if (targetUsername.isEmpty || csvValue.isEmpty) return false;

    final cleanTarget = targetUsername.toLowerCase().trim();
    final cleanCsv = csvValue.toLowerCase().trim();

    // Exact match
    if (cleanTarget == cleanCsv) return true;

    // Numeric match (extract numbers only)
    final targetNumbers = cleanTarget.replaceAll(RegExp(r'[^0-9]'), '');
    final csvNumbers = cleanCsv.replaceAll(RegExp(r'[^0-9]'), '');

    return targetNumbers.isNotEmpty && targetNumbers == csvNumbers;
  }

  static Map<String, dynamic> _extractUserData(
    List<dynamic> row,
    List<String> headers,
  ) {
    return {
      'nama': _getFieldValue(row, headers, ['nama', 'name'], ''),
      'saldo': _getFieldValue(row, headers, ['saldo', 'balance'], '0'),
      'kelas': _getFieldValue(row, headers, ['kelas', 'class'], ''),
      'asrama': _getFieldValue(row, headers, ['asrama', 'dormitory'], ''),
      'status_izin': _getFieldValue(row, headers, ['status_izin', 'izin'], ''),
      'jumlah_hafalan': _getFieldValue(row, headers, [
        'hafalan',
        'memorization',
      ], ''),
      'absensi': _getFieldValue(row, headers, ['absensi', 'attendance'], ''),
      'poin_pelanggaran': _getFieldValue(row, headers, [
        'poin',
        'penalty',
      ], '0'),
      'reward': _getFieldValue(row, headers, ['reward', 'bonus'], '0'),
      'lembaga': _getFieldValue(row, headers, ['lembaga', 'institution'], ''),
      'izin_terakhir': _getFieldValue(row, headers, [
        'izin_terakhir',
        'last_permission',
      ], ''),
    };
  }

  static String _getFieldValue(
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

  // Compare user data dengan handling yang lebih baik
  static Map<String, dynamic> _compareUserData(
    Map<String, dynamic> oldData,
    Map<String, dynamic> newData,
  ) {
    Map<String, dynamic> changes = {};
    List<Map<String, dynamic>> fieldChanges = [];

    for (final entry in _fieldNames.entries) {
      final fieldKey = entry.key;
      final fieldName = entry.value;

      final oldValue = oldData[fieldKey]?.toString().trim() ?? '';
      final newValue = newData[fieldKey]?.toString().trim() ?? '';

      // Skip if both values are empty or exactly the same
      if (oldValue == newValue) continue;

      // Only consider significant changes
      if (oldValue.isNotEmpty || newValue.isNotEmpty) {
        fieldChanges.add({
          'field': fieldKey,
          'fieldName': fieldName,
          'oldValue': oldValue,
          'newValue': newValue,
          'changeType': oldValue.isEmpty
              ? 'added'
              : (newValue.isEmpty ? 'removed' : 'modified'),
        });
      }
    }

    if (fieldChanges.isNotEmpty) {
      changes['fields'] = fieldChanges;
    }

    return changes;
  }

  // Format pesan perubahan dengan handling yang lebih baik
  static String _formatUserChangesMessage(Map<String, dynamic> changes) {
    List<String> messages = [];

    if (changes.containsKey('fields')) {
      final fieldChanges = changes['fields'] as List;

      for (var change in fieldChanges.take(3)) {
        final fieldName = change['fieldName'] ?? 'Field';
        final oldValue = change['oldValue'] ?? '';
        final newValue = change['newValue'] ?? '';
        final changeType = change['changeType'] ?? 'modified';

        switch (changeType) {
          case 'added':
            messages.add('$fieldName: $newValue (ditambahkan)');
            break;
          case 'removed':
            messages.add('$fieldName: dihapus');
            break;
          default:
            messages.add('$fieldName: $oldValue → $newValue');
        }
      }

      if (fieldChanges.length > 3) {
        messages.add('dan ${fieldChanges.length - 3} perubahan lainnya');
      }
    } else if (changes.containsKey('type') &&
        changes['type'] == 'transaction') {
      final amount = changes['amount'] ?? '0';
      final balance = changes['balance'] ?? '0';
      return 'Pemakaian: Rp${_formatCurrency(amount)} • Sisa: Rp${_formatCurrency(balance)}';
    }

    return messages.isNotEmpty ? messages.join('\n') : 'Data telah berubah';
  }

  // Tambah notifikasi untuk user dengan deduplication
  static Future<void> _addNotificationForUser(
    String username,
    NotificationItem notification,
  ) async {
    if (!_userNotifications.containsKey(username)) {
      debugPrint('⚠️ No notification notifier found for user: $username');
      return;
    }

    try {
      final currentNotifications = List<NotificationItem>.from(
        _userNotifications[username]!.value,
      );

      // Check for duplicate notifications (same type and content within last 5 minutes)
      final now = DateTime.now();
      final isDuplicate = currentNotifications.any((existing) {
        final timeDiff = now.difference(existing.timestamp).inMinutes;
        return timeDiff <= 5 &&
            existing.sheetName == notification.sheetName &&
            existing.title == notification.title &&
            existing.message == notification.message;
      });

      if (!isDuplicate) {
        currentNotifications.insert(0, notification);

        // Batasi jumlah notifikasi (max 100)
        if (currentNotifications.length > 100) {
          currentNotifications.removeRange(100, currentNotifications.length);
        }

        _userNotifications[username]!.value = currentNotifications;
        await _saveUserNotifications(username);

        debugPrint('✅ Added notification for $username: ${notification.title}');
      } else {
        debugPrint('⚠️ Duplicate notification skipped for $username');
      }
    } catch (e) {
      debugPrint('❌ Error adding notification for user $username: $e');
    }
  }

  // Load notifikasi user dari MMKV dengan error handling
  static Future<void> _loadUserNotifications(String username) async {
    if (_mmkv == null || username.isEmpty) return;

    try {
      final notificationsKey = 'notifications_enhanced_$username';
      final notificationsJson = _mmkv!.decodeString(notificationsKey);

      if (notificationsJson != null && notificationsJson.isNotEmpty) {
        final notificationsList = jsonDecode(notificationsJson) as List;
        final notifications = notificationsList
            .map((n) {
              try {
                return NotificationItem.fromJson(Map<String, dynamic>.from(n));
              } catch (e) {
                debugPrint('⚠️ Error parsing notification: $e');
                return null;
              }
            })
            .where((n) => n != null)
            .cast<NotificationItem>()
            .toList();

        if (_userNotifications.containsKey(username)) {
          _userNotifications[username]!.value = notifications;
          debugPrint(
            '✅ Loaded ${notifications.length} notifications for $username',
          );
        }
      } else {
        debugPrint('📋 No existing notifications found for $username');
      }
    } catch (e) {
      debugPrint('❌ Error loading user notifications for $username: $e');
      // Reset notifications on error
      if (_userNotifications.containsKey(username)) {
        _userNotifications[username]!.value = [];
      }
    }
  }

  // Save notifikasi user ke MMKV dengan error handling
  static Future<void> _saveUserNotifications(String username) async {
    if (_mmkv == null ||
        !_userNotifications.containsKey(username) ||
        username.isEmpty)
      return;

    try {
      final notificationsKey = 'notifications_enhanced_$username';
      final notifications = _userNotifications[username]!.value;

      if (notifications.isNotEmpty) {
        final notificationsJson = notifications.map((n) => n.toJson()).toList();
        _mmkv!.encodeString(notificationsKey, jsonEncode(notificationsJson));
        debugPrint(
          '💾 Saved ${notifications.length} notifications for $username',
        );
      } else {
        // Clear if empty
        if (_mmkv!.containsKey(notificationsKey)) {
          _mmkv!.removeValue(notificationsKey);
        }
        debugPrint('🗑️ Cleared empty notifications for $username');
      }
    } catch (e) {
      debugPrint('❌ Error saving user notifications for $username: $e');
    }
  }

  // Mark notification as read
  static Future<void> markAsReadForUser(
    String username,
    String notificationId,
  ) async {
    if (!_userNotifications.containsKey(username) || username.isEmpty) return;

    try {
      final currentNotifications = List<NotificationItem>.from(
        _userNotifications[username]!.value,
      );
      final index = currentNotifications.indexWhere(
        (n) => n.id == notificationId,
      );

      if (index != -1) {
        currentNotifications[index] = currentNotifications[index].copyWith(
          isRead: true,
        );
        _userNotifications[username]!.value = currentNotifications;
        await _saveUserNotifications(username);
        debugPrint('✅ Marked notification as read: $notificationId');
      }
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  static Future<void> markAllAsReadForUser(String username) async {
    if (!_userNotifications.containsKey(username) || username.isEmpty) return;

    try {
      final currentNotifications = _userNotifications[username]!.value
          .map((n) => n.copyWith(isRead: true))
          .toList();

      _userNotifications[username]!.value = currentNotifications;
      await _saveUserNotifications(username);
      debugPrint('✅ Marked all notifications as read for $username');
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
    }
  }

  // Clear semua notifikasi untuk user
  static Future<void> clearAllNotificationsForUser(String username) async {
    if (!_userNotifications.containsKey(username) || username.isEmpty) return;

    try {
      _userNotifications[username]!.value = [];
      await _saveUserNotifications(username);
      debugPrint('🗑️ Cleared all notifications for $username');
    } catch (e) {
      debugPrint('❌ Error clearing notifications for $username: $e');
    }
  }

  // Get unread count untuk user
  static int getUnreadCountForUser(String username) {
    if (!_userNotifications.containsKey(username) || username.isEmpty) return 0;
    return _userNotifications[username]!.value.where((n) => !n.isRead).length;
  }

  // Get total count untuk user
  static int getTotalCountForUser(String username) {
    if (!_userNotifications.containsKey(username) || username.isEmpty) return 0;
    return _userNotifications[username]!.value.length;
  }

  // Force check untuk user tertentu
  static Future<void> forceCheckForUser(String username) async {
    if (username.isEmpty) return;

    debugPrint('🔄 Force checking updates for user: $username');
    try {
      await _checkForUpdatesForUser(username);
      debugPrint('✅ Force check completed for $username');
    } catch (e) {
      debugPrint('❌ Error in force check for $username: $e');
    }
  }

  // Stop monitoring untuk user tertentu
  static void stopMonitoringForUser(String username) {
    if (username.isEmpty) return;

    _userNotifications.remove(username);
    _userInitialized.remove(username);

    debugPrint('🛑 Stopped monitoring for user: $username');

    // Jika tidak ada user yang dipantau, stop timer
    if (_userNotifications.isEmpty) {
      _monitoringTimer?.cancel();
      _monitoringTimer = null;
      debugPrint('🛑 Stopped monitoring timer - no active users');
    }
  }

  // Cleanup untuk user tertentu
  static Future<void> cleanupForUser(String username) async {
    if (username.isEmpty) return;

    try {
      stopMonitoringForUser(username);

      // Hapus cache sheets untuk user ini
      if (_mmkv != null) {
        for (var config in _sheetConfigs) {
          final cacheKey = 'sheet_cache_${username}_${config['name']}';
          if (_mmkv!.containsKey(cacheKey)) {
            _mmkv!.removeValue(cacheKey);
          }
        }

        // Hapus notifikasi
        final notificationsKey = 'notifications_enhanced_$username';
        if (_mmkv!.containsKey(notificationsKey)) {
          _mmkv!.removeValue(notificationsKey);
        }
      }

      debugPrint('🗑️ Cleanup completed for user: $username');
    } catch (e) {
      debugPrint('❌ Error during cleanup for $username: $e');
    }
  }

  // Check if user is being monitored
  static bool isUserBeingMonitored(String username) {
    return _userInitialized[username] == true &&
        _userNotifications.containsKey(username);
  }

  // Get monitoring status
  static Map<String, dynamic> getMonitoringStatus() {
    return {
      'isInitialized': _isInitialized,
      'activeUsers': _userNotifications.keys.toList(),
      'timerActive': _monitoringTimer?.isActive ?? false,
      'userInitialized': Map<String, bool>.from(_userInitialized),
    };
  }

  // Dispose all resources
  static Future<void> dispose() async {
    try {
      _monitoringTimer?.cancel();
      _monitoringTimer = null;

      _userNotifications.clear();
      _userInitialized.clear();

      _isInitialized = false;

      debugPrint('🛑 GoogleSheetsMonitorService disposed');
    } catch (e) {
      debugPrint('❌ Error disposing GoogleSheetsMonitorService: $e');
    }
  }
}

// Enhanced Notification Dialog yang terintegrasi dengan perbaikan UI
// Enhanced Notification Dialog yang terintegrasi dengan perbaikan UI
class EnhancedNotificationDialog {
  static void show({
    required BuildContext context,
    required String username,
    required VoidCallback onClearAll,
  }) async {
    if (username.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Username tidak valid')));
      return;
    }

    final notificationsNotifier =
        GoogleSheetsMonitorService.getNotificationsForUser(username);
    if (notificationsNotifier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Layanan notifikasi belum diinisialisasi')),
      );
      return;
    }

    int _visibleCount = 10;
    final ScrollController _scrollController = ScrollController();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ValueListenableBuilder<List<NotificationItem>>(
                valueListenable: notificationsNotifier,
                builder: (context, notifications, _) {
                  // Filter & sort
                  final recentNotifications =
                      notifications
                          .where(
                            (n) => n.timestamp.isAfter(
                              DateTime.now().subtract(Duration(days: 30)),
                            ),
                          )
                          .toList()
                        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

                  final displayed = recentNotifications
                      .take(_visibleCount)
                      .toList();

                  _scrollController.addListener(() {
                    if (_scrollController.position.pixels ==
                        _scrollController.position.maxScrollExtent) {
                      if (_visibleCount < 15 &&
                          _visibleCount < recentNotifications.length) {
                        setState(() {
                          _visibleCount = 15;
                        });
                      }
                    }
                  });

                  return Container(
                    width: 400,
                    height: 600,
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Notifikasi',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: displayed.length,
                            itemBuilder: (context, index) {
                              final n = displayed[index];
                              return Container(
                                margin: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: ListTile(
                                  leading: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: n.isRead
                                          ? Colors.grey
                                          : _getSheetColor(n.sheetName),
                                    ),
                                  ),
                                  title: Text(
                                    n.title,
                                    style: TextStyle(
                                      fontWeight: n.isRead
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    n.message,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Text(
                                    _formatTimestamp(n.timestamp),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  onTap: () async {
                                    // Update lokal dulu
                                    final updated = n.copyWith(isRead: true);
                                    final list =
                                        List<NotificationItem>.from(
                                            notificationsNotifier.value,
                                          )
                                          ..removeWhere((e) => e.id == n.id)
                                          ..insert(0, updated);
                                    notificationsNotifier.value = list;

                                    // Simpan di background
                                    unawaited(
                                      GoogleSheetsMonitorService.markAsReadForUser(
                                        username,
                                        n.id,
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close),
                          label: Text("Tutup"),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );

    _scrollController.dispose();
  }

  // Sisanya tetap sama: _buildEmptyState, _buildNotificationTile, _getSheetColor, _formatTimestamp
  static Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 40,
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Belum Ada Notifikasi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Anda akan mendapat notifikasi saat ada\nperubahan data di Google Sheets',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildNotificationTile({
    required NotificationItem notification,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.white : Colors.blue[25],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead ? Colors.grey[200]! : Colors.blue[100]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 2, right: 12),
                    child: notification.isRead
                        ? Icon(
                            Icons.circle_outlined,
                            size: 12,
                            color: Colors.grey[400],
                          )
                        : Icon(Icons.circle, size: 12, color: Colors.blue[500]),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: notification.isRead
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                            Text(
                              _formatTimestamp(notification.timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          notification.message,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getSheetColor(
                              notification.sheetName,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            notification.sheetName,
                            style: TextStyle(
                              fontSize: 11,
                              color: _getSheetColor(notification.sheetName),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _getSheetColor(String sheetName) {
    switch (sheetName) {
      case 'Riwayat Transaksi':
        return Colors.green[700] ?? Colors.green;
      case 'Data Keuangan':
        return Colors.orange[700] ?? Colors.orange;
      case 'Data Akademik':
        return Colors.purple[700] ?? Colors.purple;
      case 'Data Perizinan':
        return Colors.red[700] ?? Colors.red;
      case 'Data Absensi':
        return Colors.teal[700] ?? Colors.teal;
      default:
        return Colors.blue[700] ?? Colors.blue;
    }
  }

  static String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inSeconds < 60) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}j lalu';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}h lalu';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
