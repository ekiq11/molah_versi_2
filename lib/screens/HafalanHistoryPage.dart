// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class HafalanHistoryPage extends StatefulWidget {
  final String nisn;
  final String? namaSantri;

  const HafalanHistoryPage({Key? key, required this.nisn, this.namaSantri})
    : super(key: key);

  @override
  State<HafalanHistoryPage> createState() => _HafalanHistoryPageState();
}

class HafalanData {
  final String waktu;
  final String tanggal;
  final String nisn;
  final String namaSantri;
  final String mustami;
  final String surahAwal;
  final String ayatAwal;
  final String surahAkhir;
  final String ayatAkhir;
  final String nilai;
  final String keterangan;

  HafalanData({
    required this.waktu,
    required this.tanggal,
    required this.nisn,
    required this.namaSantri,
    required this.mustami,
    required this.surahAwal,
    required this.ayatAwal,
    required this.surahAkhir,
    required this.ayatAkhir,
    required this.nilai,
    required this.keterangan,
  });

  factory HafalanData.fromCsvRow(List<dynamic> row) {
    return HafalanData(
      waktu: row.length > 0 ? row[0].toString() : '',
      tanggal: row.length > 1 ? row[1].toString() : '',
      nisn: row.length > 2 ? row[2].toString().replaceAll("'", "").trim() : '',
      namaSantri: row.length > 3 ? row[3].toString() : '',
      mustami: row.length > 4 ? row[4].toString() : '',
      surahAwal: row.length > 5 ? row[5].toString() : '',
      ayatAwal: row.length > 6 ? row[6].toString() : '',
      surahAkhir: row.length > 7 ? row[7].toString() : '',
      ayatAkhir: row.length > 8 ? row[8].toString() : '',
      nilai: row.length > 9 ? row[9].toString() : '',
      keterangan: row.length > 10 ? row.sublist(10).join(' ') : '',
    );
  }

  // Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'waktu': waktu,
      'tanggal': tanggal,
      'nisn': nisn,
      'namaSantri': namaSantri,
      'mustami': mustami,
      'surahAwal': surahAwal,
      'ayatAwal': ayatAwal,
      'surahAkhir': surahAkhir,
      'ayatAkhir': ayatAkhir,
      'nilai': nilai,
      'keterangan': keterangan,
    };
  }

  // Create from JSON for caching
  factory HafalanData.fromJson(Map<String, dynamic> json) {
    return HafalanData(
      waktu: json['waktu'] ?? '',
      tanggal: json['tanggal'] ?? '',
      nisn: json['nisn'] ?? '',
      namaSantri: json['namaSantri'] ?? '',
      mustami: json['mustami'] ?? '',
      surahAwal: json['surahAwal'] ?? '',
      ayatAwal: json['ayatAwal'] ?? '',
      surahAkhir: json['surahAkhir'] ?? '',
      ayatAkhir: json['ayatAkhir'] ?? '',
      nilai: json['nilai'] ?? '',
      keterangan: json['keterangan'] ?? '',
    );
  }
}

class _HafalanHistoryPageState extends State<HafalanHistoryPage> {
  List<HafalanData> _recentData = [];
  List<HafalanData> _allData = []; // Store all data for different sorting
  bool _loading = true;
  String _error = '';
  String _currentNamaSantri = '';
  bool _isFromCache = false;
  String _sortBy = 'newest'; // newest, oldest, name, grade
  String _lastSuccessfulUrl = ''; // Track which URL worked

  // PERBAIKAN: Multiple CSV URLs dengan berbagai format export
  static const List<String> _csvUrls = [
    // URL utama dengan gid spesifik
    'https://docs.google.com/spreadsheets/d/1BZbBczH2OY8SB2_1tDpKf_B8WvOyk8TJl4esfT-dgzw/export?format=csv&gid=2071598361',

    // URL dengan export default (sheet pertama)
    'https://docs.google.com/spreadsheets/d/1BZbBczH2OY8SB2_1tDpKf_B8WvOyk8TJl4esfT-dgzw/export?format=csv',

    // URL dengan format sharing alternatif
    'https://docs.google.com/spreadsheets/d/1BZbBczH2OY8SB2_1tDpKf_B8WvOyk8TJl4esfT-dgzw/gviz/tq?tqx=out:csv&gid=2071598361',

    // URL dengan format TSV sebagai backup
    'https://docs.google.com/spreadsheets/d/1BZbBczH2OY8SB2_1tDpKf_B8WvOyk8TJl4esfT-dgzw/export?format=tsv&gid=2071598361',

    // URL dengan format ODS sebagai backup terakhir
    'https://docs.google.com/spreadsheets/d/1BZbBczH2OY8SB2_1tDpKf_B8WvOyk8TJl4esfT-dgzw/export?format=ods',
  ];

  // Cache duration: 5 menit (lebih pendek untuk testing)
  static const int CACHE_DURATION_MINUTES = 5;

  @override
  void initState() {
    super.initState();
    // PERBAIKAN: Inisialisasi dengan delay untuk memastikan widget tree sudah siap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndLoadData();
    });
  }

  // PERBAIKAN: Method baru untuk inisialisasi yang lebih aman
  Future<void> _initializeAndLoadData() async {
    try {
      // Pastikan Flutter engine sudah siap
      await Future.delayed(Duration(milliseconds: 100));

      // Pastikan context masih valid
      if (!mounted) return;

      await _loadData();
    } catch (e) {
      print('💥 Error in initialization: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Gagal inisialisasi aplikasi: $e';
        });
      }
    }
  }

  // Apply sorting based on current sort preference
  void _applySorting() {
    List<HafalanData> sortedData = List.from(_allData);

    switch (_sortBy) {
      case 'newest':
        sortedData.sort((a, b) {
          DateTime? dateA = _parseDateTime(a);
          DateTime? dateB = _parseDateTime(b);
          if (dateA == null && dateB == null) {
            return '${b.tanggal} ${b.waktu}'.compareTo(
              '${a.tanggal} ${a.waktu}',
            );
          } else if (dateA == null) {
            return 1;
          } else if (dateB == null) {
            return -1;
          } else {
            return dateB.compareTo(dateA);
          }
        });
        break;
      case 'oldest':
        sortedData.sort((a, b) {
          DateTime? dateA = _parseDateTime(a);
          DateTime? dateB = _parseDateTime(b);
          if (dateA == null && dateB == null) {
            return '${a.tanggal} ${a.waktu}'.compareTo(
              '${b.tanggal} ${b.waktu}',
            );
          } else if (dateA == null) {
            return 1;
          } else if (dateB == null) {
            return -1;
          } else {
            return dateA.compareTo(dateB);
          }
        });
        break;
      case 'grade':
        sortedData.sort((a, b) {
          // Sort by grade (A > B > C > D > empty)
          String gradeA = a.nilai.toUpperCase();
          String gradeB = b.nilai.toUpperCase();

          Map<String, int> gradeOrder = {'A': 4, 'B': 3, 'C': 2, 'D': 1, '': 0};

          int orderA = gradeOrder[gradeA.isNotEmpty ? gradeA[0] : ''] ?? 0;
          int orderB = gradeOrder[gradeB.isNotEmpty ? gradeB[0] : ''] ?? 0;

          if (orderA != orderB) {
            return orderB.compareTo(orderA); // Higher grade first
          }

          // If same grade, sort by newest date
          DateTime? dateA = _parseDateTime(a);
          DateTime? dateB = _parseDateTime(b);
          if (dateA != null && dateB != null) {
            return dateB.compareTo(dateA);
          }
          return 0;
        });
        break;
    }

    if (mounted) {
      setState(() {
        _recentData = sortedData.take(10).toList();
      });
    }
  }

  // Load data from cache first, then fetch if needed
  Future<void> _loadData() async {
    try {
      if (mounted) {
        setState(() {
          _loading = true;
          _error = '';
        });
      }

      // Try to load from cache first
      bool cacheLoaded = await _loadFromCache();

      if (cacheLoaded) {
        print('✅ Data loaded from cache');
        if (mounted) {
          setState(() {
            _loading = false;
            _isFromCache = true;
          });
        }

        // Check if cache is expired and refresh in background if needed
        if (await _isCacheExpired()) {
          print('🔄 Cache expired, refreshing in background...');
          _refreshDataInBackground();
        }
      } else {
        print('❌ No cache found, fetching from server...');
        await _fetchFromServer();
      }
    } catch (e) {
      print('💥 Error loading data: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Terjadi kesalahan: $e';
        });
      }
    }
  }

  // PERBAIKAN: Load data from cache dengan error handling yang lebih baik
  Future<bool> _loadFromCache() async {
    try {
      // PERBAIKAN: Gunakan getInstance dengan timeout dan error handling
      SharedPreferences? prefs;

      try {
        // Timeout untuk getInstance
        prefs = await SharedPreferences.getInstance().timeout(
          Duration(seconds: 10),
        );
      } on Exception catch (e) {
        print('❌ SharedPreferences getInstance failed: $e');
        // Jika SharedPreferences gagal, return false agar langsung fetch dari server
        return false;
      }

      String cacheKey = 'hafalan_data_${widget.nisn}';

      // PERBAIKAN: Tambahkan try-catch untuk setiap operasi SharedPreferences
      String? cachedData;
      String? cachedTimestamp;
      String? cachedName;

      try {
        cachedData = prefs.getString(cacheKey);
        cachedTimestamp = prefs.getString('${cacheKey}_timestamp');
        cachedName = prefs.getString('${cacheKey}_name');
      } catch (e) {
        print('❌ Error reading SharedPreferences: $e');
        return false;
      }

      if (cachedData != null && cachedTimestamp != null) {
        try {
          List<dynamic> jsonList = json.decode(cachedData);
          List<HafalanData> hafalanList = jsonList
              .map((item) => HafalanData.fromJson(item))
              .toList();

          if (hafalanList.isNotEmpty && mounted) {
            setState(() {
              _recentData = hafalanList;
              _allData = hafalanList; // Store for sorting
              _currentNamaSantri =
                  cachedName ??
                  widget.namaSantri ??
                  hafalanList.first.namaSantri;
            });
            return true;
          }
        } catch (e) {
          print('❌ Error parsing cached data: $e');
          // Jika parsing gagal, hapus cache yang rusak
          try {
            await prefs.remove(cacheKey);
            await prefs.remove('${cacheKey}_timestamp');
            await prefs.remove('${cacheKey}_name');
          } catch (removeError) {
            print('❌ Error removing corrupted cache: $removeError');
          }
        }
      }
      return false;
    } catch (e) {
      print('❌ Error loading cache: $e');
      return false;
    }
  }

  // PERBAIKAN: Check if cache is expired dengan error handling
  Future<bool> _isCacheExpired() async {
    try {
      SharedPreferences? prefs;

      try {
        prefs = await SharedPreferences.getInstance().timeout(
          Duration(seconds: 5),
        );
      } catch (e) {
        print('❌ SharedPreferences getInstance failed in isCacheExpired: $e');
        return true; // Anggap expired jika tidak bisa akses SharedPreferences
      }

      String cacheKey = 'hafalan_data_${widget.nisn}';

      try {
        String? cachedTimestamp = prefs.getString('${cacheKey}_timestamp');

        if (cachedTimestamp != null) {
          DateTime cacheTime = DateTime.parse(cachedTimestamp);
          DateTime now = DateTime.now();
          Duration difference = now.difference(cacheTime);

          return difference.inMinutes > CACHE_DURATION_MINUTES;
        }
      } catch (e) {
        print('❌ Error checking cache expiration: $e');
      }

      return true;
    } catch (e) {
      print('❌ General error in isCacheExpired: $e');
      return true;
    }
  }

  // PERBAIKAN: Save data to cache dengan error handling yang lebih baik
  Future<void> _saveToCache(List<HafalanData> data, String namaSantri) async {
    try {
      SharedPreferences? prefs;

      try {
        prefs = await SharedPreferences.getInstance().timeout(
          Duration(seconds: 10),
        );
      } catch (e) {
        print('❌ SharedPreferences getInstance failed in saveToCache: $e');
        // Jika tidak bisa save ke cache, tidak masalah - aplikasi tetap berjalan
        return;
      }

      String cacheKey = 'hafalan_data_${widget.nisn}';
      List<Map<String, dynamic>> jsonList = data
          .map((item) => item.toJson())
          .toList();

      try {
        await prefs.setString(cacheKey, json.encode(jsonList));
        await prefs.setString(
          '${cacheKey}_timestamp',
          DateTime.now().toIso8601String(),
        );
        await prefs.setString('${cacheKey}_name', namaSantri);

        print('💾 Data saved to cache for NISN: ${widget.nisn}');
      } catch (e) {
        print('❌ Error writing to SharedPreferences: $e');
        // Tidak throw error - biarkan aplikasi tetap berjalan tanpa cache
      }
    } catch (e) {
      print('❌ Error saving to cache: $e');
      // Tidak throw error - cache adalah fitur optional
    }
  }

  // PERBAIKAN: Clear cache untuk debugging dengan error handling
  Future<void> _clearCache() async {
    try {
      SharedPreferences? prefs;

      try {
        prefs = await SharedPreferences.getInstance().timeout(
          Duration(seconds: 10),
        );
      } catch (e) {
        print('❌ SharedPreferences getInstance failed in clearCache: $e');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Tidak dapat mengakses cache. Memuat data langsung dari server...',
              ),
              backgroundColor: Colors.orange[600],
            ),
          );

          // Langsung fetch dari server jika SharedPreferences bermasalah
          await _fetchFromServer(showLoading: true);
        }
        return;
      }

      String cacheKey = 'hafalan_data_${widget.nisn}';

      try {
        await prefs.remove(cacheKey);
        await prefs.remove('${cacheKey}_timestamp');
        await prefs.remove('${cacheKey}_name');
        await prefs.remove('last_successful_url');

        print('🗑️ Cache cleared for NISN: ${widget.nisn}');
      } catch (e) {
        print('❌ Error clearing cache: $e');
      }

      // Show snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cache dibersihkan. Memuat ulang data...'),
            backgroundColor: Colors.orange[600],
          ),
        );

        // Reload data
        await _fetchFromServer(showLoading: true);
      }
    } catch (e) {
      print('❌ Error clearing cache: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal membersihkan cache. Memuat data dari server...',
            ),
            backgroundColor: Colors.red[600],
          ),
        );

        await _fetchFromServer(showLoading: true);
      }
    }
  }

  // Refresh data in background without showing loading
  Future<void> _refreshDataInBackground() async {
    try {
      await _fetchFromServer(showLoading: false);
      print('✅ Background refresh completed');
    } catch (e) {
      print('❌ Background refresh failed: $e');
    }
  }

  // Manual refresh (pull to refresh or button)
  Future<void> _refreshData() async {
    await _fetchFromServer(showLoading: true);
  }

  String _normalizeNisn(String nisn) {
    String cleaned = nisn.replaceAll("'", "").trim();
    if (cleaned.length == 9 &&
        cleaned.isNotEmpty &&
        RegExp(r'^\d+$').hasMatch(cleaned)) {
      return '0$cleaned';
    }
    return cleaned;
  }

  bool _isNisnMatch(String csvNisn, String targetNisn) {
    String cleanedCsvNisn = csvNisn.replaceAll("'", "").trim();
    String normalizedCsvNisn = _normalizeNisn(csvNisn);
    String normalizedTargetNisn = _normalizeNisn(targetNisn);

    return cleanedCsvNisn == targetNisn ||
        cleanedCsvNisn == normalizedTargetNisn ||
        normalizedCsvNisn == targetNisn ||
        normalizedCsvNisn == normalizedTargetNisn;
  }

  // Improved date parsing function with better edge case handling
  DateTime? _parseDateTime(HafalanData data) {
    try {
      String dateStr = data.tanggal.trim();
      String timeStr = data.waktu.trim();

      // Skip empty dates
      if (dateStr.isEmpty) {
        print('⚠️ Empty date string');
        return null;
      }

      // Handle combined date-time in tanggal field
      if (dateStr.contains(' ') && timeStr.isEmpty) {
        List<String> parts = dateStr.split(' ');
        dateStr = parts[0];
        if (parts.length > 1) {
          timeStr = parts.sublist(1).join(' ');
        }
      }

      // Handle various date formats
      DateTime? parsedDate;

      // Try different date formats with more flexibility
      List<Map<String, dynamic>> dateFormats = [
        {
          'format': 'yyyy-MM-dd',
          'separator': '-',
          'order': ['year', 'month', 'day'],
        }, // 2024-01-15
        {
          'format': 'dd/MM/yyyy',
          'separator': '/',
          'order': ['day', 'month', 'year'],
        }, // 15/01/2024
        {
          'format': 'dd-MM-yyyy',
          'separator': '-',
          'order': ['day', 'month', 'year'],
        }, // 15-01-2024
        {
          'format': 'MM/dd/yyyy',
          'separator': '/',
          'order': ['month', 'day', 'year'],
        }, // 01/15/2024
        {
          'format': 'yyyy/MM/dd',
          'separator': '/',
          'order': ['year', 'month', 'day'],
        }, // 2024/01/15
        {
          'format': 'd/M/yyyy',
          'separator': '/',
          'order': ['day', 'month', 'year'],
        }, // 5/1/2024
        {
          'format': 'd-M-yyyy',
          'separator': '-',
          'order': ['day', 'month', 'year'],
        }, // 5-1-2024
      ];

      for (Map<String, dynamic> formatInfo in dateFormats) {
        try {
          String separator = formatInfo['separator'];
          List<String> order = formatInfo['order'];

          List<String> dateParts;
          if (dateStr.contains(separator)) {
            dateParts = dateStr.split(separator);
          } else {
            continue;
          }

          if (dateParts.length == 3) {
            // Parse based on order
            int year = 0, month = 0, day = 0;

            for (int i = 0; i < 3; i++) {
              int value = int.parse(dateParts[i].trim());
              switch (order[i]) {
                case 'year':
                  year = value;
                  // Handle 2-digit years
                  if (year < 100) {
                    year += (year < 50) ? 2000 : 1900;
                  }
                  break;
                case 'month':
                  month = value;
                  break;
                case 'day':
                  day = value;
                  break;
              }
            }

            // Enhanced validation
            if (_isValidDate(year, month, day)) {
              parsedDate = DateTime(year, month, day);
              print(
                '✅ Parsed date: $dateStr -> ${parsedDate.toString().substring(0, 10)}',
              );
              break;
            }
          }
        } catch (e) {
          continue;
        }
      }

      // If date parsing failed, try ISO format as last resort
      if (parsedDate == null) {
        try {
          parsedDate = DateTime.parse(dateStr);
          print(
            '✅ ISO parsed: $dateStr -> ${parsedDate.toString().substring(0, 10)}',
          );
        } catch (e) {
          print('⚠️ Failed to parse date: $dateStr');
          return null;
        }
      }

      // Parse time if available
      if (timeStr.isNotEmpty && timeStr != dateStr) {
        try {
          // Clean time string (remove extra spaces, handle AM/PM)
          String cleanTimeStr = timeStr.trim().toLowerCase();
          bool isPM = cleanTimeStr.contains('pm');
          bool isAM = cleanTimeStr.contains('am');

          // Remove AM/PM markers
          cleanTimeStr = cleanTimeStr.replaceAll(RegExp(r'\s*(am|pm)\s*'), '');

          List<String> timeParts = cleanTimeStr.split(':');
          if (timeParts.length >= 2) {
            int hour = int.parse(timeParts[0].trim());
            int minute = int.parse(timeParts[1].trim());
            int second = timeParts.length > 2
                ? int.parse(timeParts[2].trim())
                : 0;

            // Handle 12-hour format
            if (isPM && hour != 12) {
              hour += 12;
            } else if (isAM && hour == 12) {
              hour = 0;
            }

            if (hour >= 0 &&
                hour <= 23 &&
                minute >= 0 &&
                minute <= 59 &&
                second >= 0 &&
                second <= 59) {
              parsedDate = DateTime(
                parsedDate.year,
                parsedDate.month,
                parsedDate.day,
                hour,
                minute,
                second,
              );
              print(
                '✅ Added time: $timeStr -> ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
              );
            }
          }
        } catch (e) {
          print('⚠️ Failed to parse time: $timeStr, error: $e');
          // Keep the date part even if time parsing fails
        }
      }

      return parsedDate;
    } catch (e) {
      print('💥 Error parsing datetime for ${data.tanggal} ${data.waktu}: $e');
      return null;
    }
  }

  // Helper function to validate date
  bool _isValidDate(int year, int month, int day) {
    if (year < 1900 || year > 2100) return false;
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;

    // Check days in month
    List<int> daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

    // Check for leap year
    bool isLeapYear = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
    if (isLeapYear && month == 2) {
      daysInMonth[1] = 29;
    }

    return day <= daysInMonth[month - 1];
  }

  // PERBAIKAN: Try multiple URLs sequentially dengan timeout yang lebih baik
  Future<void> _fetchFromServer({bool showLoading = true}) async {
    try {
      if (showLoading && mounted) {
        setState(() {
          _loading = true;
          _error = '';
        });
      }

      // PERBAIKAN: Load last successful URL from preferences dengan error handling
      SharedPreferences? prefs;
      String? lastUrl;

      try {
        prefs = await SharedPreferences.getInstance().timeout(
          Duration(seconds: 5),
        );
        lastUrl = prefs.getString('last_successful_url');
      } catch (e) {
        print('❌ Cannot access SharedPreferences for last URL: $e');
        // Lanjutkan tanpa last successful URL
      }

      List<String> urlsToTry = List.from(_csvUrls);

      // If we have a last successful URL, try it first
      if (lastUrl != null && _csvUrls.contains(lastUrl)) {
        urlsToTry.remove(lastUrl);
        urlsToTry.insert(0, lastUrl);
      }

      http.Response? response;
      String? successfulUrl;
      String lastError = '';

      // Try each URL until one works
      for (String url in urlsToTry) {
        try {
          print('🔄 Trying URL: $url');

          // PERBAIKAN: Timeout yang lebih pendek dan error handling yang lebih baik
          response = await http
              .get(
                Uri.parse(url),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                  'Accept': 'text/csv,text/plain,application/csv,*/*',
                },
              )
              .timeout(Duration(seconds: 10)); // Reduced timeout

          if (response.statusCode == 200 && response.body.isNotEmpty) {
            print('✅ Success with URL: $url');
            successfulUrl = url;
            break;
          } else {
            lastError = 'HTTP ${response.statusCode}';
            print('❌ Failed with URL: $url - Status: ${response.statusCode}');
          }
        } catch (e) {
          lastError = e.toString();
          print('❌ Error with URL: $url - Error: $e');
          continue;
        }
      }

      if (response == null ||
          response.statusCode != 200 ||
          successfulUrl == null) {
        throw Exception('Semua URL gagal diakses. Error terakhir: $lastError');
      }

      // PERBAIKAN: Save successful URL for next time dengan error handling
      if (prefs != null) {
        try {
          await prefs.setString('last_successful_url', successfulUrl);
        } catch (e) {
          print('❌ Cannot save successful URL: $e');
          // Tidak critical, lanjutkan
        }
      }

      // Process CSV data
      List<List<dynamic>> csvData;

      try {
        // Handle different formats
        if (successfulUrl.contains('format=tsv')) {
          // TSV format
          csvData = CsvToListConverter(
            fieldDelimiter: '\t',
          ).convert(response.body);
        } else {
          // CSV format (default)
          csvData = CsvToListConverter().convert(response.body);
        }
      } catch (e) {
        print('❌ CSV parsing error: $e');
        // Try with different delimiters
        try {
          csvData = CsvToListConverter(
            fieldDelimiter: ';',
          ).convert(response.body);
        } catch (e2) {
          throw Exception('Gagal memproses format data: $e2');
        }
      }

      print('📊 Total rows in CSV: ${csvData.length}');

      if (csvData.isEmpty) {
        throw Exception('Data CSV kosong');
      }

      // Skip header and filter by NISN
      final filtered = csvData
          .skip(1)
          .where((row) {
            if (row.length > 2) {
              bool match = _isNisnMatch(row[2].toString(), widget.nisn);
              if (match) {
                print('✅ Found match: ${row[2]} for ${widget.nisn}');
              }
              return match;
            }
            return false;
          })
          .map((row) => HafalanData.fromCsvRow(row))
          .toList();

      print('📋 Filtered data count: ${filtered.length}');

      if (filtered.isNotEmpty) {
        String namaSantri = widget.namaSantri ?? filtered.first.namaSantri;

        // Sort by date (newest first)
        filtered.sort((a, b) {
          DateTime? dateA = _parseDateTime(a);
          DateTime? dateB = _parseDateTime(b);

          // Handle null dates (put them at the end)
          if (dateA == null && dateB == null) {
            // Fallback to string comparison
            String fullA = '${a.tanggal} ${a.waktu}';
            String fullB = '${b.tanggal} ${b.waktu}';
            return fullB.compareTo(fullA);
          } else if (dateA == null) {
            return 1; // a goes after b
          } else if (dateB == null) {
            return -1; // a goes before b
          } else {
            // Both dates are valid, sort newest first
            return dateB.compareTo(dateA);
          }
        });

        // Take only the most recent 10 records for display
        List<HafalanData> recentData = filtered.take(10).toList();

        // Debug: Print sorted dates
        print('📅 Sorted data (newest first):');
        for (int i = 0; i < recentData.length && i < 5; i++) {
          DateTime? parsed = _parseDateTime(recentData[i]);
          print(
            '${i + 1}. ${recentData[i].tanggal} ${recentData[i].waktu} -> $parsed',
          );
        }

        // Save to cache (save all filtered data, not just recent)
        await _saveToCache(filtered, namaSantri);

        if (mounted) {
          setState(() {
            _recentData = recentData;
            _allData = filtered; // Store all data for sorting
            _currentNamaSantri = namaSantri;
            _loading = false;
            _isFromCache = false;
            _error = '';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Tidak ada data ditemukan untuk NISN: ${widget.nisn}';
          });
        }
      }
    } catch (e) {
      print('💥 Fetch error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Terjadi kesalahan: $e';
        });
      }
    }
  }

  String _formatDate(String datetime) {
    try {
      if (datetime.contains(' ')) {
        List<String> parts = datetime.split(' ');
        String datePart = parts[0];
        List<String> dateComponents = datePart.split('-');
        if (dateComponents.length == 3) {
          return '${dateComponents[2]}/${dateComponents[1]}/${dateComponents[0]}';
        }
      }
      return datetime;
    } catch (e) {
      return datetime;
    }
  }

  String _formatTime(String datetime) {
    try {
      if (datetime.contains(' ')) {
        return datetime.split(' ')[1].substring(0, 5); // HH:MM
      }
      return datetime;
    } catch (e) {
      return datetime;
    }
  }

  Color _getNilaiColor(String nilai) {
    if (nilai.isEmpty) return Colors.grey[400]!;
    if (nilai.toUpperCase().contains('A')) return Colors.green[600]!;
    if (nilai.toUpperCase().contains('B')) return Colors.blue[600]!;
    if (nilai.toUpperCase().contains('C')) return Colors.orange[600]!;
    return Colors.red[600]!;
  }

  Widget _buildSimpleCard(HafalanData data, int index) {
    // Check if this is from today or recent
    bool isToday = false;
    bool isRecent = false;

    DateTime? parsedDate = _parseDateTime(data);
    if (parsedDate != null) {
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      DateTime cardDate = DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
      );

      isToday = cardDate == today;
      isRecent = now.difference(parsedDate).inDays <= 3 && !isToday;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isToday
            ? Border.all(color: Colors.green[400]!, width: 2)
            : isRecent
            ? Border.all(color: Colors.blue[300]!, width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header dengan tanggal, indikator, dan nilai
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Ranking indicator
                      if (index < 3)
                        Container(
                          margin: EdgeInsets.only(right: 8),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: index == 0
                                ? Colors.amber[600]
                                : index == 1
                                ? Colors.grey[400]
                                : Colors.orange[400],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                      // Date indicator
                      if (isToday)
                        Container(
                          margin: EdgeInsets.only(right: 6),
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'HARI INI',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else if (isRecent)
                        Container(
                          margin: EdgeInsets.only(right: 6),
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'BARU',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 4),
                      Text(
                        _formatDate(data.tanggal),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 4),
                      Text(
                        _formatTime(data.waktu),
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                if (data.nilai.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getNilaiColor(data.nilai),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      data.nilai,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),

            SizedBox(height: 12),

            // Mustami
            Row(
              children: [
                Icon(Icons.person, size: 18, color: Colors.teal[600]),
                SizedBox(width: 6),
                Text(
                  'Mustami: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                Expanded(
                  child: Text(
                    data.mustami,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.teal[700],
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 8),

            // Setoran
            Row(
              children: [
                Icon(Icons.book, size: 18, color: Colors.blue[600]),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${data.surahAwal} ${data.ayatAwal} → ${data.surahAkhir} ${data.ayatAkhir}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),

            // Keterangan
            if (data.keterangan.isNotEmpty) ...[
              SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, size: 18, color: Colors.orange[600]),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      data.keterangan,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              color: Colors.grey[700],
              size: 18,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Riwayat Hafalan',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.teal[600],
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          // Show cache indicator
          if (_isFromCache)
            Container(
              margin: EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Cache',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

          // Debug: Clear cache button (hanya untuk testing)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'refresh') {
                _refreshData();
              } else if (value == 'clear_cache') {
                _clearCache();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 8),
                    Text('Refresh Data'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_cache',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, size: 18, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Clear Cache', style: TextStyle(color: Colors.orange)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Minimal Header - Santri Info Only
          if (_currentNamaSantri.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.teal[600]!, Colors.teal[500]!],
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    child: Text(
                      _currentNamaSantri[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentNamaSantri,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "NISN: ${widget.nisn}",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_recentData.length} setoran',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Content
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.teal[600]),
                        SizedBox(height: 16),
                        Text(
                          "Memuat data hafalan...",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Mencoba beberapa sumber data...",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : _error.isNotEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Gagal Memuat Data',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[600],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _error,
                            style: TextStyle(color: Colors.red[500]),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          Column(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _refreshData,
                                icon: Icon(Icons.refresh),
                                label: Text("Coba Lagi"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal[600],
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: _clearCache,
                                icon: Icon(Icons.clear_all, size: 16),
                                label: Text("Clear Cache & Coba Lagi"),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.orange[600],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: Colors.blue[600],
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Tips Troubleshooting:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[700],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '• Pastikan koneksi internet stabil\n'
                                  '• Coba clear cache jika data lama\n'
                                  '• Periksa apakah NISN sudah benar\n'
                                  '• Hubungi admin jika masih bermasalah',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _recentData.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text(
                          "Tidak ada data hafalan",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          "untuk NISN ${widget.nisn}",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _refreshData,
                          icon: Icon(Icons.refresh),
                          label: Text("Muat Ulang"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal[600],
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refreshData,
                    color: Colors.teal[600],
                    child: Column(
                      children: [
                        // Header info
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.history,
                                color: Colors.teal[600],
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '10 Setoran Terakhir',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal[700],
                                ),
                              ),
                              Spacer(),
                              if (_isFromCache)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Data Cache',
                                    style: TextStyle(
                                      color: Colors.orange[700],
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // List data
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.only(bottom: 16),
                            itemCount: _recentData.length,
                            itemBuilder: (context, index) {
                              return _buildSimpleCard(
                                _recentData[index],
                                index,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
