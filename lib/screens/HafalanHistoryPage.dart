// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class HafalanHistoryPage extends StatefulWidget {
  final String nisn;
  final String? namaSantri;

  const HafalanHistoryPage({super.key, required this.nisn, this.namaSantri});

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
      waktu: row.isNotEmpty ? row[0].toString() : '',
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
  // Pagination variables
  List<HafalanData> _displayedData = []; // Data yang ditampilkan
  List<HafalanData> _allData = []; // Semua data dari server
  bool _loading = true;
  bool _loadingMore = false; // Loading untuk pagination
  String _error = '';
  String _currentNamaSantri = '';
  bool _isFromCache = false;
  final String _sortBy = 'newest';

  // Pagination settings
  static const int _itemsPerPage = 10;
  int _currentPage = 0;
  bool _hasMoreData = true;

  // ScrollController untuk detect scroll end
  final ScrollController _scrollController = ScrollController();

  static const List<String> _csvUrls = [
    'https://docs.google.com/spreadsheets/d/1BZbBczH2OY8SB2_1tDpKf_B8WvOyk8TJl4esfT-dgzw/export?format=csv&gid=2071598361',
    'https://docs.google.com/spreadsheets/d/1BZbBczH2OY8SB2_1tDpKf_B8WvOyk8TJl4esfT-dgzw/export?format=csv',
    'https://docs.google.com/spreadsheets/d/1BZbBczH2OY8SB2_1tDpKf_B8WvOyk8TJl4esfT-dgzw/gviz/tq?tqx=out:csv&gid=2071598361',
    'https://docs.google.com/spreadsheets/d/1BZbBczH2OY8SB2_1tDpKf_B8WvOyk8TJl4esfT-dgzw/export?format=tsv&gid=2071598361',
    'https://docs.google.com/spreadsheets/d/1BZbBczH2OY8SB2_1tDpKf_B8WvOyk8TJl4esfT-dgzw/export?format=ods',
  ];

  static const int CACHE_DURATION_MINUTES = 5;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndLoadData();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Detect when user scrolls to bottom
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  // Load more data for pagination
  void _loadMoreData() {
    if (_loadingMore || !_hasMoreData) return;

    setState(() {
      _loadingMore = true;
    });

    // Simulate loading delay (optional)
    Future.delayed(Duration(milliseconds: 500), () {
      _loadNextPage();
    });
  }

  // Load next page of data
  void _loadNextPage() {
    if (!mounted) return;

    int startIndex = (_currentPage + 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;

    if (startIndex >= _allData.length) {
      // No more data
      setState(() {
        _hasMoreData = false;
        _loadingMore = false;
      });
      return;
    }

    List<HafalanData> nextPageData = _allData
        .skip(startIndex)
        .take(_itemsPerPage)
        .toList();

    setState(() {
      _displayedData.addAll(nextPageData);
      _currentPage++;
      _loadingMore = false;
      _hasMoreData = endIndex < _allData.length;
    });

    print(
      '📄 Loaded page ${_currentPage + 1}, showing ${_displayedData.length} of ${_allData.length} items',
    );
  }

  Future<void> _initializeAndLoadData() async {
    try {
      await Future.delayed(Duration(milliseconds: 100));
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
          String gradeA = a.nilai.toUpperCase();
          String gradeB = b.nilai.toUpperCase();
          Map<String, int> gradeOrder = {'A': 4, 'B': 3, 'C': 2, 'D': 1, '': 0};
          int orderA = gradeOrder[gradeA.isNotEmpty ? gradeA[0] : ''] ?? 0;
          int orderB = gradeOrder[gradeB.isNotEmpty ? gradeB[0] : ''] ?? 0;
          if (orderA != orderB) {
            return orderB.compareTo(orderA);
          }
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
        _allData = sortedData;
        // Reset pagination
        _currentPage = 0;
        _hasMoreData = _allData.length > _itemsPerPage;
        _displayedData = _allData.take(_itemsPerPage).toList();
      });
    }
  }

  Future<void> _loadData() async {
    try {
      if (mounted) {
        setState(() {
          _loading = true;
          _error = '';
        });
      }

      bool cacheLoaded = await _loadFromCache();

      if (cacheLoaded) {
        print('✅ Data loaded from cache');
        if (mounted) {
          setState(() {
            _loading = false;
            _isFromCache = true;
          });
        }

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

  Future<bool> _loadFromCache() async {
    try {
      SharedPreferences? prefs;

      try {
        prefs = await SharedPreferences.getInstance().timeout(
          Duration(seconds: 10),
        );
      } on Exception catch (e) {
        print('❌ SharedPreferences getInstance failed: $e');
        return false;
      }

      String cacheKey = 'hafalan_data_${widget.nisn}';
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

      if (cachedTimestamp != null && cachedData != null) {
        try {
          List<dynamic> jsonList = json.decode(cachedData);
          List<HafalanData> hafalanList = jsonList
              .map((item) => HafalanData.fromJson(item))
              .toList();

          if (hafalanList.isNotEmpty && mounted) {
            setState(() {
              _allData = hafalanList;
              // Reset pagination for cache data
              _currentPage = 0;
              _hasMoreData = _allData.length > _itemsPerPage;
              _displayedData = _allData.take(_itemsPerPage).toList();
              _currentNamaSantri =
                  cachedName ??
                  widget.namaSantri ??
                  hafalanList.first.namaSantri;
            });
            return true;
          }
        } catch (e) {
          print('❌ Error parsing cached data: $e');
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

  Future<bool> _isCacheExpired() async {
    try {
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance().timeout(
          Duration(seconds: 5),
        );
      } catch (e) {
        print('❌ SharedPreferences getInstance failed in isCacheExpired: $e');
        return true;
      }

      String cacheKey = 'hafalan_data_${widget.nisn}';
      try {
        String? cachedTimestamp = prefs.getString('${cacheKey}_timestamp');
        if (cachedTimestamp == null) return true;

        DateTime cacheTime = DateTime.parse(cachedTimestamp);
        DateTime now = DateTime.now();
        Duration difference = now.difference(cacheTime);
        return difference.inMinutes > CACHE_DURATION_MINUTES;
      } catch (e) {
        print('❌ Error checking cache expiration: $e');
      }
      return true;
    } catch (e) {
      print('❌ General error in isCacheExpired: $e');
      return true;
    }
  }

  Future<void> _saveToCache(List<HafalanData> data, String namaSantri) async {
    try {
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance().timeout(
          Duration(seconds: 10),
        );
      } catch (e) {
        print('❌ SharedPreferences getInstance failed in saveToCache: $e');
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
      }
    } catch (e) {
      print('❌ Error saving to cache: $e');
    }
  }

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cache dibersihkan. Memuat ulang data...'),
            backgroundColor: Colors.orange[600],
          ),
        );
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

  Future<void> _refreshDataInBackground() async {
    try {
      await _fetchFromServer(showLoading: false);
      print('✅ Background refresh completed');
    } catch (e) {
      print('❌ Background refresh failed: $e');
    }
  }

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

  DateTime? _parseDateTime(HafalanData data) {
    try {
      String dateStr = data.tanggal.trim();
      String timeStr = data.waktu.trim();

      if (dateStr.isEmpty) {
        print('⚠️ Empty date string');
        return null;
      }

      if (dateStr.contains(' ') && timeStr.isEmpty) {
        List<String> parts = dateStr.split(' ');
        dateStr = parts[0];
        if (parts.length > 1) {
          timeStr = parts.sublist(1).join(' ');
        }
      }

      DateTime? parsedDate;

      List<Map<String, dynamic>> dateFormats = [
        {
          'format': 'yyyy-MM-dd',
          'separator': '-',
          'order': ['year', 'month', 'day'],
        },
        {
          'format': 'dd/MM/yyyy',
          'separator': '/',
          'order': ['day', 'month', 'year'],
        },
        {
          'format': 'dd-MM-yyyy',
          'separator': '-',
          'order': ['day', 'month', 'year'],
        },
        {
          'format': 'MM/dd/yyyy',
          'separator': '/',
          'order': ['month', 'day', 'year'],
        },
        {
          'format': 'yyyy/MM/dd',
          'separator': '/',
          'order': ['year', 'month', 'day'],
        },
        {
          'format': 'd/M/yyyy',
          'separator': '/',
          'order': ['day', 'month', 'year'],
        },
        {
          'format': 'd-M-yyyy',
          'separator': '-',
          'order': ['day', 'month', 'year'],
        },
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
            int year = 0, month = 0, day = 0;

            for (int i = 0; i < 3; i++) {
              int value = int.parse(dateParts[i].trim());
              switch (order[i]) {
                case 'year':
                  year = value;
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

      if (timeStr.isNotEmpty && timeStr != dateStr) {
        try {
          String cleanTimeStr = timeStr.trim().toLowerCase();
          bool isPM = cleanTimeStr.contains('pm');
          bool isAM = cleanTimeStr.contains('am');

          cleanTimeStr = cleanTimeStr.replaceAll(RegExp(r'\s*(am|pm)\s*'), '');

          List<String> timeParts = cleanTimeStr.split(':');
          if (timeParts.length >= 2) {
            int hour = int.parse(timeParts[0].trim());
            int minute = int.parse(timeParts[1].trim());
            int second = timeParts.length > 2
                ? int.parse(timeParts[2].trim())
                : 0;

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
        }
      }

      return parsedDate;
    } catch (e) {
      print('💥 Error parsing datetime for ${data.tanggal} ${data.waktu}: $e');
      return null;
    }
  }

  bool _isValidDate(int year, int month, int day) {
    if (year < 1900 || year > 2100) return false;
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;

    List<int> daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

    bool isLeapYear = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
    if (isLeapYear && month == 2) {
      daysInMonth[1] = 29;
    }

    return day <= daysInMonth[month - 1];
  }

  Future<void> _fetchFromServer({bool showLoading = true}) async {
    try {
      if (showLoading && mounted) {
        setState(() {
          _loading = true;
          _error = '';
        });
      }

      SharedPreferences? prefs;
      String? lastUrl;

      try {
        prefs = await SharedPreferences.getInstance().timeout(
          Duration(seconds: 5),
        );
        lastUrl = prefs.getString('last_successful_url');
      } catch (e) {
        print('❌ Cannot access SharedPreferences for last URL: $e');
      }

      List<String> urlsToTry = List.from(_csvUrls);

      if (lastUrl != null && _csvUrls.contains(lastUrl)) {
        urlsToTry.remove(lastUrl);
        urlsToTry.insert(0, lastUrl);
      }

      http.Response? response;
      String? successfulUrl;
      String lastError = '';

      for (String url in urlsToTry) {
        try {
          print('🔄 Trying URL: $url');

          response = await http
              .get(
                Uri.parse(url),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                  'Accept': 'text/csv,text/plain,application/csv,*/*',
                },
              )
              .timeout(Duration(seconds: 10));

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

      if (prefs != null) {
        try {
          await prefs.setString('last_successful_url', successfulUrl);
        } catch (e) {
          print('❌ Cannot save successful URL: $e');
        }
      }

      List<List<dynamic>> csvData;

      try {
        if (successfulUrl.contains('format=tsv')) {
          csvData = CsvToListConverter(
            fieldDelimiter: '\t',
          ).convert(response.body);
        } else {
          csvData = CsvToListConverter().convert(response.body);
        }
      } catch (e) {
        print('❌ CSV parsing error: $e');
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

        filtered.sort((a, b) {
          DateTime? dateA = _parseDateTime(a);
          DateTime? dateB = _parseDateTime(b);

          if (dateA == null && dateB == null) {
            String fullA = '${a.tanggal} ${a.waktu}';
            String fullB = '${b.tanggal} ${b.waktu}';
            return fullB.compareTo(fullA);
          } else if (dateA == null) {
            return 1;
          } else if (dateB == null) {
            return -1;
          } else {
            return dateB.compareTo(dateA);
          }
        });

        await _saveToCache(filtered, namaSantri);

        if (mounted) {
          setState(() {
            _allData = filtered;
            // Reset pagination
            _currentPage = 0;
            _hasMoreData = _allData.length > _itemsPerPage;
            _displayedData = _allData.take(_itemsPerPage).toList();
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
        return datetime.split(' ')[1].substring(0, 5);
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
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

  // Widget untuk loading indicator saat memuat data lebih banyak
  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: Colors.teal[600], strokeWidth: 2),
            SizedBox(height: 8),
            Text(
              'Memuat data lainnya...',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // Widget untuk end of data indicator
  Widget _buildEndOfDataIndicator() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.done_all, color: Colors.grey[400], size: 24),
            SizedBox(height: 8),
            Text(
              'Semua data telah dimuat',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            Text(
              '(${_displayedData.length} dari ${_allData.length} total)',
              style: TextStyle(color: Colors.grey[400], fontSize: 10),
            ),
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
        title: Text(
          'Riwayat Hafalan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.teal[600],
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
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
                      '${_allData.length} total',
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
                        ],
                      ),
                    ),
                  )
                : _allData.isEmpty
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
                                'Menampilkan ${_displayedData.length} dari ${_allData.length} setoran',
                                style: TextStyle(
                                  fontSize: 14,
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

                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.only(bottom: 16),
                            itemCount:
                                _displayedData.length +
                                1, // +1 for loading indicator
                            itemBuilder: (context, index) {
                              // Show loading indicator at the end
                              if (index == _displayedData.length) {
                                if (_loadingMore) {
                                  return _buildLoadingMoreIndicator();
                                } else if (!_hasMoreData &&
                                    _displayedData.isNotEmpty) {
                                  return _buildEndOfDataIndicator();
                                } else {
                                  return SizedBox.shrink();
                                }
                              }

                              return _buildSimpleCard(
                                _displayedData[index],
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
