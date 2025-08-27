// lib/utils/login_preferences.dart
import 'package:mmkv/mmkv.dart';
import 'dart:convert';

// ==================== MMKV Helper Class ====================
class LoginPreferences {
  static Future<bool> clearAllUserData(String username) async {
    try {
      final mmkv = await _getInstance();

      final keysToRemove = [
        'user_logged_in',
        'user_username',
        'user_data_json',
        'user_login_time',
        'santri_$username',
        'notifications_$username',
        'last_update_$username',
        'notifications_enhanced_$username',
      ];

      for (final key in keysToRemove) {
        mmkv.removeValue(key);
      }

      return true;
    } catch (e) {
      print('❌ Error clearing user data: $e');
      return false;
    }
  }

  // MMKV instance - lazy initialization
  static MMKV? _mmkv;

  // Simplified keys - konsisten dan mudah ditrack
  static const String _keyIsLoggedIn = 'user_logged_in';
  static const String _keyUsername = 'user_username';
  static const String _keyUserData = 'user_data_json';
  static const String _keyLoginTime = 'user_login_time';

  // Initialize MMKV instance
  static Future<MMKV> _getInstance() async {
    if (_mmkv == null) {
      // Initialize MMKV with encryption (optional)
      MMKV.initialize();
      _mmkv = MMKV.defaultMMKV();
      print('✅ MMKV initialized successfully');
    }
    return _mmkv!;
  }

  /// ✅ SAVE LOGIN DATA - MMKV Implementation
  static Future<bool> saveLoginData({
    required String username,
    Map<String, dynamic>? userData,
  }) async {
    try {
      print('📱 Saving login data for: $username');

      final mmkv = await _getInstance();

      // MMKV operations are synchronous and atomic
      mmkv.encodeBool(_keyIsLoggedIn, true);
      mmkv.encodeString(_keyUsername, username.trim());
      mmkv.encodeString(_keyLoginTime, DateTime.now().toIso8601String());

      if (userData != null) {
        mmkv.encodeString(_keyUserData, json.encode(userData));
      }

      // ✅ TAMBAHKAN INI - Debug print untuk verifikasi
      print('📊 After save - All keys: ${mmkv.allKeys}');
      print(
        '📊 After save - user_logged_in: ${mmkv.decodeBool(_keyIsLoggedIn, defaultValue: false)}',
      );
      print(
        '📊 After save - user_username: "${mmkv.decodeString(_keyUsername)}"',
      );
      print(
        '📊 After save - user_login_time: "${mmkv.decodeString(_keyLoginTime)}"',
      );

      print('✅ Login data saved successfully to MMKV');

      // Verifikasi data tersimpan
      final verification = await _verifyStoredData(username);
      if (verification) {
        print('✅ Data verification passed');
        return true;
      } else {
        print('⚠️ Data verification failed');
        return false;
      }
    } catch (e) {
      print('❌ Error saving login data to MMKV: $e');
      return false;
    }
  }

  // ✅ Verification method for MMKV
  static Future<bool> _verifyStoredData(String username) async {
    try {
      final mmkv = await _getInstance();

      final storedUsername = mmkv.decodeString(_keyUsername) ?? '';
      final isLoggedIn = mmkv.decodeBool(_keyIsLoggedIn, defaultValue: false);
      final loginTime = mmkv.decodeString(_keyLoginTime) ?? '';

      return isLoggedIn &&
          storedUsername == username.trim() &&
          loginTime.isNotEmpty;
    } catch (e) {
      print('❌ Error verifying login data: $e');
      return false;
    }
  }

  // ✅ CHECK LOGIN STATUS - MMKV Implementation
  static Future<bool> isLoggedIn() async {
    const maxRetries = 3;
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        attempt++;
        final mmkv = await _getInstance();

        final isLoggedIn = mmkv.decodeBool(_keyIsLoggedIn, defaultValue: false);
        final username = mmkv.decodeString(_keyUsername) ?? '';
        final loginTime = mmkv.decodeString(_keyLoginTime) ?? '';

        print(
          '🔍 Login check attempt $attempt: isLoggedIn=$isLoggedIn, username="$username", loginTime="$loginTime"',
        );

        // Debug: print semua keys untuk memastikan
        if (attempt == 1) {
          print('📊 All MMKV keys: ${mmkv.allKeys}');
        }

        // Validasi tambahan: pastikan loginTime ada dan tidak terlalu lama
        if (isLoggedIn && username.isNotEmpty && loginTime.isNotEmpty) {
          try {
            final loginDateTime = DateTime.parse(loginTime);
            final now = DateTime.now();
            final difference = now.difference(loginDateTime);

            // Jika login lebih dari 30 hari, consider expired
            if (difference.inDays > 30) {
              print('⚠️ Login session expired');
              await logout();
              return false;
            }
            return true;
          } catch (e) {
            print('⚠️ Error parsing login time: $e');
            // Jika parsing error, tetap return true (jangan logout otomatis)
            return true;
          }
        }

        if (attempt >= maxRetries) {
          return false;
        }

        // Tunggu sebelum retry
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      } catch (e) {
        print('❌ Login check error attempt $attempt: $e');
        if (attempt >= maxRetries) {
          return false;
        }
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
    return false;
  }

  // ✅ GET USER DATA - MMKV Implementation
  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final mmkv = await _getInstance();

      final username = mmkv.decodeString(_keyUsername) ?? '';
      final userDataJson = mmkv.decodeString(_keyUserData) ?? '';
      final loginTime = mmkv.decodeString(_keyLoginTime) ?? '';

      if (username.isEmpty) return null;

      final userData = <String, dynamic>{
        'username': username,
        'login_time': loginTime,
      };

      // Add additional data if exists
      if (userDataJson.isNotEmpty) {
        try {
          final additionalData =
              json.decode(userDataJson) as Map<String, dynamic>;
          userData.addAll(additionalData);
        } catch (e) {
          print('⚠️ Error parsing user data JSON: $e');
        }
      }

      return userData;
    } catch (e) {
      print('❌ Error getting user data from MMKV: $e');
      return null;
    }
  }

  // ✅ CLEAR LOGIN DATA - MMKV Implementation
  static Future<bool> logout() async {
    try {
      print('🚪 Logging out user...');

      final mmkv = await _getInstance();

      // MMKV removeValue operations
      mmkv.removeValue(_keyIsLoggedIn);
      mmkv.removeValue(_keyUsername);
      mmkv.removeValue(_keyUserData);
      mmkv.removeValue(_keyLoginTime);

      // Verify data cleared
      final isCleared =
          !mmkv.containsKey(_keyIsLoggedIn) &&
          !mmkv.containsKey(_keyUsername) &&
          !mmkv.containsKey(_keyUserData) &&
          !mmkv.containsKey(_keyLoginTime);

      if (isCleared) {
        print('✅ Logout successful - all data cleared from MMKV');
      } else {
        print('⚠️ Some data might not be cleared completely');
      }

      return isCleared;
    } catch (e) {
      print('❌ Error during logout: $e');
      return false;
    }
  }

  // ✅ GET USERNAME - MMKV Implementation
  static Future<String?> getUsername() async {
    const maxRetries = 2;
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        attempt++;
        final mmkv = await _getInstance();
        final username = mmkv.decodeString(_keyUsername) ?? '';

        print('🔍 Get username attempt $attempt: "$username"');

        if (username.isNotEmpty) {
          return username;
        }

        if (attempt >= maxRetries) {
          return null;
        }

        await Future.delayed(Duration(milliseconds: 200));
      } catch (e) {
        print('❌ Error getting username attempt $attempt: $e');
        if (attempt >= maxRetries) {
          return null;
        }
        await Future.delayed(Duration(milliseconds: 200));
      }
    }
    return null;
  }

  // ✅ UTILITY: Clear all MMKV data (for debugging)
  static Future<void> clearAll() async {
    try {
      final mmkv = await _getInstance();
      mmkv.clearAll();
      print('🗑️ All MMKV data cleared');
    } catch (e) {
      print('❌ Error clearing all MMKV data: $e');
    }
  }

  // ✅ UTILITY: Get all stored keys (for debugging)
  static Future<List<String>> getAllKeys() async {
    try {
      final mmkv = await _getInstance();
      final keys = mmkv.allKeys;
      print('📊 All MMKV keys: $keys');
      return keys;
    } catch (e) {
      print('❌ Error getting all keys: $e');
      return [];
    }
  }

  // ✅ UTILITY: Check MMKV health
  static Future<bool> checkHealth() async {
    try {
      final mmkv = await _getInstance();

      // Test write and read
      const testKey = 'mmkv_health_test';
      final testValue = 'test_value_${DateTime.now().millisecondsSinceEpoch}';

      mmkv.encodeString(testKey, testValue);
      final readValue = mmkv.decodeString(testKey) ?? '';
      mmkv.removeValue(testKey);

      final isHealthy = readValue == testValue;
      print('🏥 MMKV health check: ${isHealthy ? "HEALTHY" : "UNHEALTHY"}');

      return isHealthy;
    } catch (e) {
      print('❌ MMKV health check failed: $e');
      return false;
    }
  }
}
