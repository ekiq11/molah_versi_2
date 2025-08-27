// Import CombinedHeader - pastikan sudah sesuai dengan kode yang diperbaiki sebelumnya
import 'package:flutter/material.dart';

class CombinedHeader extends StatelessWidget {
  final Map<String, dynamic> santriData;
  final int notificationCount;
  final VoidCallback? onNotificationTap;
  final VoidCallback onLogoutTap;
  final String saldo;
  final VoidCallback onTopUpTap;
  final bool isSaldoVisible;
  final VoidCallback onToggleSaldoVisibility;

  const CombinedHeader({
    super.key,
    required this.santriData,
    required this.notificationCount,
    this.onNotificationTap,
    required this.onLogoutTap,
    required this.saldo,
    required this.onTopUpTap,
    required this.isSaldoVisible,
    required this.onToggleSaldoVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 360;

    return Column(
      children: [
        // Header Section - Clean Design
        Container(
          padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 20 : 24,
            horizontal: isSmallScreen ? 20 : 24,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFE53E3E),
                Color(0xFFE53E3E).withOpacity(0.9),
                Color(0xFFE53E3E).withOpacity(0.8),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 24),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFE53E3E).withOpacity(0.3),
                blurRadius: 15,
                offset: Offset(0, 6),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              // Profile Row - Clean & Simple
              Row(
                children: [
                  // Avatar dengan design yang lebih menarik
                  Container(
                    width: isSmallScreen ? 50 : 56,
                    height: isSmallScreen ? 50 : 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.3),
                          Colors.white.withOpacity(0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: isSmallScreen ? 24 : 28,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 16 : 20),

                  // User Info - Clean Typography
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selamat Datang',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13 : 14,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          santriData['nisn'] ?? 'Memuat data...',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 18 : 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.1,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          santriData['nama'] ?? 'Memuat data...',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13 : 14,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: isSmallScreen ? 24 : 28),

              // Balance Section - Ultra Clean Design
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 18 : 22),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saldo Santri',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 13,
                              color: Colors.white.withOpacity(0.85),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  isSaldoVisible ? saldo : 'Rp ••••••••',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isSmallScreen ? 18 : 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    height: 1.1,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              SizedBox(width: 8),
                              GestureDetector(
                                onTap: onToggleSaldoVisibility,
                                child: Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isSaldoVisible
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.white.withOpacity(0.9),
                                    size: isSmallScreen ? 16 : 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: 16),

                    // Top Up Icon - Small & Clean
                    GestureDetector(
                      onTap: onTopUpTap,
                      child: Container(
                        padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: isSmallScreen ? 20 : 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
