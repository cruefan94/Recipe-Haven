import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Receives Android ACTION_SEND recipe links without auto-saving them.
/// The user reviews the link in Add Recipe and chooses which cookbook to use.
class IncomingRecipeShare extends ChangeNotifier {
  IncomingRecipeShare._();

  static final IncomingRecipeShare instance = IncomingRecipeShare._();
  static const MethodChannel _channel =
      MethodChannel('recipe_haven/shared_recipe');

  bool _initialized = false;
  String? _pendingUrl;

  Future<void> initialize() async {
    if (_initialized || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedRecipeUrl') {
        _receive(call.arguments);
      }
    });

    // Cold-launch: the native Activity keeps the link until Dart is ready.
    try {
      _receive(await _channel.invokeMethod<String>('takeInitialShare'));
    } on MissingPluginException {
      // Android host is not configured; normal recipe entry still works.
    } on PlatformException {
      // Ignore an unavailable share bridge rather than blocking startup.
    }
  }

  void _receive(dynamic raw) {
    if (raw is! String || raw.length > 2048) return;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return;
    }
    _pendingUrl = uri.toString();
    notifyListeners();
  }

  /// Returns and clears the next shared link exactly once.
  String? takePendingUrl() {
    final value = _pendingUrl;
    _pendingUrl = null;
    return value;
  }
}
