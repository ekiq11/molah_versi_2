import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'dart:convert';

class TopupService {
  // URL untuk membaca data dari Google Sheets
  static const String _readUrl =
      'https://docs.google.com/spreadsheets/d/e/2PACX-1vRDHsC8NwqMTfbdbDNEnv6ciXHLEQFIt2ytzVyvqmpnULAOGbltaXwtgY41EK_SCKtkhmJ9lsQiPObs/pub?gid=919906307&single=true&output=csv';

  // URL untuk menulis data ke Google Sheets (Anda perlu membuat Google Apps Script)
  // Contoh: https://script.google.com/macros/s/YOUR_SCRIPT_ID/exec
  static const String _writeUrl =
      'https://script.google.com/macros/s/AKfycbzTQVLLXuidDtr0-ZFWuxGM55-RC7y2Kk6uoaVuJjLgV2lp9HgkCP7KDojO-spLyLym/exec';

  Future<bool> submitTopup({
    required String nisn,
    required String amount,
  }) async {
    try {
      // Method 1: Menggunakan Google Apps Script (Recommended)
      final response = await http.post(
        Uri.parse(_writeUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nisn': nisn, 'amount': amount}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] == true;
      }

      return false;
    } catch (e) {
      print('Error submitting topup: $e');
      return false;
    }
  }

  // Alternative method: Simulasi untuk development/testing
  Future<bool> submitTopupSimulation({
    required String nisn,
    required String amount,
  }) async {
    try {
      // Simulasi delay network
      await Future.delayed(Duration(seconds: 2));

      // Log data yang akan dikirim
      print('Topup data to be sent:');
      print('NISN: $nisn');
      print('Amount: $amount');
      print('Timestamp: ${DateTime.now()}');

      // Simulasi berhasil (90% success rate)
      final success = DateTime.now().millisecond % 10 != 0;

      if (success) {
        print('Topup simulation: SUCCESS');
      } else {
        print('Topup simulation: FAILED');
      }

      return success;
    } catch (e) {
      print('Error in topup simulation: $e');
      return false;
    }
  }

  // Method untuk verifikasi data sebelum dikirim
  bool _validateTopupData(String nisn, String amount) {
    if (nisn.isEmpty) return false;
    if (amount.isEmpty) return false;

    final numericAmount = int.tryParse(amount.replaceAll(RegExp(r'[^\d]'), ''));
    if (numericAmount == null || numericAmount <= 0) return false;

    return true;
  }

  // Method untuk format data sebelum dikirim
  Map<String, dynamic> _formatTopupData(String nisn, String amount) {
    final cleanAmount = amount.replaceAll(RegExp(r'[^\d]'), '');
    final timestamp = DateTime.now().toIso8601String();

    return {
      'nisn': nisn,
      'amount': cleanAmount,
      'timestamp': timestamp,
      'status': 'pending',
    };
  }
}
