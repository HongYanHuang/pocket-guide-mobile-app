import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pocket_guide_mobile/models/user_model.dart';
import 'package:pocket_guide_mobile/screens/login_screen.dart';
import 'package:pocket_guide_mobile/services/api_service.dart';
import 'package:pocket_guide_mobile/services/auth_service.dart';

// ---------------------------------------------------------------------------
// Rawi dark account palette
// ---------------------------------------------------------------------------
const _kBg       = Color(0xFF1C1916);
const _kSurface  = Color(0xFF272320);
const _kInk      = Color(0xFFF6F1E7);   // rawiPaper — primary text on dark
const _kInk2     = Color(0xFFB8AA9E);   // secondary text
const _kInk3     = Color(0xFF7A6E65);   // muted / disabled text
const _kDivider  = Color(0xFF302C28);   // subtle row dividers
const _kRed      = Color(0xFFD45B5B);   // destructive

// ---------------------------------------------------------------------------
// AccountScreen — top-level "Account" tab
// ---------------------------------------------------------------------------

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _auth = AuthService();
  User? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _auth.getCurrentUser();
    if (mounted) setState(() { _user = user; _loading = false; });
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  bool _isApple(String email) =>
      email.endsWith('@privaterelay.appleid.com');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: _kInk3, strokeWidth: 2))
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final user = _user;
    if (user == null) {
      return Center(
        child: Text(
          'Unable to load account',
          style: GoogleFonts.sourceSans3(color: _kInk2),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Page title
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Text(
            'you.',
            style: GoogleFonts.sourceSans3(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: _kInk,
              letterSpacing: -0.5,
            ),
          ),
        ),

        const SizedBox(height: 36),

        // ── Avatar + name / email + provider badge
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _Avatar(
                initials: _initials(user.name),
                pictureUrl: user.picture,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: GoogleFonts.sourceSans3(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: _kInk,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: GoogleFonts.sourceSans3(
                        fontSize: 13,
                        color: _kInk2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    _ProviderBadge(isApple: _isApple(user.email)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),

        // ── Navigation rows
        const Divider(color: _kDivider, thickness: 1, height: 1),
        _NavRow(
          icon: CupertinoIcons.time,
          label: 'Tour History',
          onTap: () => Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => const _HistoryScreen()),
          ),
        ),
        const Divider(color: _kDivider, thickness: 1, height: 1),
        _NavRow(
          icon: CupertinoIcons.slider_horizontal_3,
          label: 'Account Settings',
          onTap: () => Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => const _SettingsScreen()),
          ),
        ),
        const Divider(color: _kDivider, thickness: 1, height: 1),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// History screen
// ---------------------------------------------------------------------------

class _HistoryScreen extends StatefulWidget {
  const _HistoryScreen();

  @override
  State<_HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<_HistoryScreen> {
  final _api  = ApiService();
  final _auth = AuthService();
  List<Map<String, dynamic>> _tours = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTours();
  }

  Future<void> _loadTours() async {
    try {
      final token = await _auth.getAccessToken();
      if (token == null) throw Exception('Not authenticated');
      final raw = await _api.getMyTours(token);
      if (mounted) {
        setState(() {
          _tours = raw.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _BackHeader(title: 'Tour History'),
            const Divider(color: _kDivider, thickness: 1, height: 1),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _kInk3, strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Text(
          'Failed to load tours',
          style: GoogleFonts.sourceSans3(color: _kInk2),
        ),
      );
    }
    if (_tours.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.map, size: 48, color: _kInk3),
            const SizedBox(height: 16),
            Text('No tours yet',
                style: GoogleFonts.sourceSans3(fontSize: 16, color: _kInk2)),
            const SizedBox(height: 8),
            Text(
              'Your completed tours will appear here.',
              style: GoogleFonts.sourceSans3(fontSize: 13, color: _kInk3),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _tours.length,
      separatorBuilder: (_, __) =>
          const Divider(color: _kDivider, height: 1, thickness: 1),
      itemBuilder: (_, i) => _TourRow(tour: _tours[i]),
    );
  }
}

class _TourRow extends StatelessWidget {
  const _TourRow({required this.tour});
  final Map<String, dynamic> tour;

  String get _title =>
      (tour['title_display'] as String?)?.isNotEmpty == true
          ? tour['title_display'] as String
          : (tour['city'] as String? ?? 'Tour');

  String get _city  => (tour['city'] as String?) ?? '';
  int    get _days  => (tour['duration_days'] as int?) ?? 1;

  String get _date {
    final raw = tour['created_at'] as String?;
    if (raw == null) return '';
    try {
      return DateFormat('MMM yyyy').format(DateTime.parse(raw));
    } catch (_) { return ''; }
  }

  String? get _coverUrl {
    final images = tour['images'];
    if (images is! Map) return null;
    final cover = images['cover'];
    if (cover is! Map) return null;
    final url = cover['url'] as String?;
    if (url == null) return null;
    return url.startsWith('http') ? url : '${ApiService.baseUrl}$url';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 64,
              height: 64,
              child: _coverUrl != null
                  ? Image.network(
                      _coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
          const SizedBox(width: 14),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: GoogleFonts.sourceSans3(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _kInk,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                if (_city.isNotEmpty) ...[
                  Text(_city,
                      style: GoogleFonts.sourceSans3(
                          fontSize: 13, color: _kInk2)),
                  const SizedBox(height: 2),
                ],
                Text(
                  [
                    if (_date.isNotEmpty) _date,
                    _days == 1 ? '1 day' : '$_days days',
                  ].join(' · '),
                  style: GoogleFonts.sourceSans3(
                      fontSize: 12, color: _kInk3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        color: _kSurface,
        child: const Icon(CupertinoIcons.map, color: _kInk3, size: 24),
      );
}

// ---------------------------------------------------------------------------
// Settings screen
// ---------------------------------------------------------------------------

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _BackHeader(title: 'Account Settings'),
            const Divider(color: _kDivider, thickness: 1, height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _SectionLabel('PREFERENCES'),
                  _InfoRow(label: 'Language', value: 'English'),
                  const Divider(color: _kDivider, height: 1, thickness: 1),
                  _InfoRow(label: 'Units', value: 'Metric (km)'),
                  const Divider(color: _kDivider, height: 1, thickness: 1),
                  const SizedBox(height: 28),
                  _SectionLabel('LEGAL'),
                  _LinkRow(
                    label: 'Terms of Service',
                    url: 'https://www.google.com',
                  ),
                  const Divider(color: _kDivider, height: 1, thickness: 1),
                  _LinkRow(
                    label: 'Privacy Policy',
                    url: 'https://www.google.com',
                  ),
                  const Divider(color: _kDivider, height: 1, thickness: 1),
                  const SizedBox(height: 40),
                  const _SignOutButton(),
                  const SizedBox(height: 14),
                  const _DeleteAccountButton(),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Delete account screen
// ---------------------------------------------------------------------------

class _DeleteAccountScreen extends StatefulWidget {
  const _DeleteAccountScreen();

  @override
  State<_DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<_DeleteAccountScreen> {
  bool _confirmed = false;
  bool _deleting  = false;
  final _auth = AuthService();
  final _api  = ApiService();

  Future<void> _handleDelete() async {
    final proceed = await _showConfirmSheet();
    if (proceed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final token = await _auth.getAccessToken();
      if (token == null) throw Exception('Not authenticated');
      await _api.deleteAccount(token);
      // Logout clears tokens even if the backend call fails
      // (since sessions are already revoked server-side)
      await _auth.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete account. Please try again.'),
          ),
        );
      }
    }
  }

  Future<bool?> _showConfirmSheet() {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delete Account?',
                style: GoogleFonts.sourceSans3(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _kInk,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This will permanently delete your account and anonymise your '
                'personal data. Your tours will remain but will no longer be '
                'linked to you. You can create a new account at any time.',
                style: GoogleFonts.sourceSans3(
                    fontSize: 14, color: _kInk2, height: 1.55),
              ),
              const SizedBox(height: 28),
              _SheetButton(
                label: 'Cancel',
                color: _kDivider,
                textColor: _kInk,
                onTap: () => Navigator.pop(ctx, false),
              ),
              const SizedBox(height: 10),
              _SheetButton(
                label: 'Delete Account',
                color: _kRed.withOpacity(0.15),
                textColor: _kRed,
                onTap: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _BackHeader(title: 'Delete Account'),
            const Divider(color: _kDivider, thickness: 1, height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ConsequenceBlock(
                      title: 'What will be deleted',
                      isWarning: true,
                      items: [
                        'All active sessions and sign-in access',
                        'Your personal data (email & name) will be anonymised',
                      ],
                    ),
                    const SizedBox(height: 20),
                    _ConsequenceBlock(
                      title: 'What will remain',
                      isWarning: false,
                      items: [
                        'Your tour history (kept, but unlinked from your identity)',
                        'You can create a new account at any time',
                      ],
                    ),
                    const SizedBox(height: 36),
                    // Confirmation checkbox
                    GestureDetector(
                      onTap: () =>
                          setState(() => _confirmed = !_confirmed),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _confirmed
                                ? CupertinoIcons.checkmark_square_fill
                                : CupertinoIcons.square,
                            size: 22,
                            color: _confirmed ? _kRed : _kInk3,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'I understand this is permanent and cannot be undone.',
                              style: GoogleFonts.sourceSans3(
                                fontSize: 14,
                                color: _kInk2,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Delete button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: _deleting
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: _kRed, strokeWidth: 2))
                          : ElevatedButton(
                              onPressed: _confirmed ? _handleDelete : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _confirmed
                                    ? _kRed.withOpacity(0.15)
                                    : _kSurface,
                                disabledBackgroundColor: _kSurface,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: _confirmed
                                        ? _kRed.withOpacity(0.5)
                                        : _kDivider,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Delete My Account',
                                style: GoogleFonts.sourceSans3(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _confirmed ? _kRed : _kInk3,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sub-widgets
// ---------------------------------------------------------------------------

class _BackHeader extends StatelessWidget {
  const _BackHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 24, 12),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: const Icon(CupertinoIcons.chevron_back,
                color: _kInk, size: 28),
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: GoogleFonts.sourceSans3(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _kInk,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, this.pictureUrl});
  final String initials;
  final String? pictureUrl;

  @override
  Widget build(BuildContext context) {
    if (pictureUrl != null && pictureUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          pictureUrl!,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _circle(),
        ),
      );
    }
    return _circle();
  }

  Widget _circle() => Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: _kInk,   // warm ivory circle on dark bg
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: GoogleFonts.sourceSans3(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _kBg,   // dark text on ivory
          ),
        ),
      );
}

class _ProviderBadge extends StatelessWidget {
  const _ProviderBadge({required this.isApple});
  final bool isApple;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kDivider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isApple)
            Text(
              '',   // Apple symbol (Unicode U+F8FF)
              style: TextStyle(fontSize: 12, color: _kInk2),
            )
          else
            Text(
              'G',
              style: GoogleFonts.sourceSans3(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4285F4),
              ),
            ),
          const SizedBox(width: 5),
          Text(
            isApple ? 'Apple' : 'Google',
            style: GoogleFonts.sourceSans3(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _kInk2,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: _kDivider,
        highlightColor: _kDivider.withOpacity(0.5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 20, color: _kInk2),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.sourceSans3(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: _kInk,
                  ),
                ),
              ),
              const Icon(CupertinoIcons.chevron_right,
                  size: 16, color: _kInk3),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Text(
        text,
        style: GoogleFonts.sourceSans3(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _kInk3,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: GoogleFonts.sourceSans3(fontSize: 16, color: _kInk)),
          ),
          Row(
            children: [
              Text(value,
                  style: GoogleFonts.sourceSans3(
                      fontSize: 15, color: _kInk3)),
              const SizedBox(width: 6),
              const Icon(CupertinoIcons.lock, size: 13, color: _kInk3),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.url});
  final String label;
  final String url;

  Future<void> _launch() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _launch,
        splashColor: _kDivider,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style:
                        GoogleFonts.sourceSans3(fontSize: 16, color: _kInk)),
              ),
              const Icon(CupertinoIcons.chevron_right,
                  size: 16, color: _kInk3),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignOutButton extends StatefulWidget {
  const _SignOutButton();

  @override
  State<_SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends State<_SignOutButton> {
  bool _loading = false;
  final _auth = AuthService();

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kSurface,
        title: Text('Sign Out?',
            style: GoogleFonts.sourceSans3(
                color: _kInk, fontWeight: FontWeight.w700)),
        content: Text(
          'You will need to sign in again to access your account.',
          style: GoogleFonts.sourceSans3(color: _kInk2, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.sourceSans3(color: _kInk2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sign Out',
                style: GoogleFonts.sourceSans3(color: _kRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    await _auth.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _loading ? null : _signOut,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kSurface,
            disabledBackgroundColor: _kSurface,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: _kDivider),
            ),
          ),
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: _kInk2, strokeWidth: 2))
              : Text(
                  'Sign Out',
                  style: GoogleFonts.sourceSans3(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _kInk,
                  ),
                ),
        ),
      ),
    );
  }
}

class _DeleteAccountButton extends StatelessWidget {
  const _DeleteAccountButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => const _DeleteAccountScreen()),
          ),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kRed.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.trash,
                    size: 18, color: _kRed.withOpacity(0.7)),
                const SizedBox(width: 10),
                Text(
                  'Delete Account',
                  style: GoogleFonts.sourceSans3(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: _kRed.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsequenceBlock extends StatelessWidget {
  const _ConsequenceBlock({
    required this.title,
    required this.items,
    required this.isWarning,
  });
  final String title;
  final List<String> items;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.sourceSans3(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isWarning ? _kRed.withOpacity(0.8) : _kInk3,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isWarning ? _kRed.withOpacity(0.07) : _kSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isWarning ? _kRed.withOpacity(0.22) : _kDivider,
            ),
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        isWarning
                            ? CupertinoIcons.xmark_circle
                            : CupertinoIcons.checkmark_circle,
                        size: 15,
                        color: isWarning
                            ? _kRed.withOpacity(0.6)
                            : _kInk3,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.value,
                        style: GoogleFonts.sourceSans3(
                          fontSize: 14,
                          color: isWarning ? _kInk2 : _kInk3,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          label,
          style: GoogleFonts.sourceSans3(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
