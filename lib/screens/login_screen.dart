import 'package:flutter/cupertino.dart';
import 'package:pocket_guide_mobile/services/auth_service.dart';
import 'package:pocket_guide_mobile/main.dart';
import 'package:pocket_guide_mobile/design_system/colors.dart';
import 'package:pocket_guide_mobile/design_system/typography.dart';
import 'package:pocket_guide_mobile/design_system/spacing.dart';
import 'package:pocket_guide_mobile/design_system/components/pg_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _authService.login();

      // In web mode, login() returns false because the page will redirect to Google
      // We should keep showing loading state and let the redirect happen
      // The page will reload at /auth/callback after Google OAuth
      // So we don't need to handle success/failure here for web mode

      if (success) {
        // This only happens in mobile mode
        // Navigate to main app
        if (mounted) {
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(builder: (context) => const MainScreen()),
          );
        }
      } else {
        // In web mode, this is expected - keep loading state and let redirect happen
        // The page will redirect to Google OAuth, so we won't see this state
        print('🔐 Login initiated, waiting for redirect...');
        // Don't clear loading state - let the redirect happen
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: PGColors.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: PGSpacing.screen,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo/Icon
                Icon(
                  CupertinoIcons.map_fill,
                  size: 100,
                  color: PGColors.brand,
                ),
                SizedBox(height: PGSpacing.xl),

                // App Name
                Text(
                  'Pocket Guide',
                  style: PGTypography.largeTitle.copyWith(
                    color: PGColors.brand,
                  ),
                ),
                SizedBox(height: PGSpacing.s),

                // Tagline
                Text(
                  'Your personalized travel companion',
                  style: PGTypography.body.copyWith(
                    color: PGColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: PGSpacing.xxl * 2),

                // Error message
                if (_errorMessage != null) ...[
                  Container(
                    padding: PGSpacing.paddingL,
                    decoration: BoxDecoration(
                      color: PGColors.errorLight,
                      borderRadius: PGRadius.radiusM,
                      border: Border.all(color: PGColors.error),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.exclamationmark_circle,
                          color: PGColors.error,
                          size: 20,
                        ),
                        SizedBox(width: PGSpacing.s),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: PGTypography.footnote.copyWith(
                              color: PGColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: PGSpacing.xl),
                ],

                // Google Sign In Button
                PGButton(
                  text: _isLoading ? 'Signing in...' : 'Sign in with Google',
                  onPressed: _handleGoogleLogin,
                  isLoading: _isLoading,
                  isFullWidth: true,
                  size: PGButtonSize.large,
                ),
                SizedBox(height: PGSpacing.xl),

                // Terms and Privacy
                Text(
                  'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                  style: PGTypography.caption1.copyWith(
                    color: PGColors.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
