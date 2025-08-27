import 'package:flutter/material.dart';

class ReportSection extends StatelessWidget {
  final Map<String, dynamic> santriData;

  const ReportSection({super.key, required this.santriData});

  // Method helper untuk format izin terakhir
  String _formatIzinTerakhir(dynamic izinData) {
    if (izinData == null) {
      return 'Belum Pernah Izin';
    }

    final String izinString = izinData.toString().trim();

    // Cek berbagai kemungkinan nilai kosong
    if (izinString.isEmpty ||
        izinString == '-' ||
        izinString.toLowerCase() == 'null' ||
        izinString.toLowerCase() == 'kosong' ||
        izinString.toLowerCase() == 'tidak ada' ||
        izinString.toLowerCase() == 'belum ada') {
      return 'Belum Pernah Izin';
    }

    return izinString;
  }

  @override
  Widget build(BuildContext context) {
    // Mendapatkan ukuran layar
    final screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 360;
    final bool isLargeScreen = screenSize.width > 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Text(
            'Laporan Santri',
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : (isLargeScreen ? 20 : 18),
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Grid dengan 2 kolom
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: isSmallScreen ? 12 : 14,
            crossAxisSpacing: isSmallScreen ? 12 : 14,
            childAspectRatio: isSmallScreen ? 1.4 : (isLargeScreen ? 1.8 : 1.6),
          ),
          itemCount: 4,
          itemBuilder: (context, index) {
            switch (index) {
              case 0:
                return _buildInfoCard(
                  title: 'ABSENSI',
                  value: santriData['absensi'] ?? 'KBM Belum dimulai',
                  icon: Icons.calendar_today,
                  iconColor: Colors.blue[700]!,
                  cardColor: Colors.blue[50]!,
                  isSmallScreen: isSmallScreen,
                  isLargeScreen: isLargeScreen,
                );
              case 1:
                return _buildInfoCard(
                  title: 'HAFALAN',
                  value: (santriData['jumlah_hafalan'] + 'Juz' ?? '0'),
                  icon: Icons.menu_book,
                  iconColor: Colors.green[700]!,
                  cardColor: Colors.green[50]!,
                  isSmallScreen: isSmallScreen,
                  isLargeScreen: isLargeScreen,
                );
              case 2:
                return _buildInfoCard(
                  title: 'PERIZINAN',
                  value: santriData['status_izin'] ?? 'Sedang Dipondok',
                  icon: Icons.assignment,
                  iconColor: Colors.orange[700]!,
                  cardColor: Colors.orange[50]!,
                  isSmallScreen: isSmallScreen,
                  isLargeScreen: isLargeScreen,
                );
              case 3:
                return _buildInfoCard(
                  title: 'IZIN TERAKHIR',
                  value: _formatIzinTerakhir(santriData['izin_terakhir']),
                  icon: Icons.event,
                  iconColor: Colors.purple[700]!,
                  cardColor: Colors.purple[50]!,
                  isSmallScreen: isSmallScreen,
                  isLargeScreen: isLargeScreen,
                );
              default:
                return Container();
            }
          },
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color cardColor,
    required bool isSmallScreen,
    required bool isLargeScreen,
  }) {
    final double paddingValue = isSmallScreen ? 12 : (isLargeScreen ? 16 : 14);
    final double iconSize = isSmallScreen ? 18 : (isLargeScreen ? 22 : 20);
    final double iconContainerSize = isSmallScreen
        ? 38
        : (isLargeScreen ? 46 : 42);
    final double titleFontSize = isSmallScreen ? 12 : (isLargeScreen ? 13 : 12);
    final double valueFontSize = isSmallScreen ? 12 : (isLargeScreen ? 15 : 14);
    final double borderRadius = isSmallScreen ? 12 : (isLargeScreen ? 16 : 14);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Strip warna kiri
          Container(
            width: 6,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(borderRadius),
                bottomLeft: Radius.circular(borderRadius),
              ),
            ),
          ),
          // Konten utama
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(paddingValue),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: iconContainerSize,
                        height: iconContainerSize,
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: iconColor, size: iconSize),
                      ),
                      SizedBox(width: isSmallScreen ? 10 : 12),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 6 : 8),
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
