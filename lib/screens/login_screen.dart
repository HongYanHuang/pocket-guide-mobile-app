import 'dart:math' show pi;
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
      backgroundColor: PGColors.rawiInk,
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
        const Spacer(flex: 2),

        // Wordmark
        Text(
          'rawi',
          textAlign: TextAlign.center,
          style: GoogleFonts.sourceSans3(
            fontSize: 76,
            fontWeight: FontWeight.w800,
            color: PGColors.rawiPaper,
            letterSpacing: -0.04 * 76,
            height: 1,
          ),
        ),

        const SizedBox(height: 14),

        // Tagline
        Text(
          'Walk with a story.',
          textAlign: TextAlign.center,
          style: GoogleFonts.sourceSans3(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            color: PGColors.rawiPaper.withValues(alpha: 0.48),
            letterSpacing: -0.01,
          ),
        ),

        const Spacer(flex: 3),
      ],
    );
  }

  // ── Buttons ───────────────────────────────────────────────────────────────

  Widget _buildButtonSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
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
            const _OrDivider(),
            const SizedBox(height: 12),
          ],

          // Google Sign-In
          _GoogleButton(
            onTap: _busy ? null : _handleGoogleLogin,
            loading: _loading == 'google',
          ),

          const SizedBox(height: 22),

          // Terms
          Text(
            'By continuing, you agree to our Terms of Service and Privacy Policy.',
            textAlign: TextAlign.center,
            style: GoogleFonts.sourceSans3(
              fontSize: 11.5,
              color: PGColors.rawiPaper.withValues(alpha: 0.28),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Apple Sign-In button ─────────────────────────────────────────────────────
// Uses the package widget — required for App Store compliance.

class _AppleButton extends StatelessWidget {
  const _AppleButton({this.onPressed, required this.loading});
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) return const _LoadingPill(light: true);
    return SizedBox(
      height: 56,
      child: SignInWithAppleButton(
        onPressed: onPressed ?? () {},
        style: SignInWithAppleButtonStyle.white,
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
          color: loading
              ? PGColors.rawiPaper.withValues(alpha: 0.88)
              : PGColors.rawiPaper,
          borderRadius: BorderRadius.circular(14),
        ),
        child: loading
            ? const _LoadingPill(light: false)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _GoogleGIcon(size: 20),
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

// ─── Shared loading indicator ─────────────────────────────────────────────────

class _LoadingPill extends StatelessWidget {
  const _LoadingPill({required this.light});
  final bool light; // true → white bg (Apple), false → paper bg (Google)

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: light ? PGColors.rawiInk : PGColors.rawiInk,
          ),
        ),
      ),
    );
  }
}

// ─── "or" divider ─────────────────────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final line = PGColors.rawiPaper.withValues(alpha: 0.14);
    return Row(
      children: [
        Expanded(child: Container(height: 0.5, color: line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or',
            style: GoogleFonts.sourceSans3(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: PGColors.rawiPaper.withValues(alpha: 0.30),
            ),
          ),
        ),
        Expanded(child: Container(height: 0.5, color: line)),
      ],
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

// ─── Google "G" badge (CustomPainter) ────────────────────────────────────────
// Draws the 4-colour Google G: blue ring, red/yellow/green arcs, white centre,
// blue horizontal bar.

class _GoogleGIcon extends StatelessWidget {
  const _GoogleGIcon({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  static const _blue   = Color(0xFF4285F4);
  static const _red    = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green  = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final r    = size.width / 2;
    final c    = Offset(r, r);
    final rect = Rect.fromCircle(center: c, radius: r);
    final p    = Paint()..style = PaintingStyle.fill;

    canvas.save();
    canvas.clipPath(Path()..addOval(rect));

    // Blue base (fills the top arc + bar region by default)
    p.color = _blue;
    canvas.drawCircle(c, r, p);

    // Red: right side (-15° → 105°, sweep 120°)
    p.color = _red;
    canvas.drawArc(rect, -15 * pi / 180, 120 * pi / 180, true, p);

    // Yellow: bottom (105° → 205°, sweep 100°)
    p.color = _yellow;
    canvas.drawArc(rect, 105 * pi / 180, 100 * pi / 180, true, p);

    // Green: left (205° → 335°, sweep 130°)
    p.color = _green;
    canvas.drawArc(rect, 205 * pi / 180, 130 * pi / 180, true, p);

    // White inner circle — creates the G ring
    p.color = Colors.white;
    canvas.drawCircle(c, r * 0.60, p);

    // Blue horizontal bar — the G stroke on the right
    p.color = _blue;
    canvas.drawRect(Rect.fromLTWH(r, r - r * 0.22, r, r * 0.44), p);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
