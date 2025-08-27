import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentPage extends StatefulWidget {
  final String username;
  final String studentName;

  const PaymentPage({
    super.key,
    required this.username,
    required this.studentName,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPaymentType = 'SPP';
  late AnimationController _animationController;
  late AnimationController _shimmerController;
  late Animation<double> _slideAnimation;
  late Animation<double> _shimmerAnimation;
  bool _isLoading = true;

  final String _whatsappNumber = '+6281237804124';
  final String _bankAccount = '7269288153';
  final String _bankName = 'BSI';
  final String _accountName = 'Yayasan Pesantren Zaid bin Tsabit';

  // Color scheme
  static const Color primaryRed = Color(0xFFE53E3E);
  static const Color lightRed = Color(0xFFFED7D7);
  static const Color darkRed = Color(0xFFE53E3E);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _simulateLoading();
  }

  void _initializeAnimations() {
    _tabController = TabController(length: 2, vsync: this);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // Start shimmer while loading
    _shimmerController.repeat();
  }

  void _simulateLoading() {
    // Simulate loading time
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _shimmerController.stop();
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('$label berhasil disalin'),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendWhatsAppMessage() async {
    final String message =
        "Assalamualaikum, Saya atas nama Wali dari *${widget.studentName}*\n"
        "(${widget.username}) ingin melakukan pembayaran $_selectedPaymentType, "
        "berikut bukti pembayarannya. Jazakumullahu khairan";

    final String encodedMessage = Uri.encodeComponent(message);
    final String whatsappUrl =
        "https://wa.me/$_whatsappNumber?text=$encodedMessage";

    try {
      HapticFeedback.mediumImpact();
      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(
          Uri.parse(whatsappUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          _showErrorSnackBar('WhatsApp tidak dapat dibuka');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: ${e.toString()}');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: primaryRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Pembayaran',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading ? _buildShimmerView() : _buildMainContent(),
      bottomNavigationBar: _isLoading ? null : _buildBottomButton(),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      child: FadeTransition(
        opacity: _slideAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildStudentInfoCard(),
            _buildPaymentTypeSection(),
            _buildBankAccountCard(),
            _buildInstructionsCard(),
            const SizedBox(height: 100), // Space for bottom button
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildShimmerCard(height: 120),
          _buildShimmerCard(height: 140),
          _buildShimmerCard(height: 200),
          _buildShimmerCard(height: 180),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildShimmerCard({required double height}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AnimatedBuilder(
          animation: _shimmerAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.grey[300]!,
                    Colors.grey[100]!,
                    Colors.grey[300]!,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                  transform: GradientRotation(_shimmerAnimation.value * 0.5),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 150,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.6,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStudentInfoCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryRed, darkRed],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryRed.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Informasi Santri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.account_circle_outlined,
              'Nama',
              widget.studentName,
              isWhiteTheme: true,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.assignment_ind_outlined,
              'Username',
              widget.username,
              isWhiteTheme: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isWhiteTheme = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: isWhiteTheme
              ? Colors.white.withOpacity(0.8)
              : Colors.grey[600],
          size: 20,
        ),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: isWhiteTheme
                ? Colors.white.withOpacity(0.8)
                : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: isWhiteTheme ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentTypeSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: lightRed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.category, color: primaryRed, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Jenis Pembayaran',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildPaymentTypeChip('SPP', Icons.school)),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPaymentTypeChip('Ekskul', Icons.sports_soccer),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTypeChip(String type, IconData icon) {
    final bool isSelected = _selectedPaymentType == type;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedPaymentType = type;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryRed : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryRed : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryRed.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              type,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankAccountCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_balance,
                  color: Colors.blue[600],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Informasi Rekening',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!, width: 1),
            ),
            child: Column(
              children: [
                _buildBankInfoRow('Bank', _bankName, false),
                const Divider(height: 20),
                _buildBankInfoRow('No. Rekening', _bankAccount, true),
                const Divider(height: 20),
                _buildBankInfoRow('Atas Nama', _accountName, false),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber[200]!, width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pastikan transfer ke rekening yang benar dan konfirmasi via WhatsApp',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber[800],
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

  Widget _buildBankInfoRow(String label, String value, bool canCopy) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Text(': ', style: TextStyle(color: Colors.grey)),
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (canCopy)
                GestureDetector(
                  onTap: () => _copyToClipboard(value, label),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.copy, size: 16, color: Colors.blue[700]),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.list_alt, color: Colors.green[600], size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Cara Pembayaran',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _InstructionStep(
            1,
            'Transfer ke rekening BSI yang tertera di atas',
            Icons.account_balance_wallet,
          ),
          const _InstructionStep(
            2,
            'Screenshot atau simpan bukti transfer',
            Icons.screenshot,
          ),
          const _InstructionStep(
            3,
            'Klik tombol "Konfirmasi WhatsApp" di bawah',
            Icons.message,
          ),
          const _InstructionStep(
            4,
            'Kirim bukti transfer beserta data Santri',
            Icons.send,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF25D366), Color(0xFF25D366)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF25D366).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _sendWhatsAppMessage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.call, size: 24, color: Colors.white),
                    SizedBox(width: 12),
                    Text(
                      'Konfirmasi via WhatsApp',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pastikan transfer sudah dilakukan sebelum konfirmasi',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final int number;
  final String text;
  final IconData icon;

  const _InstructionStep(this.number, this.text, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFE53E3E),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!, width: 1),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w500,
                        height: 1.4,
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
  }
}
