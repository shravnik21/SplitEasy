import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'groups_list_screen.dart';

/// Shows LoginScreen if signed out, GroupsListScreen if signed in.
/// Rebuilds automatically on sign-in, sign-out, and token refresh.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        if (session != null) {
          return const GroupsListScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
