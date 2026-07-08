import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_gate.dart';
import 'theme/app_theme.dart';

Future<void> initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
    debugPrint('DOTENV: loaded OK');
  } catch (e) {
    debugPrint('DOTENV LOAD ERROR: $e');
  }

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabasePublishableKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  debugPrint('SUPABASE_URL="$supabaseUrl"');
  debugPrint('SUPABASE_ANON_KEY length=${supabasePublishableKey.length}');

  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    debugPrint('SUPABASE INIT SKIPPED: empty url or key');
    return;
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
    debugPrint('SUPABASE: initialized OK');
  } catch (e) {
    debugPrint('SUPABASE INIT ERROR: $e');
  }
}

void main() async {
  await initializeApp();
  runApp(const SplitEasyApp());
}

class SplitEasyApp extends StatelessWidget {
  const SplitEasyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SplitEasy',
      theme: AppTheme.theme,
      home: const AuthGate(),
    );
  }
}
