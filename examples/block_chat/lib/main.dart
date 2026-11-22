import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_screen.dart';
import 'screens/blocks_screen.dart';

/// Inject only the Supabase project URL and publishable (public client) key.
/// Never place a service_role or secret key in a phone build.
const _url = String.fromEnvironment('BLOCK_CHAT_SUPABASE_URL');
const _publishableKey =
    String.fromEnvironment('BLOCK_CHAT_SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_url.startsWith('https://') || _publishableKey.isEmpty) {
    throw StateError(
      'Configure the Block Chat Supabase project before building an installer.',
    );
  }
  await Supabase.initialize(url: _url, anonKey: _publishableKey);
  runApp(const BlockChatApp());
}

class BlockChatApp extends StatefulWidget {
  const BlockChatApp({super.key});
  @override
  State<BlockChatApp> createState() => _BlockChatAppState();
}

class _BlockChatAppState extends State<BlockChatApp> {
  StreamSubscription<AuthState>? _subscription;
  Session? _session;

  @override
  void initState() {
    super.initState();
    final auth = Supabase.instance.client.auth;
    _session = auth.currentSession;
    _subscription = auth.onAuthStateChange.listen((event) {
      if (mounted) setState(() => _session = event.session);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ColorScheme.fromSeed(
      seedColor: const Color(0xFF46CEBC), brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF6CDDCB),
      secondary: const Color(0xFFE5BD71),
      surface: const Color(0xFF142632),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Block Chat',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: palette,
        scaffoldBackgroundColor: const Color(0xFF0D1923),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0D1923)),
        cardTheme: CardThemeData(
          color: const Color(0xFF182E3B),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF182D39),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      home: _session == null
          ? const AuthScreen()
          : BlocksScreen(key: ValueKey(_session!.user.id)),
    );
  }
}
