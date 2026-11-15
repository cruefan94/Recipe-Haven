import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A UI privacy gate for the separate cookbook. Recipes and JSON exports are
/// not encrypted by this verifier; do not describe this as encrypted storage.
class PrivateCookbookPassword {
  PrivateCookbookPassword({SharedPreferencesAsync? preferences})
      : _prefs = preferences ?? SharedPreferencesAsync();

  static const _key = 'recipe_haven_private_cookbook_password_v1';
  static const _iterations = 120000;
  final SharedPreferencesAsync _prefs;

  Future<bool> get isConfigured async {
    final value = await _prefs.getString(_key);
    return value != null && value.isNotEmpty;
  }

  static Future<String> buildVerifier(
    String password, {
    List<int>? salt,
  }) async {
    if (password.length < 8) {
      throw const FormatException('Choose a password with at least 8 characters.');
    }
    final random = Random.secure();
    final nonce = salt ?? List<int>.generate(24, (_) => random.nextInt(256));
    if (nonce.length < 16) {
      throw const FormatException('Salt must be at least 16 bytes.');
    }
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: 256,
    ).deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: nonce,
    );
    return 'v1:' + base64Encode(nonce) + ':' +
        base64Encode(await key.extractBytes());
  }

  static Future<bool> verifyVerifier(String verifier, String password) async {
    final parts = verifier.split(':');
    if (parts.length != 3 || parts[0] != 'v1') return false;
    try {
      final salt = base64Decode(parts[1]);
      final expected = base64Decode(parts[2]);
      if (salt.length < 16 || expected.length != 32) return false;
      final generated = await buildVerifier(password, salt: salt);
      final actual = base64Decode(generated.split(':')[2]);
      var difference = 0;
      for (var i = 0; i < expected.length; i++) {
        difference |= expected[i] ^ actual[i];
      }
      return difference == 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> create(String password) async {
    if (await isConfigured) {
      throw StateError('The private cookbook password is already configured.');
    }
    final verifier = await buildVerifier(password);
    await _prefs.setString(_key, verifier);
  }

  Future<bool> verify(String password) async {
    final verifier = await _prefs.getString(_key);
    if (verifier == null || verifier.isEmpty) return false;
    return verifyVerifier(verifier, password);
  }
}
