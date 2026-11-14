import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../models/recipe.dart';

/// Best-effort import of structured Recipe data. Sites may block automated
/// access or omit JSON-LD: in those cases the original URL is saved as a link.
class RecipeImportService {
  Future<Recipe> importUrl(String raw) async {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw FormatException('Paste a full https:// recipe link.');
    }
    final fallback = Recipe(
      id: 'web:${uri.toString()}', title: uri.host.replaceFirst('www.', ''),
      source: uri.host.replaceFirst('www.', ''), sourceUrl: uri.toString(),
      linkOnly: true,
    );
    try {
      final response = await http.get(uri, headers: {'Accept': 'text/html'}).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200 || response.bodyBytes.length > 3 * 1024 * 1024) return fallback;
      final doc = html_parser.parse(utf8.decode(response.bodyBytes, allowMalformed: true));
      final title = doc.querySelector('meta[property="og:title"]')?.attributes['content'] ?? doc.querySelector('title')?.text ?? fallback.title;
      final bestFallback = fallback.copyWith(title: title.trim().isEmpty ? fallback.title : title.trim());
      for (final script in doc.querySelectorAll('script[type="application/ld+json"]')) {
        try {
          final parsed = jsonDecode(script.text);
          for (final node in _walk(parsed)) {
            final type = node['@type'];
            final types = type is List ? type.map((e) => '$e').toList() : ['$type'];
            if (!types.any((t) => t.toLowerCase() == 'recipe' || t.toLowerCase().endsWith('/recipe'))) continue;
            final ingredients = _asTexts(node['recipeIngredient']);
            final steps = _instructions(node['recipeInstructions']);
            final name = _plain('${node['name'] ?? title}');
            final picture = _image(node['image'], uri);
            return Recipe(
              id: fallback.id, title: name.isEmpty ? bestFallback.title : name,
              source: bestFallback.source, sourceUrl: uri.toString(), imageUrl: picture,
              category: _plain('${node['recipeCategory'] ?? ''}'),
              cuisine: _plain('${node['recipeCuisine'] ?? ''}'),
              ingredients: ingredients, steps: steps,
              linkOnly: ingredients.isEmpty && steps.isEmpty,
            );
          }
        } catch (_) { /* Invalid JSON-LD on this page; try the next script. */ }
      }
      return bestFallback;
    } catch (_) {
      return fallback;
    }
  }

  Iterable<Map<String, dynamic>> _walk(dynamic input) sync* {
    if (input is List) {
      for (final value in input) { yield* _walk(value); }
    } else if (input is Map) {
      final map = Map<String, dynamic>.from(input);
      yield map;
      if (map['@graph'] != null) yield* _walk(map['@graph']);
      if (map['mainEntity'] != null) yield* _walk(map['mainEntity']);
    }
  }

  String _plain(String input) => html_parser.parseFragment(input).text?.trim() ?? '';

  List<String> _asTexts(dynamic input) {
    if (input == null) return [];
    final elements = input is List ? input : [input];
    return elements.map((e) => _plain('$e')).where((e) => e.isNotEmpty).toList();
  }

  List<String> _instructions(dynamic input) {
    if (input == null) return [];
    if (input is String) return input.trim().isEmpty ? [] : [ _plain(input) ];
    if (input is Map) {
      final map = Map<String, dynamic>.from(input);
      if (map['itemListElement'] != null) return _instructions(map['itemListElement']);
      final text = _plain('${map['text'] ?? map['name'] ?? ''}');
      return text.isEmpty ? [] : [text];
    }
    if (input is List) return input.expand((e) => _instructions(e)).toList();
    return [];
  }

  String _image(dynamic value, Uri base) {
    dynamic current = value;
    if (current is List && current.isNotEmpty) current = current.first;
    if (current is Map) current = current['url'] ?? current['contentUrl'];
    if (current == null) return '';
    final parsed = Uri.tryParse('$current');
    if (parsed == null) return '';
    final finalUrl = base.resolveUri(parsed);
    return finalUrl.scheme == 'https' ? finalUrl.toString() : '';
  }
}
