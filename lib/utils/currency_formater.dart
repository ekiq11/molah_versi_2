class CurrencyFormatter {
  static String format(String amount) {
    // Hapus karakter non-digit
    String cleanAmount = amount.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanAmount.isEmpty) return '0';

    // Format dengan titik sebagai pemisah ribuan
    int number = int.tryParse(cleanAmount) ?? 0;
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}
