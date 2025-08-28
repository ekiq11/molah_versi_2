// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class RewardPelanggaranPage extends StatefulWidget {
  final String nisn;
  final String? namaSantri;

  const RewardPelanggaranPage({super.key, required this.nisn, this.namaSantri});

  @override
  State<RewardPelanggaranPage> createState() => _RewardPelanggaranPageState();
}

class RewardPelanggaranData {
  final String id;
  final String jenisPemberian;
  final String kodeEtika;
  final String jenisEtika;
  final String jumlahPelanggaran;
  final String jumlahReward;
  final String nisn;
  final String namaSantri;
  final String kelasAsrama;
  final String hariTanggal;
  final String waktu;
  final String tempatKejadian;
  final String rincianKejadian;
  final String ustadzGuru;

  RewardPelanggaranData({
    required this.id,
    required this.jenisPemberian,
    required this.kodeEtika,
    required this.jenisEtika,
    required this.jumlahPelanggaran,
    required this.jumlahReward,
    required this.nisn,
    required this.namaSantri,
    required this.kelasAsrama,
    required this.hariTanggal,
    required this.waktu,
    required this.tempatKejadian,
    required this.rincianKejadian,
    required this.ustadzGuru,
  });

  factory RewardPelanggaranData.fromCsvRow(List<dynamic> row) {
    return RewardPelanggaranData(
      id: row.isNotEmpty ? row[0].toString().trim() : '',
      jenisPemberian: row.length > 1 ? row[1].toString().trim() : '',
      kodeEtika: row.length > 2 ? row[2].toString().trim() : '',
      jenisEtika: row.length > 3 ? row[3].toString().trim() : '',
      jumlahPelanggaran: row.length > 4 ? row[4].toString().trim() : '',
      jumlahReward: row.length > 5 ? row[5].toString().trim() : '',
      nisn: row.length > 6 ? row[6].toString().replaceAll("'", "").trim() : '',
      namaSantri: row.length > 7 ? row[7].toString().trim() : '',
      kelasAsrama: row.length > 8 ? row[8].toString().trim() : '',
      hariTanggal: row.length > 9 ? row[9].toString().trim() : '',
      waktu: row.length > 10 ? row[10].toString().trim() : '',
      tempatKejadian: row.length > 11 ? row[11].toString().trim() : '',
      rincianKejadian: row.length > 12 ? row[12].toString().trim() : '',
      ustadzGuru: row.length > 13 ? row[13].toString().trim() : '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'jenisPemberian': jenisPemberian,
      'kodeEtika': kodeEtika,
      'jenisEtika': jenisEtika,
      'jumlahPelanggaran': jumlahPelanggaran,
      'jumlahReward': jumlahReward,
      'nisn': nisn,
      'namaSantri': namaSantri,
      'kelasAsrama': kelasAsrama,
      'hariTanggal': hariTanggal,
      'waktu': waktu,
      'tempatKejadian': tempatKejadian,
      'rincianKejadian': rincianKejadian,
      'ustadzGuru': ustadzGuru,
    };
  }

  factory RewardPelanggaranData.fromJson(Map<String, dynamic> json) {
    return RewardPelanggaranData(
      id: json['id'] ?? '',
      jenisPemberian: json['jenisPemberian'] ?? '',
      kodeEtika: json['kodeEtika'] ?? '',
      jenisEtika: json['jenisEtika'] ?? '',
      jumlahPelanggaran: json['jumlahPelanggaran'] ?? '',
      jumlahReward: json['jumlahReward'] ?? '',
      nisn: json['nisn'] ?? '',
      namaSantri: json['namaSantri'] ?? '',
      kelasAsrama: json['kelasAsrama'] ?? '',
      hariTanggal: json['hariTanggal'] ?? '',
      waktu: json['waktu'] ?? '',
      tempatKejadian: json['tempatKejadian'] ?? '',
      rincianKejadian: json['rincianKejadian'] ?? '',
      ustadzGuru: json['ustadzGuru'] ?? '',
    );
  }

  bool get isReward => jenisPemberian.toUpperCase().contains('REWARD');
  bool get isPelanggaran =>
      jenisPemberian.toUpperCase().contains('PELANGGARAN');
}

// Enhanced Shimmer Widget
class ShimmerWidget extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerWidget({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<ShimmerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + _animation.value, 0.0),
              end: Alignment(1.0 + _animation.value, 0.0),
              colors: [
                Colors.grey[300]!.withOpacity(0.6),
                Colors.grey[100]!.withOpacity(0.8),
                Colors.grey[300]!.withOpacity(0.6),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Enhanced Shimmer Loading Cards
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header shimmer
          Row(
            children: [
              ShimmerWidget(
                width: 100,
                height: 28,
                borderRadius: BorderRadius.circular(16),
              ),
              Spacer(),
              ShimmerWidget(
                width: 70,
                height: 28,
                borderRadius: BorderRadius.circular(20),
              ),
            ],
          ),
          SizedBox(height: 20),
          // Title shimmer
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: ShimmerWidget(
              width: double.infinity,
              height: 20,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          SizedBox(height: 16),
          // Description shimmer
          ShimmerWidget(
            width: double.infinity,
            height: 16,
            borderRadius: BorderRadius.circular(8),
          ),
          SizedBox(height: 8),
          ShimmerWidget(
            width: MediaQuery.of(context).size.width * 0.7,
            height: 16,
            borderRadius: BorderRadius.circular(8),
          ),
          SizedBox(height: 20),
          // Details container shimmer
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    ShimmerWidget(
                      width: 24,
                      height: 24,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    SizedBox(width: 8),
                    ShimmerWidget(
                      width: 100,
                      height: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    Spacer(),
                    ShimmerWidget(
                      width: 60,
                      height: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    ShimmerWidget(
                      width: 24,
                      height: 24,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    SizedBox(width: 8),
                    ShimmerWidget(
                      width: 120,
                      height: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardPelanggaranPageState extends State<RewardPelanggaranPage>
    with TickerProviderStateMixin {
  List<RewardPelanggaranData> _allData = [];
  List<RewardPelanggaranData> _rewardData = [];
  List<RewardPelanggaranData> _pelanggaranData = [];
  bool _loading = true;
  String _error = '';
  String _currentNamaSantri = '';
  String _currentKelasAsrama = '';
  bool _isFromCache = false;
  String _selectedTab = 'semua';
  late AnimationController _headerAnimationController;
  late Animation<double> _headerSlideAnimation;
  late Animation<double> _headerFadeAnimation;

  // Updated Google Sheets URL
  static const String csvUrl =
      'https://docs.google.com/spreadsheets/d/1BZbBczH2OY8SB2_1tDpKf_B8WvOyk8TJl4esfT-dgzw/export?format=csv&gid=1620978739';
  static const int CACHE_DURATION_MINUTES = 15;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadData();
  }

  void _setupAnimations() {
    _headerAnimationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    _headerSlideAnimation = Tween<double>(begin: -50, end: 0).animate(
      CurvedAnimation(
        parent: _headerAnimationController,
        curve: Curves.easeOutBack,
      ),
    );
    _headerFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _headerAnimationController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _loading = true;
        _error = '';
      });
      bool cacheLoaded = await _loadFromCache();
      if (cacheLoaded) {
        setState(() {
          _loading = false;
          _isFromCache = true;
        });
        _headerAnimationController.forward();
        if (await _isCacheExpired()) {
          _refreshDataInBackground();
        }
      } else {
        await _fetchFromServer();
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Terjadi kesalahan: $e';
      });
    }
  }

  Future<bool> _loadFromCache() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String cacheKey = 'reward_pelanggaran_${widget.nisn}';
      String? cachedData = prefs.getString(cacheKey);
      String? cachedTimestamp = prefs.getString('${cacheKey}_timestamp');
      String? cachedName = prefs.getString('${cacheKey}_name');
      String? cachedKelas = prefs.getString('${cacheKey}_kelas');
      if (cachedTimestamp != null) {
        List<dynamic> jsonList = json.decode(cachedData!);
        List<RewardPelanggaranData> dataList = jsonList
            .map((item) => RewardPelanggaranData.fromJson(item))
            .toList();
        if (dataList.isNotEmpty) {
          _processData(dataList);
          setState(() {
            _currentNamaSantri =
                cachedName ?? widget.namaSantri ?? dataList.first.namaSantri;
            _currentKelasAsrama = cachedKelas ?? dataList.first.kelasAsrama;
          });
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isCacheExpired() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String cacheKey = 'reward_pelanggaran_${widget.nisn}';
      String? cachedTimestamp = prefs.getString('${cacheKey}_timestamp');
      DateTime cacheTime = DateTime.parse(cachedTimestamp!);
      return DateTime.now().difference(cacheTime).inMinutes >
          CACHE_DURATION_MINUTES;
    } catch (e) {
      return true;
    }
  }

  Future<void> _saveToCache(
    List<RewardPelanggaranData> data,
    String namaSantri,
    String kelasAsrama,
  ) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String cacheKey = 'reward_pelanggaran_${widget.nisn}';
      List<Map<String, dynamic>> jsonList = data
          .map((item) => item.toJson())
          .toList();
      await prefs.setString(cacheKey, json.encode(jsonList));
      await prefs.setString(
        '${cacheKey}_timestamp',
        DateTime.now().toIso8601String(),
      );
      await prefs.setString('${cacheKey}_name', namaSantri);
      await prefs.setString('${cacheKey}_kelas', kelasAsrama);
    } catch (e) {
      print('Error saving to cache: $e');
    }
  }

  Future<void> _refreshDataInBackground() async {
    try {
      await _fetchFromServer(showLoading: false);
    } catch (e) {
      print('Background refresh failed: $e');
    }
  }

  Future<void> _refreshData() async {
    await _fetchFromServer(showLoading: true);
  }

  String _normalizeNisn(String nisn) {
    String cleaned = nisn.replaceAll("'", "").trim();
    if (cleaned.length == 9 && RegExp(r'^\d+$').hasMatch(cleaned)) {
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

  DateTime? _parseDateTime(RewardPelanggaranData data) {
    try {
      String dateStr = data.hariTanggal.trim();
      if (dateStr.isEmpty) return null;
      List<RegExp> datePatterns = [
        RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})'),
        RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})'),
        RegExp(r'(\d{1,2})-(\d{1,2})-(\d{4})'),
      ];
      for (RegExp pattern in datePatterns) {
        RegExpMatch? match = pattern.firstMatch(dateStr);
        if (match != null) {
          int day, month, year;
          if (pattern == datePatterns[1]) {
            year = int.parse(match.group(1)!);
            month = int.parse(match.group(2)!);
            day = int.parse(match.group(3)!);
          } else {
            day = int.parse(match.group(1)!);
            month = int.parse(match.group(2)!);
            year = int.parse(match.group(3)!);
          }
          if (_isValidDate(year, month, day)) {
            return DateTime(year, month, day);
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  bool _isValidDate(int year, int month, int day) {
    if (year < 1900 || year > 2100) return false;
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;
    return true;
  }

  Future<void> _fetchFromServer({bool showLoading = true}) async {
    try {
      if (showLoading) {
        setState(() {
          _loading = true;
          _error = '';
        });
      }
      final res = await http.get(Uri.parse(csvUrl));
      if (res.statusCode == 200) {
        final data = CsvToListConverter().convert(res.body);
        if (data.isNotEmpty) {
          final filtered = data
              .skip(1)
              .where(
                (row) =>
                    row.length > 6 &&
                    _isNisnMatch(row[6].toString(), widget.nisn),
              )
              .map((row) => RewardPelanggaranData.fromCsvRow(row))
              .toList();
          if (filtered.isNotEmpty) {
            filtered.sort((a, b) {
              DateTime? dateA = _parseDateTime(a);
              DateTime? dateB = _parseDateTime(b);
              if (dateA == null && dateB == null) {
                return b.hariTanggal.compareTo(a.hariTanggal);
              } else if (dateA == null) {
                return 1;
              } else if (dateB == null) {
                return -1;
              } else {
                return dateB.compareTo(dateA);
              }
            });
            String namaSantri = widget.namaSantri ?? filtered.first.namaSantri;
            String kelasAsrama = filtered.first.kelasAsrama;
            await _saveToCache(filtered, namaSantri, kelasAsrama);
            _processData(filtered);
            setState(() {
              _currentNamaSantri = namaSantri;
              _currentKelasAsrama = kelasAsrama;
              _loading = false;
              _isFromCache = false;
            });
            if (showLoading) {
              _headerAnimationController.forward();
            }
          } else {
            setState(() {
              _loading = false;
            });
          }
        }
      } else {
        setState(() {
          _loading = false;
          _error = 'Gagal memuat data';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Terjadi kesalahan: $e';
      });
    }
  }

  void _processData(List<RewardPelanggaranData> data) {
    _allData = data.take(20).toList();
    _rewardData = _allData.where((item) => item.isReward).toList();
    _pelanggaranData = _allData.where((item) => item.isPelanggaran).toList();
  }

  List<RewardPelanggaranData> get _currentData {
    switch (_selectedTab) {
      case 'reward':
        return _rewardData;
      case 'pelanggaran':
        return _pelanggaranData;
      default:
        return _allData;
    }
  }

  Widget _buildStudentHeader() {
    String displayName = _currentNamaSantri.isNotEmpty
        ? _currentNamaSantri
        : (widget.namaSantri ?? '');
    if (displayName.isEmpty && _currentKelasAsrama.isEmpty) {
      return SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: _headerAnimationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _headerSlideAnimation.value),
          child: Opacity(
            opacity: _headerFadeAnimation.value,
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE53E3E),
                    Color(0xFFE53E3E).withOpacity(0.9),
                    Color(0xFFE53E3E).withOpacity(0.8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color.fromARGB(255, 201, 4, 4).withOpacity(0.3),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Hero(
                      tag: 'student_avatar_${widget.nisn}',
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.3),
                              Colors.white.withOpacity(0.1),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : 'S',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              shadows: [
                                Shadow(
                                  blurRadius: 8.0,
                                  color: Colors.black.withOpacity(0.3),
                                  offset: Offset(1.0, 1.0),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (displayName.isNotEmpty)
                            Text(
                              displayName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                                height: 1.2,
                                shadows: [
                                  Shadow(
                                    blurRadius: 8.0,
                                    color: Colors.black.withOpacity(0.3),
                                    offset: Offset(1.0, 1.0),
                                  ),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.badge_outlined,
                                      size: 12,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      "NISN: ${widget.nisn}",
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.95),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_currentKelasAsrama.isNotEmpty)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.25),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.school_outlined,
                                        size: 12,
                                        color: Colors.white.withOpacity(0.85),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        _currentKelasAsrama,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
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
                    SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isFromCache)
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.offline_bolt_outlined,
                              color: Colors.white.withOpacity(0.8),
                              size: 16,
                            ),
                          ),
                        if (_isFromCache) SizedBox(height: 6),
                        GestureDetector(
                          onTap: _refreshData,
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.refresh_rounded,
                              color: Colors.white.withOpacity(0.85),
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabButton(String value, String label, int count, IconData icon) {
    bool isSelected = _selectedTab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = value),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(vertical: 16),
          margin: EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFE53E3E),
                      Color(0xFFE53E3E).withOpacity(0.9),
                      Color(0xFFE53E3E).withOpacity(0.8),
                    ],
                  )
                : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : Color.fromARGB(255, 248, 82, 32).withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? Color.fromARGB(255, 201, 4, 4).withOpacity(0.25)
                    : Colors.black.withOpacity(0.05),
                blurRadius: isSelected ? 12 : 6,
                offset: Offset(0, isSelected ? 6 : 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.1 : 1.0,
                duration: Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  color: isSelected
                      ? Colors.white
                      : Color.fromARGB(255, 248, 82, 32),
                  size: 24,
                ),
              ),
              SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Color.fromARGB(255, 248, 82, 32),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 6),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.25)
                      : Color.fromARGB(255, 248, 82, 32).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? null
                      : Border.all(
                          color: Color.fromARGB(
                            255,
                            248,
                            82,
                            32,
                          ).withOpacity(0.3),
                          width: 1,
                        ),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : Color.fromARGB(255, 231, 21, 21),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataCard(RewardPelanggaranData data, int index) {
    bool isReward = data.isReward;
    bool isToday = false;
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
    }
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 400 + (index * 80)),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double opacity, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - opacity)),
          child: Opacity(
            opacity: opacity,
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: isToday
                    ? Border.all(
                        color: isReward ? Color(0xFF4CAF50) : Color(0xFFFF5722),
                        width: 2,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: isToday
                        ? (isReward ? Color(0xFF4CAF50) : Color(0xFFFF5722))
                              .withOpacity(0.25)
                        : Colors.black.withOpacity(0.08),
                    blurRadius: isToday ? 20 : 15,
                    offset: Offset(0, isToday ? 10 : 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    if (isToday)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: [
                                (isReward
                                        ? Color(0xFF4CAF50)
                                        : Color(0xFFE53E3E))
                                    .withOpacity(0.06),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isReward
                                        ? [Color(0xFF4CAF50), Color(0xFF66BB6A)]
                                        : [
                                            Color(0xFFE53E3E),
                                            Color(0xFFE53E3E).withOpacity(0.9),
                                            Color(0xFFE53E3E).withOpacity(0.8),
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (isReward
                                                  ? Color(0xFF4CAF50)
                                                  : Color(0xFFE53E3E))
                                              .withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isReward
                                          ? Icons.star_rounded
                                          : Icons.warning_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      isReward ? 'REWARD' : 'PELANGGARAN',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isToday) ...[
                                SizedBox(width: 10),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF2196F3),
                                        Color(0xFF42A5F5),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.today_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'HARI INI',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              Spacer(),
                              if (isReward && data.jumlahReward.isNotEmpty)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF4CAF50),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(
                                          0xFF4CAF50,
                                        ).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.emoji_events_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        data.jumlahReward,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (!isReward &&
                                  data.jumlahPelanggaran.isNotEmpty)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFFF5722),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(
                                          0xFFFF5722,
                                        ).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.remove_circle_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        data.jumlahPelanggaran,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 20),
                          if (data.jenisEtika.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color:
                                    (isReward
                                            ? Color(0xFF4CAF50)
                                            : Color(0xFFFF5722))
                                        .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      (isReward
                                              ? Color(0xFF4CAF50)
                                              : Color(0xFFFF5722))
                                          .withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                data.jenisEtika,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isReward
                                      ? Color(0xFF2E7D32)
                                      : Color(0xFFD84315),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          if (data.rincianKejadian.isNotEmpty) ...[
                            SizedBox(height: 16),
                            Text(
                              data.rincianKejadian,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                                height: 1.6,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                          SizedBox(height: 20),
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.calendar_today_rounded,
                                        size: 18,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        data.hariTanggal,
                                        style: TextStyle(
                                          color: Colors.grey[800],
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (data.waktu.isNotEmpty) ...[
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[100],
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.access_time_rounded,
                                          size: 18,
                                          color: Colors.orange[700],
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        data.waktu,
                                        style: TextStyle(
                                          color: Colors.grey[800],
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (data.tempatKejadian.isNotEmpty) ...[
                                  SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.green[100],
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.location_on_rounded,
                                          size: 18,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          data.tempatKejadian,
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (data.ustadzGuru.isNotEmpty) ...[
                                  SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.purple[100],
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.person_rounded,
                                          size: 18,
                                          color: Colors.purple[700],
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Pelapor: ',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          data.ustadzGuru,
                                          style: TextStyle(
                                            color: Colors.grey[800],
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Color(0xFFF8F9FE),
        elevation: 0,
        // leading: IconButton(
        //   icon: Icon(
        //     Icons.arrow_back_ios_new_rounded,
        //     color: Colors.grey[700],
        //     size: 20,
        //   ),
        //   onPressed: () => Navigator.pop(context),
        // ),
        centerTitle: true,
        title: Text(
          'Reward & Pelanggaran',
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: Color(0xFF667eea),
        child: CustomScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildStudentHeader()),
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    _buildTabButton(
                      'semua',
                      'SEMUA',
                      _allData.length,
                      Icons.list_rounded,
                    ),
                    SizedBox(width: 12),
                    _buildTabButton(
                      'reward',
                      'REWARD',
                      _rewardData.length,
                      Icons.star_rounded,
                    ),
                    SizedBox(width: 12),
                    _buildTabButton(
                      'pelanggaran',
                      'PELANGGARAN',
                      _pelanggaranData.length,
                      Icons.warning_rounded,
                    ),
                  ],
                ),
              ),
            ),
            _loading
                ? SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => ShimmerCard(),
                      childCount: 6,
                    ),
                  )
                : _error.isNotEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Icon(
                              Icons.error_outline_rounded,
                              size: 64,
                              color: Colors.red[400],
                            ),
                          ),
                          SizedBox(height: 24),
                          Text(
                            'Oops! Terjadi Kesalahan',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 12),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              _error,
                              style: TextStyle(
                                color: Colors.red[600],
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(height: 32),
                          ElevatedButton(
                            onPressed: _refreshData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF667eea),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded),
                                SizedBox(width: 12),
                                Text(
                                  "Coba Lagi",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _currentData.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Icon(
                              Icons.inbox_rounded,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                          ),
                          SizedBox(height: 24),
                          Text(
                            "Tidak ada data",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            "Belum ada catatan reward atau pelanggaran",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildDataCard(_currentData[index], index),
                      childCount: _currentData.length,
                    ),
                  ),
            SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}
