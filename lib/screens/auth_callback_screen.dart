import 'package:flutter/material.dart';
import 'package:pocket_guide_mobile/services/auth_service.dart';

class AuthCallbackScreen extends StatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  final AuthService _authService = AuthService();
  String _status = 'Processing login...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    try {
      // Get URL from browser
      final uri = Uri.base;
      final code = uri.queryParameters['code'];
      final state = uri.queryParameters['state'];
      final error = uri.queryParameters['error'];

      // Check for OAuth errors
      if (error != null) {
        setState(() {
          _status = 'Login failed: $error';
          _hasError = true;
        });
        _redirectToLogin('OAuth error: $error');
        return;
      }

      // Validate parameters
      if (code == null || state == null) {
        setState(() {
          _status = 'Invalid callback parameters';
          _hasError = true;
        });
        _redirectToLogin('Missing authorization code or state');
        return;
      }

      // Update status
      setState(() {
        _status = 'Exchanging code for tokens...';
      });

      // Exchange code for tokens
      print('🔐 AuthCallback: Exchanging code for tokens...');
      final success = await _authService.handleWebCallback(code, state);

      if (success) {
        print('✅ AuthCallback: Token exchange successful!');
        setState(() {
          _status = 'Login successful! Redirecting...';
        });

        // Wait a bit to show success message
        await Future.delayed(const Duration(milliseconds: 500));

        // Navigate to home
        print('🏠 AuthCallback: Navigating to /home...');
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/home',
            (route) => false,
          );
          print('✅ AuthCallback: Navigation to /home completed');
        } else {
          print('❌ AuthCallback: Widget not mounted, cannot navigate');
        }
      } else {
        print('❌ AuthCallback: Token exchange failed');
        setState(() {
          _status = 'Login failed';
          _hasError = true;
        });
        _redirectToLogin('Failed to complete login');
      }
    } catch (e) {
      setState(() {
        _status = 'Error: ${e.toString()}';
        _hasError = true;
      });
      _redirectToLogin(e.toString());
    }
  }

  void _redirectToLogin(String errorMessage) {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_hasError) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
              ] else ...[
                Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.red.shade300,
                ),
                const SizedBox(height: 24),
              ],
              Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: _hasError ? Colors.red.shade700 : Colors.grey.shade700,
                ),
              ),
              if (_hasError) ...[
                const SizedBox(height: 16),
                const Text(
                  'Redirecting to login...',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
