import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:molahv2/screens/payment_confirmation.dart';
import 'package:molahv2/utils/currency_formater.dart';

class TopUpDialog {
  static Future<void> show({
    required BuildContext context,
    required String currentBalance,
    required String nisn,
  }) async {
    List<int> quickAmounts = [
      10000,
      20000,
      25000,
      50000,
      100000,
      200000,
      300000,
      500000,
    ];
    int? selectedAmount;
    TextEditingController customAmountController = TextEditingController();
    bool isCustomAmountSelected = false;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Helper function to check if input is valid
            bool isValidInput() {
              if (selectedAmount != null && !isCustomAmountSelected) {
                return true;
              }
              if (isCustomAmountSelected &&
                  customAmountController.text.isNotEmpty) {
                final customAmount =
                    int.tryParse(customAmountController.text) ?? 0;
                return customAmount >= 5000 && customAmount <= 10000000;
              }
              return false;
            }

            return Dialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 24.0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Determine if we're on a small screen
                  bool isSmallScreen = constraints.maxWidth < 360;

                  return Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 0,
                          blurRadius: 30,
                          offset: Offset(0, 15),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header with icon
                          Container(
                            width: isSmallScreen ? 60 : 72,
                            height: isSmallScreen ? 60 : 72,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.green[300]!,
                                  Colors.green[500]!,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.3),
                                  spreadRadius: 0,
                                  blurRadius: 15,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.account_balance_wallet,
                              color: Colors.white,
                              size: isSmallScreen ? 30 : 36,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 16 : 20),
                          Text(
                            'Top Up Saldo',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 20 : 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          Text(
                            'Pilih nominal yang ingin Anda top up',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 14,
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          // Show NISN for confirmation
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Text(
                              'NISN: $nisn',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11 : 12,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 16 : 24),

                          // Current Balance
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.blue[50]!, Colors.blue[100]!],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Saldo Saat Ini',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 11 : 12,
                                    color: Colors.blue[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Rp.$currentBalance',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 16 : 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 16 : 24),

                          // Quick amount buttons
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Pilih Nominal Cepat',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 8 : 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: isSmallScreen ? 2 : 2,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: isSmallScreen ? 2.2 : 2.5,
                                ),
                            itemCount: quickAmounts.length,
                            itemBuilder: (context, index) {
                              int amount = quickAmounts[index];
                              bool isSelected =
                                  selectedAmount == amount &&
                                  !isCustomAmountSelected;
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      selectedAmount = amount;
                                      isCustomAmountSelected = false;
                                      customAmountController.clear();
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.green[50]
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.green[300]!
                                            : Colors.grey[300]!,
                                        width: isSelected ? 2 : 1,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: Colors.green.withOpacity(
                                                  0.2,
                                                ),
                                                spreadRadius: 0,
                                                blurRadius: 8,
                                                offset: Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Rp.${CurrencyFormatter.format(amount.toString())}',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 12 : 14,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? Colors.green[600]
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          SizedBox(height: isSmallScreen ? 16 : 24),

                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      vertical: isSmallScreen ? 12 : 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'Batal',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 14 : 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: isSmallScreen ? 8 : 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: isValidInput()
                                      ? () {
                                          // Get final amount (as clean number string)
                                          String finalAmount;
                                          if (selectedAmount != null &&
                                              !isCustomAmountSelected) {
                                            finalAmount = selectedAmount
                                                .toString();
                                          } else {
                                            // Clean the custom amount (remove any formatting)
                                            finalAmount = customAmountController
                                                .text
                                                .replaceAll(
                                                  RegExp(r'[^\d]'),
                                                  '',
                                                );
                                          }

                                          // Debug print for verification
                                          print('DEBUG - NISN: $nisn');
                                          print('DEBUG - Amount: $finalAmount');
                                          print(
                                            'DEBUG - Selected Amount: $selectedAmount',
                                          );
                                          print(
                                            'DEBUG - Is Custom: $isCustomAmountSelected',
                                          );

                                          // Close dialog first
                                          Navigator.of(context).pop();

                                          // Navigate to payment confirmation screen with the data
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  PaymentConfirmationScreen(
                                                    amount:
                                                        finalAmount, // Pass clean amount
                                                    nisn: nisn, // Pass NISN
                                                  ),
                                            ),
                                          );
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isValidInput()
                                        ? Colors.green[500]
                                        : Colors.grey[300],
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: EdgeInsets.symmetric(
                                      vertical: isSmallScreen ? 12 : 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    shadowColor: isValidInput()
                                        ? Colors.green.withOpacity(0.3)
                                        : null,
                                  ),
                                  child: Text(
                                    'Top Up',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 14 : 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// Formatter for currency input
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Only allow digits
    String newText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // If empty after removing non-digits, return empty
    if (newText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Format the number with thousand separators
    final number = int.parse(newText);
    final formatted = CurrencyFormatter.format(number.toString());

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
