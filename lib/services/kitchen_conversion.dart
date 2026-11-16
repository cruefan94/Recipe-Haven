/// Cooking unit conversions with explicit US vs metric volume definitions.
enum CookingDimension { volume, mass, temperature }
class CookingUnit {
  const CookingUnit(this.id, this.label, this.dimension, this.toBase);
  final String id;
  final String label;
  final CookingDimension dimension;
  final double toBase;
}
class KitchenConversion {
  static const units = <CookingUnit>[
    CookingUnit('usCup', 'US cup', CookingDimension.volume, 236.5882365),
    CookingUnit('metricCup', 'Metric cup (250 mL)', CookingDimension.volume, 250),
    CookingUnit('usTbsp', 'US tablespoon', CookingDimension.volume, 236.5882365 / 16),
    CookingUnit('metricTbsp', 'Metric tablespoon (15 mL)', CookingDimension.volume, 15),
    CookingUnit('usTsp', 'US teaspoon', CookingDimension.volume, 236.5882365 / 48),
    CookingUnit('metricTsp', 'Metric teaspoon (5 mL)', CookingDimension.volume, 5),
    CookingUnit('ml', 'Millilitre (mL)', CookingDimension.volume, 1),
    CookingUnit('l', 'Litre (L)', CookingDimension.volume, 1000),
    CookingUnit('usFlOz', 'US fluid ounce', CookingDimension.volume, 236.5882365 / 8),
    CookingUnit('g', 'Gram (g)', CookingDimension.mass, 1),
    CookingUnit('kg', 'Kilogram (kg)', CookingDimension.mass, 1000),
    CookingUnit('oz', 'Ounce (oz)', CookingDimension.mass, 28.349523125),
    CookingUnit('lb', 'Pound (lb)', CookingDimension.mass, 453.59237),
    CookingUnit('c', 'Celsius (°C)', CookingDimension.temperature, 1),
    CookingUnit('f', 'Fahrenheit (°F)', CookingDimension.temperature, 1),
  ];
  static List<CookingUnit> forDimension(CookingDimension kind) =>
      units.where((u) => u.dimension == kind).toList();
  static CookingUnit unit(String id) => units.firstWhere((u) => u.id == id);
  static double convert(double value, String fromId, String toId) {
    if (!value.isFinite) throw ArgumentError('Enter a valid number');
    final from = unit(fromId), to = unit(toId);
    if (from.dimension != to.dimension) {
      throw ArgumentError('Volume and weight require ingredient density');
    }
    if (from.dimension == CookingDimension.temperature) {
      if (from.id == to.id) return value;
      return from.id == 'c' ? value * 9 / 5 + 32 : (value - 32) * 5 / 9;
    }
    return value * from.toBase / to.toBase;
  }
  static String format(double value) {
    if (!value.isFinite) return '—';
    if (value == 0) return '0';
    return value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
