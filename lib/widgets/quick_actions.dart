import 'package:flutter/material.dart';
import 'package:molahv2/screens/HafalanHistoryPage.dart';
import 'package:molahv2/screens/ekskul.dart';
import 'package:molahv2/screens/reward.dart';
import 'package:molahv2/screens/spp.dart';

class QuickActions extends StatelessWidget {
  final String nisn;

  const QuickActions({super.key, required this.nisn});

  @override
  Widget build(BuildContext context) {
    // Mendapatkan ukuran layar
    final screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 360;
    final bool isLargeScreen = screenSize.width > 600;
    void navigateToEkskulPayment(
      BuildContext context,
      String nisn,
      String studentName,
    ) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EkskulPaymentScreen(nisn: nisn),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            'Semua Riwayat',
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : (isLargeScreen ? 20 : 18),
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
            ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 12 : 16),
        LayoutBuilder(
          builder: (context, constraints) {
            // Menentukan tinggi card berdasarkan ukuran layar
            final cardHeight = isSmallScreen
                ? 95.0
                : (isLargeScreen ? 130.0 : 110.0);
            final cardWidth = isSmallScreen
                ? 85.0
                : (isLargeScreen ? 120.0 : 100.0);
            final iconSize = isSmallScreen
                ? 18.0
                : (isLargeScreen ? 26.0 : 22.0);
            final iconContainerSize = isSmallScreen
                ? 36.0
                : (isLargeScreen ? 50.0 : 42.0);

            return SizedBox(
              height: cardHeight,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: BouncingScrollPhysics(),
                children: [
                  SizedBox(width: 4), // Spasi awal
                  _buildActionCard(
                    context: context,
                    icon: Icons.history_rounded,
                    title: 'RIWAYAT\nSETORAN',
                    color: Colors.blue[700]!,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    iconSize: iconSize,
                    iconContainerSize: iconContainerSize,
                    isSmallScreen: isSmallScreen,
                    isLargeScreen: isLargeScreen,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HafalanHistoryPage(nisn: nisn),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    context: context,
                    icon: Icons.star_outline_rounded,
                    title: 'RIWAYAT\nPOIN',
                    color: Colors.orange[700]!,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    iconSize: iconSize,
                    iconContainerSize: iconContainerSize,
                    isSmallScreen: isSmallScreen,
                    isLargeScreen: isLargeScreen,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              RewardPelanggaranPage(nisn: nisn),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    context: context,
                    icon: Icons.receipt_long_rounded,
                    title: 'SPP\nSANTRI',
                    color: Colors.green[700]!,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    iconSize: iconSize,
                    iconContainerSize: iconContainerSize,
                    isSmallScreen: isSmallScreen,
                    isLargeScreen: isLargeScreen,
                    onTap: () {
                      // Navigasi ke halaman SPP dengan passing NISN
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SPPPaymentPage(nisn: nisn),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    context: context,
                    icon: Icons.sports_rounded,
                    title: 'EKSKUL\nSANTRI',
                    color: Colors.purple[700]!,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    iconSize: iconSize,
                    iconContainerSize: iconContainerSize,
                    isSmallScreen: isSmallScreen,
                    isLargeScreen: isLargeScreen,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EkskulPaymentScreen(nisn: nisn),
                        ),
                      );
                    },
                  ),
                  SizedBox(width: 4), // Spasi akhir
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required double cardWidth,
    required double cardHeight,
    required double iconSize,
    required double iconContainerSize,
    required bool isSmallScreen,
    required bool isLargeScreen,
    required VoidCallback onTap,
  }) {
    // Menentukan ukuran font berdasarkan ukuran layar
    final fontSize = isSmallScreen ? 10.0 : (isLargeScreen ? 14.0 : 12.0);

    return Container(
      width: cardWidth,
      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 4 : 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: iconContainerSize,
                  height: iconContainerSize,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: iconSize),
                ),
                SizedBox(height: isSmallScreen ? 6 : 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
