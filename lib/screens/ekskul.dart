import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:mmkv/mmkv.dart';
import 'dart:convert';
import 'dart:io';

class EkskulPaymentScreen extends StatefulWidget {
  final String nisn;

  const EkskulPaymentScreen({super.key, required this.nisn})
    : assert(nisn.length > 0, 'NISN tidak boleh kosong');

  // Method untuk validasi NISN
  static bool isValidNISN(String nisn) {
    return nisn.isNotEmpty &&
        nisn.length >= 8 &&
        nisn.length <= 12 &&
        RegExp(r'^\d+$').hasMatch(nisn);
  }

  @override
  State<EkskulPaymentScreen> createState() => _EkskulPaymentScreenState();
}

class _EkskulPaymentScreenState extends State<EkskulPaymentScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _animationController;
  late AnimationController _shimmerController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _shimmerAnimation;

  // Data states
  Map<String, dynamic> _paymentData = {};
  bool _isLoading = true;
  String _errorMessage = '';

  // CSV URLs
  static const List<String> _csvUrls = [
    'https://docs.google.com/spreadsheets/d/1nKsOxOHqi4fmJ9aR4ZpSUiePKVtZG03L2Qjc_iv5QmU/export?format=csv&gid=1521495544',
    'https://docs.google.com/spreadsheets/d/1nKsOxOHqi4fmJ9aR4ZpSUiePKVtZG03L2Qjc_iv5QmU/export?format=csv',
  ];

  MMKV? _mmkv;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _initializeMMKV();
    _fetchPaymentData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _shimmerController.repeat();
  }

  Future<void> _initializeMMKV() async {
    try {
      MMKV.initialize();
      _mmkv = MMKV.defaultMMKV();
    } catch (e) {
      _debugLog('Error initializing MMKV: $e');
    }
  }

  // Method untuk log debugging
  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[EkskulPayment] $message');
    }
  }

  Future<void> _fetchPaymentData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Check internet connectivity
      await InternetAddress.lookup('google.com').timeout(Duration(seconds: 5));

      for (int urlIndex = 0; urlIndex < _csvUrls.length; urlIndex++) {
        final csvUrl = _csvUrls[urlIndex];
        _debugLog('Trying CSV URL ${urlIndex + 1}: $csvUrl');

        try {
          final response = await http
              .get(
                Uri.parse(csvUrl),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                  'Accept': 'text/csv,application/csv,text/plain,*/*',
                  'Cache-Control': 'no-cache',
                },
              )
              .timeout(const Duration(seconds: 15));

          if (response.statusCode == 200 && response.body.isNotEmpty) {
            final csvData = const CsvToListConverter().convert(response.body);

            if (csvData.isNotEmpty) {
              final paymentData = _parsePaymentCSV(csvData);

              if (paymentData.isNotEmpty) {
                await _processPaymentData(paymentData);
                return;
              }
            }
          }
        } catch (e) {
          _debugLog('Error with URL ${urlIndex + 1}: $e');
        }
      }

      throw Exception('Data NISN ${widget.nisn} tidak ditemukan');
    } catch (e) {
      _handleError('Gagal memuat data pembayaran ekskul: $e');
    }
  }

  // Method untuk validasi data CSV
  bool _validateCSVRow(List<dynamic> row) {
    // Check minimum columns
    if (row.length < 11) {
      return false;
    }

    final nisn = row[1]?.toString().trim() ?? '';
    final nama = row[2]?.toString().trim() ?? '';

    // Skip empty NISN
    if (nisn.isEmpty) return false;

    // Skip summary rows
    if (nisn.toUpperCase().contains('TOTAL') ||
        nisn.toUpperCase().contains('PENGELUARAN') ||
        nama.toUpperCase().contains('TOTAL') ||
        nama.toUpperCase().contains('PENGELUARAN')) {
      return false;
    }

    // Skip empty names
    if (nama.isEmpty) return false;

    return true;
  }

  Map<String, dynamic> _parsePaymentCSV(List<List<dynamic>> csvData) {
    try {
      if (csvData.length < 5) {
        _debugLog('CSV data tidak memiliki cukup baris: ${csvData.length}');
        return {};
      }

      _debugLog('Mencari data untuk NISN: ${widget.nisn}');
      _debugLog('Total baris CSV: ${csvData.length}');

      // Print sample data untuk debugging
      if (csvData.length > 2) {
        _debugLog('Header: ${csvData[0]}');
        _debugLog('Sample data row: ${csvData[2]}');
      }

      // Start from row 3 (index 2) based on your CSV structure
      // Baris 0: Header kolom
      // Baris 1: Kosong/header tambahan
      // Baris 2: Data mulai dari sini
      for (int i = 2; i < csvData.length; i++) {
        final row = csvData[i];

        // Skip rows that are too short
        if (row.length < 11) {
          _debugLog(
            'Row ${i + 1} terlalu pendek: ${row.length} kolom, data: $row',
          );
          continue;
        }

        // Column mapping based on your CSV:
        // A(0)=NO, B(1)=NISN, C(2)=NAMA, D(3)=STATUS, E(4)=EKSKUL, etc.
        final nisn = row[1]?.toString().trim() ?? '';
        final nama = row[2]?.toString().trim() ?? '';

        // Debug setiap baris yang diproses
        _debugLog('Row ${i + 1}: NISN="$nisn", NAMA="$nama"');

        // Skip rows with empty NISN or invalid data
        if (nisn.isEmpty) {
          _debugLog('Baris ${i + 1}: NISN kosong, skip');
          continue;
        }

        // Skip summary/total rows
        if (nisn.toUpperCase().contains('TOTAL') ||
            nisn.toUpperCase().contains('PENGELUARAN') ||
            nama.toUpperCase().contains('TOTAL') ||
            nama.toUpperCase().contains('PENGELUARAN')) {
          _debugLog(
            'Baris ${i + 1}: Skip summary row - NISN: $nisn, NAMA: $nama',
          );
          continue;
        }

        // Skip rows with empty nama
        if (nama.isEmpty) {
          _debugLog('Baris ${i + 1}: Nama kosong untuk NISN: $nisn, skip');
          continue;
        }

        _debugLog(
          'Baris ${i + 1}: Checking NISN: "$nisn" vs Target: "${widget.nisn}"',
        );

        // Check if NISN matches
        if (_isMatchingNISN(widget.nisn, nisn)) {
          _debugLog('Data ditemukan untuk NISN: $nisn di baris ${i + 1}');

          // Parse numeric values with better error handling
          final iuranPerBulan = _parseNumberFromCell(row[5]);
          final iuranTahunan = _parseNumberFromCell(row[6]);
          final nominalDibayar = _parseNumberFromCell(row[7]);
          final sisaPembayaran = _parseNumberFromCell(row[8]);
          final lunasMonths = _parseNumberFromCell(row[9]);
          final sisaTunggakan = _parseNumberFromCell(row[10]);

          final paymentData = {
            'nisn': nisn,
            'nama': nama,
            'status': row[3]?.toString().trim() ?? '',
            'ekskul': row[4]?.toString().trim() ?? '',
            'iuran_per_bulan': iuranPerBulan,
            'iuran_tahunan': iuranTahunan,
            'nominal_dibayar': nominalDibayar,
            'sisa_pembayaran': sisaPembayaran,
            'lunas_bulan_ke': lunasMonths,
            'sisa_tunggakan': sisaTunggakan,
          };

          _debugLog('Data pembayaran berhasil diparse: ${paymentData['nama']}');
          _debugLog('Detail lengkap: $paymentData');
          return paymentData;
        }
      }

      _debugLog(
        'NISN ${widget.nisn} tidak ditemukan dalam ${csvData.length - 2} baris data',
      );

      // Debug: Print semua NISN yang ditemukan untuk membantu troubleshooting
      _debugLog('NISN yang tersedia dalam CSV:');
      for (int i = 2; i < min(csvData.length, 12); i++) {
        final row = csvData[i];
        if (row.length > 1) {
          final foundNisn = row[1]?.toString().trim() ?? '';
          if (foundNisn.isNotEmpty) {
            _debugLog('  - Baris ${i + 1}: "$foundNisn"');
          }
        }
      }

      return {};
    } catch (e, stackTrace) {
      _debugLog('Error parsing payment CSV: $e');
      _debugLog('Stack trace: $stackTrace');
      return {};
    }
  }

  // Improved number parsing method
  int _parseNumberFromCell(dynamic cellValue) {
    if (cellValue == null) {
      _debugLog('parseNumber: null value -> 0');
      return 0;
    }

    String valueStr = cellValue.toString().trim();
    if (valueStr.isEmpty) {
      _debugLog('parseNumber: empty string -> 0');
      return 0;
    }

    // Store original for debugging
    final originalValue = valueStr;

    // Remove common formatting characters
    valueStr = valueStr
        .replaceAll(',', '') // Remove comma thousands separator
        .replaceAll(' ', '') // Remove spaces
        .replaceAll('Rp', '') // Remove currency symbol
        .replaceAll('rp', '') // Remove currency symbol (lowercase)
        .trim();

    // Handle dots - bisa jadi thousands separator atau decimal
    // Untuk currency Indonesia, dot biasanya thousands separator
    // Contoh: "1.000.000" = 1000000, "1.000,50" = 100050
    if (valueStr.contains('.')) {
      // Jika ada koma juga, dot adalah thousands separator
      if (valueStr.contains(',')) {
        valueStr = valueStr.replaceAll('.', '');
        // Handle decimal comma (convert to int, ignore decimal)
        if (valueStr.contains(',')) {
          valueStr = valueStr.split(',')[0];
        }
      } else {
        // Jika hanya ada dot, bisa jadi thousands atau decimal
        // Cek pola: jika ada 3 digit terakhir setelah dot terakhir, kemungkinan thousands
        final parts = valueStr.split('.');
        if (parts.length > 1 && parts.last.length == 3 && parts.length > 2) {
          // Pattern like "1.000.000" - thousands separator
          valueStr = valueStr.replaceAll('.', '');
        } else if (parts.length == 2 && parts.last.length <= 2) {
          // Pattern like "1000.50" - decimal point, take only integer part
          valueStr = parts.first;
        } else {
          // Default: treat as thousands separator
          valueStr = valueStr.replaceAll('.', '');
        }
      }
    }

    // Extract only digits
    final digitsOnly = valueStr.replaceAll(RegExp(r'[^\d]'), '');

    final result = int.tryParse(digitsOnly) ?? 0;
    _debugLog(
      'parseNumber: "$originalValue" -> "$valueStr" -> "$digitsOnly" -> $result',
    );

    return result;
  }

  // Improved NISN matching with more detailed logging
  bool _isMatchingNISN(String targetNISN, String csvNisn) {
    if (targetNISN.isEmpty || csvNisn.isEmpty) {
      _debugLog(
        'NISN matching failed - empty values: target="$targetNISN", csv="$csvNisn"',
      );
      return false;
    }

    final cleanTarget = targetNISN.trim();
    final cleanCsv = csvNisn.trim();

    _debugLog('Comparing NISN: target="$cleanTarget" vs csv="$cleanCsv"');

    // Try exact match first
    if (cleanTarget == cleanCsv) {
      _debugLog('Exact match found!');
      return true;
    }

    // Try case insensitive match
    if (cleanTarget.toLowerCase() == cleanCsv.toLowerCase()) {
      _debugLog('Case insensitive match found!');
      return true;
    }

    // Try numeric comparison (remove leading zeros)
    final targetNumeric = cleanTarget.replaceAll(RegExp(r'^0+'), '');
    final csvNumeric = cleanCsv.replaceAll(RegExp(r'^0+'), '');

    if (targetNumeric.isNotEmpty &&
        csvNumeric.isNotEmpty &&
        targetNumeric == csvNumeric) {
      _debugLog('Numeric match found (ignoring leading zeros)!');
      return true;
    }

    _debugLog('No match found');
    return false;
  }

  Future<void> _processPaymentData(Map<String, dynamic> data) async {
    _shimmerController.stop();

    setState(() {
      _paymentData = data;
      _isLoading = false;
    });

    _animationController.forward();
    await _savePaymentData(data);
  }

  Future<void> _savePaymentData(Map<String, dynamic> data) async {
    if (_mmkv == null) return;

    try {
      final key = 'payment_ekskul_${widget.nisn}';
      _mmkv!.encodeString(key, json.encode(data));
      _debugLog('Data disimpan dengan key: $key');
    } catch (e) {
      _debugLog('Error saving payment data: $e');
    }
  }

  void _handleError(String message) {
    _shimmerController.stop();

    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  // Method untuk mendapatkan status pembayaran
  Map<String, dynamic> _getPaymentStatus() {
    final iuranTahunan = _paymentData['iuran_tahunan'] ?? 0;
    final nominalDibayar = _paymentData['nominal_dibayar'] ?? 0;
    final sisaPembayaran = _paymentData['sisa_pembayaran'] ?? 0;
    final lunasMonths = _paymentData['lunas_bulan_ke'] ?? 0;

    String status = 'Belum Lunas';
    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.pending;

    if (sisaPembayaran <= 0 || lunasMonths >= 12) {
      status = 'Lunas';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (nominalDibayar > 0) {
      status = 'Sebagian';
      statusColor = Colors.blue;
      statusIcon = Icons.payment_rounded;
    }

    return {
      'status': status,
      'color': statusColor,
      'icon': statusIcon,
      'progress': iuranTahunan > 0 ? (nominalDibayar / iuranTahunan) : 0.0,
    };
  }

  String _getMonthName(int monthIndex) {
    const months = [
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
    ];
    return monthIndex < months.length
        ? months[monthIndex]
        : 'Bulan ${monthIndex + 1}';
  }

  List<String> _getPaidMonths() {
    final lunasMonths = _paymentData['lunas_bulan_ke'] ?? 0;
    List<String> months = [];

    for (int i = 0; i < lunasMonths; i++) {
      months.add(_getMonthName(i));
    }

    return months;
  }

  // Method untuk ekspor data ke format yang bisa dibagikan
  String _exportPaymentSummary() {
    if (_paymentData.isEmpty) return '';

    final status = _getPaymentStatus();
    final paidMonths = _getPaidMonths();

    return '''
RIWAYAT PEMBAYARAN EKSTRAKURIKULER

Nama: ${_paymentData['nama']}
NISN: ${_paymentData['nisn']}
Status: ${_paymentData['status']}
Ekstrakurikuler: ${_paymentData['ekskul']}

RINGKASAN PEMBAYARAN:
- Iuran per bulan: ${_formatCurrency(_paymentData['iuran_per_bulan'] ?? 0)}
- Total iuran tahunan: ${_formatCurrency(_paymentData['iuran_tahunan'] ?? 0)}
- Sudah dibayar: ${_formatCurrency(_paymentData['nominal_dibayar'] ?? 0)}
- Sisa pembayaran: ${_formatCurrency(_paymentData['sisa_pembayaran'] ?? 0)}
- Status: ${status['status']}
- Progress: ${(status['progress'] * 100).toStringAsFixed(1)}%

BULAN YANG SUDAH LUNAS:
${paidMonths.isEmpty ? 'Belum ada pembayaran' : paidMonths.map((month) => '✓ $month').join('\n')}

Generated: ${DateTime.now().toString().split('.')[0]}
    ''';
  }

  // Method untuk handle sharing
  void _sharePaymentSummary() {
    final summary = _exportPaymentSummary();
    if (summary.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: summary));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ringkasan pembayaran disalin ke clipboard'),
          backgroundColor: Colors.green[600],
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Riwayat Pembayaran Ekskul'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isLoading && _paymentData.isNotEmpty) ...[
            IconButton(
              icon: Icon(Icons.share),
              onPressed: _sharePaymentSummary,
              tooltip: 'Bagikan ringkasan',
            ),
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _fetchPaymentData,
              tooltip: 'Refresh data',
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        color: Colors.red[400],
        onRefresh: _fetchPaymentData,
        child: _isLoading ? _buildLoadingState() : _buildContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStudentInfoShimmer(),
            SizedBox(height: 16),
            _buildPaymentSummaryShimmer(),
            SizedBox(height: 16),
            _buildChartShimmer(),
            SizedBox(height: 16),
            _buildPaymentHistoryShimmer(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_errorMessage.isNotEmpty && _paymentData.isEmpty) {
      return _buildErrorState();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage.isNotEmpty) ...[
                  _buildErrorBanner(),
                  SizedBox(height: 16),
                ],
                _buildStudentInfo(),
                SizedBox(height: 16),
                _buildPaymentSummary(),
                SizedBox(height: 16),
                _buildPaymentChart(),
                SizedBox(height: 16),
                _buildPaymentHistory(),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Data tidak ditemukan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'NISN ${widget.nisn} tidak ditemukan dalam sistem',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              _errorMessage,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _fetchPaymentData,
                  icon: Icon(Icons.refresh),
                  label: Text('Coba Lagi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back),
                  label: Text('Kembali'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
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
          Icon(Icons.warning, color: Colors.amber[700], size: 22),
          SizedBox(width: 12),
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

  Widget _buildStudentInfo() {
    final status = _getPaymentStatus();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.red[400]!, Colors.red[600]!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.school, color: Colors.white, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _paymentData['nama'] ?? 'Nama tidak ditemukan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'NISN: ${_paymentData['nisn'] ?? widget.nisn}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                if (_paymentData['status'] != null &&
                    _paymentData['status'].toString().isNotEmpty) ...[
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _paymentData['status'],
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: status['color'].withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(status['icon'], color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              status['status'],
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildPaymentSummary() {
    final ekskulText = _paymentData['ekskul']?.toString() ?? '';
    final ekskulCount = ekskulText.toLowerCase().contains('ekskul2')
        ? 2
        : ekskulText.toLowerCase().contains('ekskul1')
        ? 1
        : 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sports, color: Colors.red[600], size: 24),
              SizedBox(width: 8),
              Text(
                'Ringkasan Pembayaran',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Tampilkan nama ekstrakurikuler jika ada
          if (ekskulText.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.sports_kabaddi, color: Colors.blue[600], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ekskulText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Ekstrakurikuler',
                  '$ekskulCount Kegiatan',
                  Icons.celebration,
                  Colors.blue,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildSummaryItem(
                  'Bulan Lunas',
                  '${_paymentData['lunas_bulan_ke'] ?? 0}/12',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Total Dibayar',
                  _formatCurrency(_paymentData['nominal_dibayar'] ?? 0),
                  Icons.account_balance_wallet,
                  Colors.purple,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildSummaryItem(
                  'Sisa Pembayaran',
                  _formatCurrency(_paymentData['sisa_pembayaran'] ?? 0),
                  Icons.pending_actions,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentChart() {
    final iuranTahunan = _paymentData['iuran_tahunan'] ?? 0;
    final nominalDibayar = _paymentData['nominal_dibayar'] ?? 0;
    final sisaPembayaran = _paymentData['sisa_pembayaran'] ?? 0;

    // Calculate progress percentage
    final progressPercentage = iuranTahunan > 0
        ? (nominalDibayar / iuranTahunan)
        : 0.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: Colors.red[600], size: 24),
              SizedBox(width: 8),
              Text(
                'Progress Pembayaran',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Progress Bar Section
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue[50]!, Colors.blue[100]!],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue[200]!, width: 1),
            ),
            child: Column(
              children: [
                // Progress percentage text
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Progress',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      '${(progressPercentage * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Progress Bar
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 1000),
                        curve: Curves.easeOut,
                        height: 12,
                        width:
                            MediaQuery.of(context).size.width *
                            0.7 *
                            progressPercentage,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: progressPercentage >= 1.0
                                ? [Colors.green[400]!, Colors.green[600]!]
                                : progressPercentage >= 0.5
                                ? [Colors.blue[400]!, Colors.blue[600]!]
                                : [Colors.orange[400]!, Colors.red[500]!],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // Amount details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sudah Dibayar',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          _formatCurrency(nominalDibayar),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total Iuran',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          _formatCurrency(iuranTahunan),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Status indicators
          Row(
            children: [
              Expanded(
                child: _buildProgressIndicator(
                  'Terbayar',
                  _formatCurrency(nominalDibayar),
                  progressPercentage >= 1.0
                      ? Colors.green[400]!
                      : Colors.blue[400]!,
                  Icons.check_circle_outline,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildProgressIndicator(
                  'Sisa Bayar',
                  _formatCurrency(sisaPembayaran),
                  sisaPembayaran > 0 ? Colors.orange[400]! : Colors.green[400]!,
                  sisaPembayaran > 0
                      ? Icons.pending_actions
                      : Icons.check_circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(
    String title,
    String amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistory() {
    final paidMonths = _getPaidMonths();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: Colors.red[600], size: 24),
              SizedBox(width: 8),
              Text(
                'Riwayat Pembayaran',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          if (paidMonths.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                  SizedBox(height: 12),
                  Text(
                    'Belum ada pembayaran',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Data pembayaran akan muncul setelah melakukan pembayaran',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else ...[
            // Monthly payment details
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.payments, color: Colors.green[600], size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Iuran per bulan: ${_formatCurrency(_paymentData['iuran_per_bulan'] ?? 0)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),

            // List of paid months
            Column(
              children: paidMonths.asMap().entries.map((entry) {
                final index = entry.key;
                final month = entry.value;
                final isLast = index == paidMonths.length - 1;

                return Container(
                  margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.green[400],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    month,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  Text(
                                    'Pembayaran bulan ke-${index + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  if (_paymentData['iuran_per_bulan'] != null &&
                                      _paymentData['iuran_per_bulan'] > 0) ...[
                                    SizedBox(height: 2),
                                    Text(
                                      _formatCurrency(
                                        _paymentData['iuran_per_bulan'],
                                      ),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[400],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'LUNAS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _formatCurrency(int amount) {
    if (amount == 0) return 'Rp 0';

    final formatted = amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );

    return 'Rp $formatted';
  }

  // Shimmer components
  Widget _buildStudentInfoShimmer() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildShimmerContainer(width: 48, height: 48, borderRadius: 12),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShimmerContainer(width: 150, height: 16, borderRadius: 8),
                SizedBox(height: 8),
                _buildShimmerContainer(width: 120, height: 12, borderRadius: 6),
                SizedBox(height: 8),
                _buildShimmerContainer(width: 80, height: 12, borderRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryShimmer() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShimmerContainer(width: 180, height: 20, borderRadius: 10),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildShimmerContainer(
                  width: double.infinity,
                  height: 80,
                  borderRadius: 12,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildShimmerContainer(
                  width: double.infinity,
                  height: 80,
                  borderRadius: 12,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildShimmerContainer(
                  width: double.infinity,
                  height: 80,
                  borderRadius: 12,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildShimmerContainer(
                  width: double.infinity,
                  height: 80,
                  borderRadius: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartShimmer() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShimmerContainer(width: 150, height: 20, borderRadius: 10),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildShimmerContainer(
                      width: 100,
                      height: 16,
                      borderRadius: 8,
                    ),
                    _buildShimmerContainer(
                      width: 60,
                      height: 16,
                      borderRadius: 8,
                    ),
                  ],
                ),
                SizedBox(height: 12),
                _buildShimmerContainer(
                  width: double.infinity,
                  height: 12,
                  borderRadius: 6,
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildShimmerContainer(
                      width: 80,
                      height: 14,
                      borderRadius: 7,
                    ),
                    _buildShimmerContainer(
                      width: 80,
                      height: 14,
                      borderRadius: 7,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildShimmerContainer(
                  width: double.infinity,
                  height: 80,
                  borderRadius: 12,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildShimmerContainer(
                  width: double.infinity,
                  height: 80,
                  borderRadius: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryShimmer() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShimmerContainer(width: 160, height: 20, borderRadius: 10),
          SizedBox(height: 20),
          ...List.generate(
            3,
            (index) => Container(
              margin: EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  _buildShimmerContainer(
                    width: 40,
                    height: 40,
                    borderRadius: 20,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildShimmerContainer(
                      width: double.infinity,
                      height: 60,
                      borderRadius: 12,
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
