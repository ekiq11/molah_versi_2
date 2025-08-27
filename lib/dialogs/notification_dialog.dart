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
      id: json['id'],
      title: json['title'],
      message: json['message'],
      sheetName: json['sheetName'],
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['isRead'] ?? false,
      changes: json['changes'] ?? {},
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

  // Inisialisasi untuk user tertentu
  static Future<void> initializeForUser(String username) async {
    try {
      if (_mmkv == null) {
        MMKV.initialize();
        _mmkv = MMKV.defaultMMKV();
        debugPrint('✅ GoogleSheetsMonitorService MMKV initialized');
      }

      // Buat notifier untuk user ini jika belum ada
      if (!_userNotifications.containsKey(username)) {
        _userNotifications[username] = ValueNotifier<List<NotificationItem>>(
          [],
        );
      }

      await _loadUserNotifications(username);
      await _loadInitialCacheForUser(username);
      _startMonitoringForUser(username);

      debugPrint(
        '✅ GoogleSheetsMonitorService initialized for user: $username',
      );
    } catch (e) {
      debugPrint('❌ Error initializing GoogleSheetsMonitorService: $e');
    }
  }

  // Mendapatkan notifier untuk user tertentu
  static ValueNotifier<List<NotificationItem>>? getNotificationsForUser(
    String username,
  ) {
    return _userNotifications[username];
  }

  // Load cache awal untuk user tertentu
  static Future<void> _loadInitialCacheForUser(String username) async {
    if (_mmkv == null) return;

    for (var config in _sheetConfigs) {
      try {
        final cacheKey = 'sheet_cache_${username}_${config['name']}';
        final existingCache = _mmkv!.decodeString(cacheKey);

        if (existingCache == null || existingCache.isEmpty) {
          // Hanya load cache awal jika belum ada
          final data = await _fetchSheetData(config['url']!);
          final cacheData = {
            'url': config['url'],
            'name': config['name'],
            'data': data,
            'lastUpdated': DateTime.now().toIso8601String(),
            'username': username,
          };

          _mmkv!.encodeString(cacheKey, jsonEncode(cacheData));
          debugPrint(
            '✅ Initial cache loaded for ${config['name']} - $username',
          );
        }
      } catch (e) {
        debugPrint('❌ Error loading initial cache for ${config['name']}: $e');
      }
    }
  }

  // Fetch data dari Google Sheets
  static Future<List<List<dynamic>>> _fetchSheetData(String url) async {
    final response = await http
        .get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'Mozilla/5.0 (compatible; FlutterApp/1.0)',
            'Accept': 'text/csv,application/csv,text/plain,*/*',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final csvData = response.body;
      final List<List<dynamic>> rows = const CsvToListConverter().convert(
        csvData,
      );
      return rows;
    } else {
      throw Exception('Failed to fetch data: ${response.statusCode}');
    }
  }

  // Mulai monitoring untuk user tertentu
  static void _startMonitoringForUser(
    String username, {
    Duration interval = const Duration(minutes: 5),
  }) {
    // Hanya satu timer global untuk semua user
    if (_monitoringTimer == null) {
      _monitoringTimer = Timer.periodic(interval, (timer) {
        // Check untuk semua user yang aktif
        for (String activeUsername in _userNotifications.keys) {
          _checkForUpdatesForUser(activeUsername);
        }
      });
      debugPrint(
        '✅ Started monitoring timer with ${interval.inMinutes} minutes interval',
      );
    }
  }

  // Check perubahan untuk user tertentu
  static Future<void> _checkForUpdatesForUser(String username) async {
    if (_mmkv == null) return;

    debugPrint('🔍 Checking updates for user: $username');

    for (var config in _sheetConfigs) {
      try {
        final cacheKey = 'sheet_cache_${username}_${config['name']}';
        final cachedDataJson = _mmkv!.decodeString(cacheKey);

        if (cachedDataJson == null) continue;

        final cachedData = jsonDecode(cachedDataJson);
        final oldData = List<List<dynamic>>.from(cachedData['data']);

        // Ambil data baru
        final newData = await _fetchSheetData(config['url']!);

        // Bandingkan dan cari data user spesifik
        final userOldData = _findUserDataInSheet(oldData, username);
        final userNewData = _findUserDataInSheet(newData, username);

        if (userOldData.isNotEmpty && userNewData.isNotEmpty) {
          final changes = _compareUserData(userOldData, userNewData);

          if (changes.isNotEmpty) {
            // Buat notifikasi
            final notification = NotificationItem(
              id: '${DateTime.now().millisecondsSinceEpoch}_${username}',
              title: 'Perubahan Data ${config['name']}',
              message: _formatUserChangesMessage(changes),
              sheetName: config['name']!,
              timestamp: DateTime.now(),
              changes: changes,
              username: username,
            );

            await _addNotificationForUser(username, notification);

            // Update cache
            final updatedCacheData = {
              'url': config['url'],
              'name': config['name'],
              'data': newData,
              'lastUpdated': DateTime.now().toIso8601String(),
              'username': username,
            };

            _mmkv!.encodeString(cacheKey, jsonEncode(updatedCacheData));

            debugPrint('✅ Changes detected for $username in ${config['name']}');
          }
        }
      } catch (e) {
        debugPrint('❌ Error checking updates for ${config['name']}: $e');
      }
    }
  }

  // Mencari data user dalam sheet
  static Map<String, dynamic> _findUserDataInSheet(
    List<List<dynamic>> sheetData,
    String username,
  ) {
    if (sheetData.isEmpty) return {};

    final headers = sheetData[0]
        .map((e) => e.toString().toLowerCase().trim())
        .toList();
    final nisnIndex = _findColumnIndex(headers, [
      'nisn',
      'username',
      'id',
      'student_id',
    ]);

    if (nisnIndex == -1) return {};

    for (int i = 1; i < sheetData.length; i++) {
      final row = sheetData[i];
      if (row.length > nisnIndex) {
        final csvNisn = row[nisnIndex]?.toString().trim() ?? '';
        if (_isMatchingUser(username, csvNisn)) {
          return _extractUserData(row, headers);
        }
      }
    }

    return {};
  }

  // Helper functions dari HomeScreen
  static int _findColumnIndex(
    List<String> headers,
    List<String> possibleNames,
  ) {
    for (final name in possibleNames) {
      for (int i = 0; i < headers.length; i++) {
        if (headers[i].contains(name) || name.contains(headers[i])) {
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

    return cleanTarget == cleanCsv ||
        cleanTarget.replaceAll(RegExp(r'[^0-9]'), '') ==
            cleanCsv.replaceAll(RegExp(r'[^0-9]'), '');
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

  // Compare user data - lebih spesifik untuk data santri
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

      if (oldValue != newValue &&
          (oldValue.isNotEmpty || newValue.isNotEmpty)) {
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

  // Format pesan perubahan untuk data user
  static String _formatUserChangesMessage(Map<String, dynamic> changes) {
    List<String> messages = [];

    if (changes.containsKey('fields')) {
      final fieldChanges = changes['fields'] as List;

      for (var change in fieldChanges.take(3)) {
        // Ambil 3 perubahan pertama
        final fieldName = change['fieldName'];
        final oldValue = change['oldValue'];
        final newValue = change['newValue'];

        if (change['changeType'] == 'added') {
          messages.add('$fieldName: $newValue (baru)');
        } else if (change['changeType'] == 'removed') {
          messages.add('$fieldName: dihapus');
        } else {
          messages.add('$fieldName: $oldValue → $newValue');
        }
      }

      if (fieldChanges.length > 3) {
        messages.add('dan ${fieldChanges.length - 3} perubahan lainnya');
      }
    }

    return messages.isNotEmpty ? messages.join(', ') : 'Data telah berubah';
  }

  // Tambah notifikasi untuk user
  static Future<void> _addNotificationForUser(
    String username,
    NotificationItem notification,
  ) async {
    if (_userNotifications.containsKey(username)) {
      final currentNotifications = List<NotificationItem>.from(
        _userNotifications[username]!.value,
      );
      currentNotifications.insert(0, notification);

      // Batasi jumlah notifikasi (max 50)
      if (currentNotifications.length > 50) {
        currentNotifications.removeRange(50, currentNotifications.length);
      }

      _userNotifications[username]!.value = currentNotifications;
      await _saveUserNotifications(username);
    }
  }

  // Load notifikasi user dari MMKV
  static Future<void> _loadUserNotifications(String username) async {
    if (_mmkv == null) return;

    try {
      final notificationsKey = 'notifications_enhanced_$username';
      final notificationsJson = _mmkv!.decodeString(notificationsKey);

      if (notificationsJson != null && notificationsJson.isNotEmpty) {
        final notificationsList = jsonDecode(notificationsJson) as List;
        final notifications = notificationsList
            .map((n) => NotificationItem.fromJson(n))
            .toList();

        if (_userNotifications.containsKey(username)) {
          _userNotifications[username]!.value = notifications;
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading user notifications: $e');
    }
  }

  // Save notifikasi user ke MMKV
  static Future<void> _saveUserNotifications(String username) async {
    if (_mmkv == null || !_userNotifications.containsKey(username)) return;

    try {
      final notificationsKey = 'notifications_enhanced_$username';
      final notificationsJson = _userNotifications[username]!.value
          .map((n) => n.toJson())
          .toList();

      _mmkv!.encodeString(notificationsKey, jsonEncode(notificationsJson));
    } catch (e) {
      debugPrint('❌ Error saving user notifications: $e');
    }
  }

  // Mark notification as read
  static Future<void> markAsReadForUser(
    String username,
    String notificationId,
  ) async {
    if (!_userNotifications.containsKey(username)) return;

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
    }
  }

  // Clear semua notifikasi untuk user
  static Future<void> clearAllNotificationsForUser(String username) async {
    if (_userNotifications.containsKey(username)) {
      _userNotifications[username]!.value = [];
      await _saveUserNotifications(username);
    }
  }

  // Get unread count untuk user
  static int getUnreadCountForUser(String username) {
    if (!_userNotifications.containsKey(username)) return 0;
    return _userNotifications[username]!.value.where((n) => !n.isRead).length;
  }

  // Force check untuk user tertentu
  static Future<void> forceCheckForUser(String username) async {
    await _checkForUpdatesForUser(username);
  }

  // Stop monitoring untuk user tertentu
  static void stopMonitoringForUser(String username) {
    _userNotifications.remove(username);

    // Jika tidak ada user yang dipantau, stop timer
    if (_userNotifications.isEmpty) {
      _monitoringTimer?.cancel();
      _monitoringTimer = null;
      debugPrint('🛑 Stopped monitoring timer - no active users');
    }
  }

  // Cleanup untuk user tertentu
  static Future<void> cleanupForUser(String username) async {
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
  }
}

// Enhanced Notification Dialog yang terintegrasi
class EnhancedNotificationDialog {
  static void show({
    required BuildContext context,
    required String username,
    required VoidCallback onClearAll,
  }) {
    final notificationsNotifier =
        GoogleSheetsMonitorService.getNotificationsForUser(username);

    if (notificationsNotifier == null) {
      debugPrint('❌ No notifications notifier found for user: $username');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak ada notifikasi untuk ditampilkan')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ValueListenableBuilder<List<NotificationItem>>(
              valueListenable: notificationsNotifier,
              builder: (context, notifications, child) {
                final unreadCount = notifications
                    .where((n) => !n.isRead)
                    .length;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.notifications_active,
                        color: Colors.blue[400],
                        size: 24,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Notifikasi Data (${notifications.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[800],
                      ),
                    ),
                    if (unreadCount > 0)
                      Container(
                        margin: EdgeInsets.only(top: 8),
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$unreadCount perubahan baru',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    SizedBox(height: 16),

                    // Daftar notifikasi
                    Expanded(
                      child: notifications.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: notifications.length,
                              itemBuilder: (context, index) {
                                final notification = notifications[index];
                                return _buildNotificationTile(
                                  notification: notification,
                                  onTap: () {
                                    GoogleSheetsMonitorService.markAsReadForUser(
                                      username,
                                      notification.id,
                                    );
                                  },
                                );
                              },
                            ),
                    ),

                    SizedBox(height: 20),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Tutup',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: notifications.isEmpty
                                ? null
                                : () {
                                    GoogleSheetsMonitorService.clearAllNotificationsForUser(
                                      username,
                                    );
                                    onClearAll();
                                    Navigator.of(context).pop();
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[400],
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Hapus Semua',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  static Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.notifications_none, size: 48, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'Belum ada notifikasi perubahan data',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.grey[50] : Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: notification.isRead ? Colors.grey[200]! : Colors.blue[200]!,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(12),
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
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                notification.message,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.3,
                ),
              ),
              SizedBox(height: 4),
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
      ),
    );
  }

  static String _formatTimestamp(DateTime timestamp) {
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
}
