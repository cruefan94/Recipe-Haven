import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/kitchen_conversion.dart';

class KitchenConverterScreen extends StatefulWidget {
  const KitchenConverterScreen({super.key});
  @override
  State<KitchenConverterScreen> createState() => _KitchenConverterScreenState();
}

class _KitchenConverterScreenState extends State<KitchenConverterScreen> {
  final amount = TextEditingController(text: '1');
  CookingDimension dimension = CookingDimension.volume;
  String from = 'usCup', to = 'usTbsp';

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }
  void pick(CookingDimension kind) {
    setState(() {
      dimension = kind;
      switch (kind) {
        case CookingDimension.volume: from = 'usCup'; to = 'usTbsp';
        case CookingDimension.mass: from = 'lb'; to = 'g';
        case CookingDimension.temperature: from = 'f'; to = 'c';
      }
    });
  }
  void preset(CookingDimension kind, String a, String b, String value) {
    setState(() { dimension = kind; from = a; to = b; amount.text = value; });
  }
  @override
  Widget build(BuildContext context) {
    final value = double.tryParse(amount.text.trim().replaceAll(',', '.'));
    final converted = value == null ? null : KitchenConversion.convert(value, from, to);
    final answer = converted == null ? 'Enter an amount'
      : KitchenConversion.format(converted) + ' ' + KitchenConversion.unit(to).label;
    final options = KitchenConversion.forDimension(dimension);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Kitchen Converter', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text('Convert cooking measurements, weights, and oven temperatures.'),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ChoiceChip(label: const Text('Volume'),
            selected: dimension == CookingDimension.volume,
            onSelected: (_) => pick(CookingDimension.volume)),
        ChoiceChip(label: const Text('Weight'),
            selected: dimension == CookingDimension.mass,
            onSelected: (_) => pick(CookingDimension.mass)),
        ChoiceChip(label: const Text('Oven temperature'),
            selected: dimension == CookingDimension.temperature,
            onSelected: (_) => pick(CookingDimension.temperature)),
      ]),
      const SizedBox(height: 16),
      TextField(
        key: const ValueKey('converter-amount'),
        controller: amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: const InputDecoration(labelText: 'Amount'),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey('converter-from-' + dimension.name),
        initialValue: from,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'From'),
        items: options.map((u) => DropdownMenuItem(value: u.id, child: Text(u.label))).toList(),
        onChanged: (v) { if (v != null) setState(() => from = v); },
      ),
      Center(child: IconButton(
        tooltip: 'Swap units',
        icon: const Icon(Icons.swap_vert_rounded),
        onPressed: () => setState(() {
          final previous = from; from = to; to = previous;
        }),
      )),
      DropdownButtonFormField<String>(
        key: ValueKey('converter-to-' + dimension.name),
        initialValue: to,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'To'),
        items: options.map((u) => DropdownMenuItem(value: u.id, child: Text(u.label))).toList(),
        onChanged: (v) { if (v != null) setState(() => to = v); },
      ),
      const SizedBox(height: 16),
      Card(child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Converted amount'),
          const SizedBox(height: 6),
          SelectableText(answer,
            key: const ValueKey('converter-result'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: converted == null ? null : () async {
              await Clipboard.setData(ClipboardData(text: answer));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Conversion copied')));
              }
            },
            icon: const Icon(Icons.copy_outlined), label: const Text('Copy'),
          ),
        ]),
      )),
      const SizedBox(height: 16),
      const Text('Common conversions'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ActionChip(key: const ValueKey('cup-to-tbsp'),
          label: const Text('1 US cup → tablespoons'),
          onPressed: () => preset(CookingDimension.volume, 'usCup', 'usTbsp', '1')),
        ActionChip(label: const Text('1 metric cup → mL'),
          onPressed: () => preset(CookingDimension.volume, 'metricCup', 'ml', '1')),
        ActionChip(label: const Text('350°F → °C'),
          onPressed: () => preset(CookingDimension.temperature, 'f', 'c', '350')),
        ActionChip(label: const Text('1 lb → grams'),
          onPressed: () => preset(CookingDimension.mass, 'lb', 'g', '1')),
      ]),
      const SizedBox(height: 14),
      const Text('US cup = 16 US tablespoons. A metric cup = 250 mL. '
        'Converting a cup of flour or sugar into grams requires an '
        'ingredient-specific density, so volume and weight stay separate.'),
    ]);
  }
}
