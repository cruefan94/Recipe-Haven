/// Money is integer cents. Quantities use hundredths of the selected unit.
class EstimateLine {
  const EstimateLine(this.description, this.units100, this.priceCents, this.unit);
  final String description;
  final int units100, priceCents;
  final String unit;

  int get totalCents => (units100 * priceCents + 50) ~/ 100;
  Map<String, Object> toJson() => {
    'description': description, 'quantity100': units100,
    'priceCents': priceCents, 'unit': unit, 'totalCents': totalCents,
  };
}

class ItemizedEstimate {
  static int parseHundredths(String value, {bool allowZero = false}) {
    final input = value.trim();
    if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(input)) {
      throw const FormatException('Enter a number with at most two decimal places.');
    }
    final parts = input.split('.');
    final result = int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
    if (result == 0 && !allowZero) {
      throw const FormatException('Quantity must be greater than zero.');
    }
    return result;
  }

  static int subtotal(List<EstimateLine> lines) =>
    lines.fold<int>(0, (sum, line) => sum + line.totalCents);

  static int total(List<EstimateLine> lines, int overhead, int markup) {
    if (lines.isEmpty || overhead < 0 || overhead > 100 ||
        markup < 0 || markup > 100) {
      throw const FormatException('Invalid estimate.');
    }
    final base = subtotal(lines);
    final withOverhead = base + (base * overhead + 50) ~/ 100;
    return withOverhead + (withOverhead * markup + 50) ~/ 100;
  }

  static String money(int cents) =>
    (cents ~/ 100).toString() + '.' +
    (cents.abs() % 100).toString().padLeft(2, '0');
}
