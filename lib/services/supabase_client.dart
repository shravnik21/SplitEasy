import 'package:supabase_flutter/supabase_flutter.dart';

/// Returns the shared Supabase client when the SDK has been initialized.
/// Returns null in tests or when environment credentials are unavailable.
SupabaseClient? getSupabaseClient() {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}
