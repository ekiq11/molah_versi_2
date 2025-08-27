import 'package:mmkv/mmkv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageHelper {
  static MMKV? _mmkv;
  static SharedPreferences? _prefs;

  // Fungsi untuk setup storage
  static Future<bool> init() async {
    try {
      // Coba MMKV dulu
      _mmkv = MMKV.defaultMMKV();

      // Backup dengan SharedPreferences
      _prefs = await SharedPreferences.getInstance();

      print('✓ Storage berhasil diinisialisasi');
      return true;
    } catch (e) {
      print('✗ Error storage: $e');
      // Tetap coba SharedPreferences sebagai fallback
      try {
        _prefs = await SharedPreferences.getInstance();
        print('✓ Menggunakan SharedPreferences sebagai backup');
        return true;
      } catch (e2) {
        print('✗ Semua storage gagal: $e2');
        return false;
      }
    }
  }

  // Simpan string dengan double backup
  static Future<bool> saveString(String key, String value) async {
    bool mmkvSuccess = false;
    bool prefsSuccess = false;

    // Coba MMKV dulu
    try {
      _mmkv?.encodeString(key, value);
      mmkvSuccess = true;
      print('✓ MMKV saved: $key = $value');
    } catch (e) {
      print('✗ MMKV save error: $e');
    }

    // Backup ke SharedPreferences
    try {
      prefsSuccess = await _prefs?.setString(key, value) ?? false;
      if (prefsSuccess) {
        print('✓ SharedPrefs saved: $key = $value');
      }
    } catch (e) {
      print('✗ SharedPrefs save error: $e');
    }

    return mmkvSuccess || prefsSuccess;
  }

  // Ambil string dengan fallback
  static String? getString(String key) {
    // Coba MMKV dulu
    try {
      String? mmkvValue = _mmkv?.decodeString(key);
      print('✓ MMKV read: $key = $mmkvValue');
      return mmkvValue;
    } catch (e) {
      print('✗ MMKV read error: $e');
    }

    // Fallback ke SharedPreferences
    try {
      String? prefsValue = _prefs?.getString(key);
      print('✓ SharedPrefs read: $key = $prefsValue');
      return prefsValue;
    } catch (e) {
      print('✗ SharedPrefs read error: $e');
    }

    print('✗ Data tidak ditemukan: $key');
    return null;
  }

  // Simpan boolean dengan double backup
  static Future<bool> saveBool(String key, bool value) async {
    bool mmkvSuccess = false;
    bool prefsSuccess = false;

    // Coba MMKV dulu
    try {
      _mmkv?.encodeBool(key, value);
      mmkvSuccess = true;
      print('✓ MMKV saved: $key = $value');
    } catch (e) {
      print('✗ MMKV save error: $e');
    }

    // Backup ke SharedPreferences
    try {
      prefsSuccess = await _prefs?.setBool(key, value) ?? false;
      if (prefsSuccess) {
        print('✓ SharedPrefs saved: $key = $value');
      }
    } catch (e) {
      print('✗ SharedPrefs save error: $e');
    }

    return mmkvSuccess || prefsSuccess;
  }

  // Ambil boolean dengan fallback
  static bool? getBool(String key, {bool defaultValue = false}) {
    // Coba MMKV dulu
    try {
      bool? mmkvValue = _mmkv?.decodeBool(key);
      print('✓ MMKV read: $key = $mmkvValue');
      return mmkvValue;
    } catch (e) {
      print('✗ MMKV read error: $e');
    }

    // Fallback ke SharedPreferences
    try {
      bool? prefsValue = _prefs?.getBool(key);
      print('✓ SharedPrefs read: $key = $prefsValue');
      return prefsValue;
    } catch (e) {
      print('✗ SharedPrefs read error: $e');
    }

    print('✗ Data tidak ditemukan: $key, menggunakan default: $defaultValue');
    return defaultValue;
  }

  // Hapus data dari kedua storage
  static Future<bool> remove(String key) async {
    bool mmkvSuccess = false;
    bool prefsSuccess = false;

    try {
      _mmkv?.removeValue(key);
      mmkvSuccess = true;
      print('✓ MMKV removed: $key');
    } catch (e) {
      print('✗ MMKV remove error: $e');
    }

    try {
      prefsSuccess = await _prefs?.remove(key) ?? false;
      if (prefsSuccess) {
        print('✓ SharedPrefs removed: $key');
      }
    } catch (e) {
      print('✗ SharedPrefs remove error: $e');
    }

    return mmkvSuccess || prefsSuccess;
  }

  // Debug: Cek semua data yang tersimpan
  static void debugPrintAll() {
    print('=== DEBUG STORAGE ===');

    // Cek beberapa key umum
    List<String> commonKeys = ['user_logged_in', 'username', 'user_token'];

    for (String key in commonKeys) {
      try {
        // MMKV
        var mmkvValue = _mmkv?.decodeString(key) ?? _mmkv?.decodeBool(key);
        print('MMKV [$key]: $mmkvValue');

        // SharedPreferences
        var prefsValue = _prefs?.get(key);
        print('SharedPrefs [$key]: $prefsValue');
      } catch (e) {
        print('Error checking $key: $e');
      }
    }
    print('=== END DEBUG ===');
  }
}
