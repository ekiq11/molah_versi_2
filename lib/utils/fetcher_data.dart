import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:molahv2/utils/currency_formater.dart';

class DataFetcher {
  static const String _csvUrl =
      'https://docs.google.com/spreadsheets/d/e/2PACX-1vRDHsC8NwqMTfbdbDNEnv6ciXHLEQFIt2ytzVyvqmpnULAOGbltaXwtgY41EK_SCKtkhmJ9lsQiPObs/pub?gid=1307491664&single=true&output=csv';

  Future<Map<String, dynamic>> fetchSantriData(String username) async {
    try {
      final response = await http.get(Uri.parse(_csvUrl));

      if (response.statusCode == 200) {
        List<List<dynamic>> csvTable = CsvToListConverter().convert(
          response.body,
        );

        // Debug: Print data untuk melihat struktur
        print('CSV Data loaded. Rows: ${csvTable.length}');
        print('Looking for username/NISN: $username');

        // Cari data santri berdasarkan NISN (username) di kolom A
        for (int i = 1; i < csvTable.length; i++) {
          List<dynamic> row = csvTable[i];

          // Ambil NISN dari CSV dan username untuk comparison
          String csvNisn = row.isNotEmpty ? row[0].toString().trim() : '';
          String loginUsername = username.toString().trim();

          // Debug: Print setiap baris untuk melihat data
          print(
            'Row $i - CSV NISN: "$csvNisn", Login Username: "$loginUsername", Nama: ${row.length > 4 ? row[4] : 'empty'}',
          );

          // Coba beberapa cara matching:
          // 1. Exact match
          // 2. Tanpa leading zero di CSV
          // 3. Tanpa leading zero di username
          bool isMatch = false;

          if (csvNisn == loginUsername) {
            isMatch = true;
            print('Match found: Exact match');
          } else if (csvNisn ==
              loginUsername.replaceFirst(RegExp(r'^0+'), '')) {
            isMatch = true;
            print('Match found: CSV without leading zero');
          } else if (csvNisn.padLeft(loginUsername.length, '0') ==
              loginUsername) {
            isMatch = true;
            print('Match found: CSV padded with leading zeros');
          }

          if (isMatch) {
            Map<String, dynamic> santriData = {
              'nisn': loginUsername,
              'nama': row.length > 4
                  ? row[4].toString()
                  : 'Nama tidak ditemukan',
              'saldo': CurrencyFormatter.format(
                row.length > 12 ? row[12].toString() : '0',
              ),
              'status_izin':
                  row.length >
                      14 // Perbaiki key menjadi 'status_izin'
                  ? row[14].toString()
                  : 'Sedang Dipondok',
              'jumlah_hafalan': row.length > 16
                  ? row[16].toString()
                  : '0 JUZ', // Perbaiki key menjadi 'jumlah_hafalan'
              'absensi': row.length > 17
                  ? row[17].toString()
                  : 'KBM Belum dimulai',
              'kelas': row.length > 5 ? row[5].toString() : '7A',
              'asrama': row.length > 6
                  ? row[6].toString()
                  : 'ALI BIN ABI THALIB',
              'lembaga':
                  row.length >
                      7 // Kolom H (index 7)
                  ? row[7].toString()
                  : '-',
              'izin_terakhir':
                  row.length >
                      15 // Kolom P (index 15)
                  ? row[15].toString()
                  : 'Belum Ada',
              'poin_pelanggaran':
                  row.length >
                      18 // Tambahkan poin pelanggaran jika belum ada
                  ? row[18].toString()
                  : '0',
              'reward':
                  row.length >
                      19 // Tambahkan reward jika belum ada
                  ? row[19].toString()
                  : '0',
            };

            print(
              'Data santri ditemukan: ${santriData['nama']} (NISN: ${santriData['nisn']})',
            );
            print('Lembaga: ${santriData['lembaga']}');
            print('Izin Terakhir: ${santriData['izin_terakhir']}');
            return santriData;
          }
        }

        print('Data santri dengan NISN $username tidak ditemukan');
        throw Exception('Data santri tidak ditemukan');
      } else {
        print('HTTP Error: ${response.statusCode}');
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching data: $e');
      throw Exception('Error fetching data: $e');
    }
  }
}
