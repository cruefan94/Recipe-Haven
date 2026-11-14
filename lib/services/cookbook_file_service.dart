import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'cookbook_store.dart';

/// Cross-platform user-initiated JSON backup file export/import.
/// No cloud account, background sync or broad storage access is required.
class CookbookFileService {
  static const int maxBytes = 8 * 1024 * 1024;

  static Future<bool> saveBackup(CookbookStore cookbook) async {
    final bytes = Uint8List.fromList(utf8.encode(cookbook.exportBackup()));
    if (bytes.length > maxBytes) {
      throw const FormatException('Cookbook is too large for JSON file backup.');
    }
    final now = DateTime.now();
    final date = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final savedLocation = await FilePicker.saveFile(
      dialogTitle: 'Save Recipe Haven cookbook',
      fileName: 'Recipe-Haven-cookbook-$date.json',
      bytes: bytes,
      mimeType: 'application/json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    return savedLocation != null;
  }

  /// Returns null for cancellation or the count of newly restored recipes.
  /// CookbookStore validates the data and rolls back failed persistence.
  static Future<int?> restoreBackup(CookbookStore cookbook) async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Select Recipe Haven backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return null;
    final reportedLength = file.lengthSync() ?? await file.length();
    if (reportedLength != null && reportedLength > maxBytes) {
      throw const FormatException('Backup file exceeds 8 MB.');
    }
    final data = await file.readAsBytes();
    if (data.length > maxBytes) {
      throw const FormatException('Backup file exceeds 8 MB.');
    }
    return cookbook.mergeBackup(utf8.decode(data, allowMalformed: false));
  }
}
