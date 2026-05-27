import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:pocket_guide_mobile/services/auth_service.dart';
import 'package:pocket_guide_mobile/design_system/colors.dart';

// ---------------------------------------------------------------------------
// Onboarding / Login screen — rawi design
// ---------------------------------------------------------------------------
//  iOS     → Apple Sign-In  +  Google Sign-In
//  Android → Google Sign-In only
//  Web     → Google Sign-In only (OAuth redirect flow)
// ---------------------------------------------------------------------------

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();

  // null = idle, 'google' = google in-flight, 'apple' = apple in-flight
  String? _loading;
  String? _error;

  bool get _isIOS => !kIsWeb && Platform.isIOS;
  bool get _busy  => _loading != null;

  // ── Handlers ──────────────────────────────────────────────────────────────

  Future<void> _handleGoogleLogin() async {
    setState(() { _loading = 'google'; _error = null; });
    try {
      final success = await _auth.login();
      if (!mounted) return;
      if (success) {
        _navigateToMain();
      } else if (kIsWeb) {
        // Web redirect initiated — page navigates away on its own
      } else {
        setState(() => _loading = null); // user cancelled
      }
    } catch (e) {
      if (mounted) setState(() { _loading = null; _error = 'Sign-in failed. Please try again.'; });
    }
  }

  Future<void> _handleAppleLogin() async {
    setState(() { _loading = 'apple'; _error = null; });
    try {
      final success = await _auth.loginWithApple();
      if (!mounted) return;
      if (success) {
        _navigateToMain();
      } else {
        setState(() => _loading = null);
      }
    } catch (e) {
      if (mounted) setState(() { _loading = null; _error = 'Apple sign-in failed. Please try again.'; });
    }
  }

  void _navigateToMain() {
    Navigator.of(context).pushReplacementNamed('/home');
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PGColors.rawiPaper2,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildHero()),
            _buildButtonSection(),
          ],
        ),
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────

  Widget _buildHero() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 1),

        // Logo mark — ClipRRect hides the opaque black corners of the PNG
        ClipRRect(
          borderRadius: BorderRadius.circular(27),
          child: Image.asset(
            'raawi_icon.png',
            width: 120,
            height: 120,
          ),
        ),

        const SizedBox(height: 32),

        // Wordmark — "raawi" + green dot
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: 'raawi',
                style: GoogleFonts.sourceSans3(
                  fontSize: 52,
                  fontWeight: FontWeight.w700,
                  color: PGColors.rawiInk,
                  letterSpacing: -0.03 * 52,
                  height: 1,
                ),
              ),
              TextSpan(
                text: '.',
                style: GoogleFonts.sourceSans3(
                  fontSize: 52,
                  fontWeight: FontWeight.w700,
                  color: PGColors.rawiAccent,
                  letterSpacing: 0,
                  height: 1,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Primary tagline
        Text(
          'The one who narrates,\nwalks with you.',
          textAlign: TextAlign.center,
          style: GoogleFonts.sourceSans3(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: PGColors.rawiInk,
            height: 1.4,
            letterSpacing: -0.01,
          ),
        ),

        const SizedBox(height: 12),

        // Sub-tagline
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Text(
            'Audio tours, narrated by people who actually know the place.',
            textAlign: TextAlign.center,
            style: GoogleFonts.sourceSans3(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: PGColors.rawiInk3,
              height: 1.55,
            ),
          ),
        ),

        const Spacer(flex: 2),
      ],
    );
  }

  // ── Buttons ───────────────────────────────────────────────────────────────

  Widget _buildButtonSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Error banner
          if (_error != null) ...[
            _ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],

          // Apple Sign-In — iOS only
          if (_isIOS) ...[
            _AppleButton(
              onPressed: _busy ? null : _handleAppleLogin,
              loading: _loading == 'apple',
            ),
            const SizedBox(height: 12),
          ],

          // Google Sign-In
          _GoogleButton(
            onTap: _busy ? null : _handleGoogleLogin,
            loading: _loading == 'google',
          ),

          const SizedBox(height: 20),

          // Terms
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.sourceSans3(
                fontSize: 11.5,
                color: PGColors.rawiInk4,
                height: 1.55,
              ),
              children: [
                const TextSpan(text: 'By continuing, you agree to our '),
                TextSpan(
                  text: 'Terms of Service',
                  style: GoogleFonts.sourceSans3(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: PGColors.rawiInk2,
                  ),
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: GoogleFonts.sourceSans3(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: PGColors.rawiInk2,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Apple Sign-In button ─────────────────────────────────────────────────────

class _AppleButton extends StatelessWidget {
  const _AppleButton({this.onPressed, required this.loading});
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: PGColors.rawiInk,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
          ),
        ),
      );
    }
    return SizedBox(
      height: 56,
      child: SignInWithAppleButton(
        onPressed: onPressed ?? () {},
        style: SignInWithAppleButtonStyle.black,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        text: 'Continue with Apple',
      ),
    );
  }
}

// ─── Google Sign-In button ────────────────────────────────────────────────────

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({this.onTap, required this.loading});
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PGColors.rawiHair, width: 1.0),
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: PGColors.rawiInk),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/google_g.png', width: 24, height: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Continue with Google',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: PGColors.rawiInk,
                      letterSpacing: -0.01,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x22FF3B30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x55FF3B30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFFF7B6E), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.sourceSans3(
                fontSize: 13,
                color: const Color(0xFFFF9E96),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

