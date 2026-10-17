import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/api/auth_state.dart';
import '../../../core/theme/theme_provider.dart';

class AuthCallbackScreen extends StatefulWidget {
  final String? code;
  const AuthCallbackScreen({super.key, this.code});

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    final code = widget.code;
    if (code == null || code.isEmpty) {
      setState(() => _error = 'No authorization code received from 180 Identity.');
      return;
    }

    try {
      final authState = context.read<AuthState>();
      await authState.loginWith180(code);
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.watch<ThemeProvider>().tokens;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  '180 Sign-In Failed',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: tokens.onBackground),
                ),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: tokens.onSurfaceVariant)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Back to Login'),
                ),
              ] else ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  'Authenticating with 180 Identity...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: tokens.onBackground),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
