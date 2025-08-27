import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  final String amount;
  final String nisn;

  const PaymentConfirmationScreen({
    Key? key,
    required this.amount,
    required this.nisn,
  }) : super(key: key);

  @override
  _PaymentConfirmationScreenState createState() =>
      _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _shimmerController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _shimmerAnimation;

  bool _isProcessing = false;
  bool _isLoading = true;
  String _transactionCode = '';

  @override
  void initState() {
    super.initState();

    print('PaymentConfirmationScreen initialized');
    print('Received NISN: ${widget.nisn}');
    print('Received Amount: ${widget.amount}');

    _slideController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );
    _shimmerController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _shimmerAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );

    _generateTransactionCode();
    _startAnimations();
  }

  void _generateTransactionCode() {
    final now = DateTime.now();
    _transactionCode = '${now.millisecondsSinceEpoch.toString().substring(7)}';
    print('Generated transaction code: $_transactionCode');
  }

  void _startAnimations() async {
    // Simulate loading time
    await Future.delayed(Duration(milliseconds: 1200));
    setState(() {
      _isLoading = false;
    });

    _fadeController.forward();
    await Future.delayed(Duration(milliseconds: 100));
    _slideController.forward();
  }

  String _formatCurrency(String amount) {
    try {
      // Remove any non-digit characters
      final cleanAmount = amount.replaceAll(RegExp(r'[^\d]'), '');
      if (cleanAmount.isEmpty) return '0';

      final number = int.tryParse(cleanAmount) ?? 0;
      return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
    } catch (e) {
      print('Error formatting currency: $e');
      return amount;
    }
  }

  String get _nisnCode {
    if (widget.nisn.length >= 3) {
      return widget.nisn.substring(widget.nisn.length - 3);
    }
    return widget.nisn.padLeft(3, '0');
  }

  int get _totalAmount {
    try {
      final baseAmount = int.parse(
        widget.amount.replaceAll(RegExp(r'[^\d]'), ''),
      );
      final codeAmount = int.parse(_nisnCode);
      final total = baseAmount + codeAmount;

      print('Base amount: $baseAmount');
      print('Code from NISN: $codeAmount');
      print('Total amount: $total');

      return total;
    } catch (e) {
      print('Error calculating total amount: $e');
      return 0;
    }
  }

  Widget _buildShimmerEffect({required Widget child, required bool isLoading}) {
    if (!isLoading) return child;

    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.grey[300]!, Colors.grey[100]!, Colors.grey[300]!],
              stops: [
                _shimmerAnimation.value - 0.3,
                _shimmerAnimation.value,
                _shimmerAnimation.value + 0.3,
              ].map((stop) => stop.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  void _copyToClipboard(String text, String label) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.check_rounded, color: Colors.white, size: 18),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$label berhasil disalin',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isProcessing = true;
    });

    try {
      final phone = "6289693652230";
      final message =
          "Halo, saya sudah melakukan transfer untuk top up saldo.\n\n"
          "📋 *Detail Transfer:*\n"
          "• NISN: ${widget.nisn}\n"
          "• Jumlah Top Up: Rp ${_formatCurrency(widget.amount)}\n"
          "• Kode Unik: $_nisnCode\n"
          "• Total Transfer: Rp ${_formatCurrency(_totalAmount.toString())}\n"
          "• Kode Transaksi: $_transactionCode\n\n"
          "💰 *Detail Rekening Tujuan:*\n"
          "• Bank: BSI (Bank Syariah Indonesia)\n"
          "• No. Rekening: 7269288153\n"
          "• Atas Nama: PESANTREN ISLAM ZAID BIN TSABIT\n\n"
          "Silakan verifikasi pembayaran saya. Terima kasih.";

      final encodedMessage = Uri.encodeComponent(message);
      final whatsappUrl = Uri.parse(
        "https://wa.me/$phone?text=$encodedMessage",
      );

      if (!await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication)) {
        throw 'Tidak bisa buka WhatsApp';
      } else {
        // fallback terakhir
        await launchUrl(
          Uri.parse(
            "https://api.whatsapp.com/send?phone=$phone&text=$encodedMessage",
          ),
          mode: LaunchMode.externalApplication,
        );
      }

      await Future.delayed(Duration(seconds: 2));
      _showSuccessDialog();
    } catch (e) {
      print('Error opening WhatsApp: $e');
      _showErrorDialog(
        'Gagal membuka WhatsApp. Silakan hubungi bendahara secara manual.\n\nError: ${e.toString()}',
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'Terjadi Kesalahan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Text(message, style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Tutup'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openWhatsApp(); // Coba lagi
            },
            child: Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, color: Colors.white, size: 40),
              ),
              SizedBox(height: 24),
              Text(
                'Berhasil Dikirim!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Konfirmasi pembayaran telah dikirim via WhatsApp. Silakan tunggu verifikasi dari bendahara.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Kembali ke Beranda',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // Modern App Bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF000000).withOpacity(0.05),
                    offset: Offset(0, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_rounded,
                        size: 18,
                        color: Color(0xFF374151),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Konfirmasi Pembayaran',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  SizedBox(width: 40),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? _buildShimmerContent()
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            children: [
                              // User Card
                              _buildUserCard(),
                              SizedBox(height: 20),

                              // Amount Card
                              _buildAmountCard(),
                              SizedBox(height: 24),

                              // Payment Instructions
                              _buildPaymentInstructionsCard(),
                              SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),

            // Bottom Action
            if (!_isLoading) _buildBottomAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          _buildShimmerEffect(
            isLoading: true,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          SizedBox(height: 20),
          _buildShimmerEffect(
            isLoading: true,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          SizedBox(height: 24),
          _buildShimmerEffect(
            isLoading: true,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF000000).withOpacity(0.04),
            offset: Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.account_circle_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NISN',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  widget.nisn,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Aktif',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF16A34A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F2937), Color(0xFF111827)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF000000).withOpacity(0.3),
            offset: Offset(0, 10),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      constraints: BoxConstraints(minWidth: double.infinity),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon decorative element
          Icon(
            Icons.payment_rounded,
            color: Color(0xFF9CA3AF).withOpacity(0.7),
            size: 28,
          ),
          SizedBox(height: 16),

          // Title
          Text(
            'TOTAL PEMBAYARAN',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 16),

          // Main amount with proper formatting
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Rp ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _formatCurrency(_totalAmount.toString()),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Breakdown information
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Color(0xFF1F2937).withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: _formatCurrency(widget.amount),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: ' + ',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  ),
                  TextSpan(
                    text: _nisnCode,
                    style: TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: ' (kode unik)',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInstructionsCard() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF000000).withOpacity(0.04),
            offset: Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'MENUNGGU PEMBAYARAN',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Transfer ke rekening berikut:',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF374151),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 16),

          // Bank Card
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'BSI',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'BANK SYARIAH INDONESIA',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nomor Rekening',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '7269288153',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          _copyToClipboard('7269288153', 'Nomor rekening'),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(0xFFDEF7EC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.copy_rounded,
                          color: Color(0xFF10B981),
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'PESANTREN ISLAM ZAID BIN TSABIT',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Important Note
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFBAE6FD)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF0284C7), size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Transfer sesuai jumlah total yang tertera untuk memudahkan verifikasi',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF0284C7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0xFF000000).withOpacity(0.05),
            offset: Offset(0, -1),
            blurRadius: 3,
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isProcessing ? null : _openWhatsApp,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF10B981),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            disabledBackgroundColor: Color(0xFF9CA3AF),
          ),
          child: _isProcessing
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Mengirim...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Text(
                  'Saya Sudah Transfer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }
}
