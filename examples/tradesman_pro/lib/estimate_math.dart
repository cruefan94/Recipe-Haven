/// Integer-cents calculations keep routine currency math deterministic.
/// Taxes, discounts, provincial requirements and rounding need separate review.
class EstimateMath {
  static int parseCents(String amount) {
    if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(amount.trim())) {
      throw const FormatException('Enter a valid amount with up to 2 decimals');
    }
    final parts = amount.trim().split('.');
    return int.parse(parts[0]) * 100 +
        (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  }

  static int totalCents({
    required int materialCents,
    required int labourCents,
    required int overheadPercent,
    required int marginPercent,
  }) {
    if (materialCents < 0 || labourCents < 0 ||
        overheadPercent < 0 || overheadPercent > 100 ||
        marginPercent < 0 || marginPercent > 100) {
      throw const FormatException('Invalid estimate values');
    }
    final base = materialCents + labourCents;
    final overhead = (base * overheadPercent / 100).round();
    final profit = ((base + overhead) * marginPercent / 100).round();
    return base + overhead + profit;
  }

  static String formatCents(int cents) =>
      '${cents ~/ 100}.${(cents.abs() % 100).toString().padLeft(2, '0')}';
}
