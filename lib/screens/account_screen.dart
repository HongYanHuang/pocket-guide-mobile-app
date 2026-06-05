import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pocket_guide_mobile/design_system/colors.dart';
import 'package:pocket_guide_mobile/models/user_model.dart';
import 'package:pocket_guide_mobile/screens/login_screen.dart';
import 'package:pocket_guide_mobile/services/api_service.dart';
import 'package:pocket_guide_mobile/services/auth_service.dart';

// ---------------------------------------------------------------------------
// AccountScreen — "You" tab
// Light rawi paper theme throughout.
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

  // Apple relay emails always end with @privaterelay.appleid.com
  bool _isApple(String email) => email.endsWith('@privaterelay.appleid.com');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PGColors.rawiPaper,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                    color: PGColors.rawiInk3, strokeWidth: 2))
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final user = _user;
    if (user == null) {
      return Center(
        child: Text('Unable to load account',
            style: GoogleFonts.sourceSans3(color: PGColors.rawiInk3)),
      );
    }

    return CustomScrollView(
      slivers: [
        // ── Large title "Account"
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              'Account',
              style: GoogleFonts.sourceSans3(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: PGColors.rawiInk,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),

        // ── Avatar + name
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            child: Column(
              children: [
                _Avatar(
                  initials: _initials(user.name),
                  pictureUrl: user.picture,
                  isApple: _isApple(user.email),
                ),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  style: GoogleFonts.sourceSans3(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: PGColors.rawiInk,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),

        // ── YOUR LIBRARY section
        SliverToBoxAdapter(
          child: _Section(
            label: 'YOUR LIBRARY',
            rows: [
              _Row(
                icon: CupertinoIcons.clock,
                label: 'History',
                onTap: () => Navigator.push(context,
                    CupertinoPageRoute(
                        builder: (_) => const _HistoryScreen(
                            title: 'History'))),
              ),
              _RowDivider(),
              _Row(
                icon: CupertinoIcons.pencil,
                label: 'My personalized tours',
                onTap: () => Navigator.push(context,
                    CupertinoPageRoute(
                        builder: (_) => const _HistoryScreen(
                            title: 'My personalized tours'))),
              ),
            ],
          ),
        ),

        // ── PREFERENCES section
        SliverToBoxAdapter(
          child: _Section(
            label: 'PREFERENCES',
            rows: [
              _Row(
                icon: CupertinoIcons.bell,
                label: 'Notifications',
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Notification settings coming soon.')),
                ),
              ),
              _RowDivider(),
              _InfoRow(
                icon: CupertinoIcons.globe,
                label: 'Language',
                value: 'English',
              ),
              _RowDivider(),
              _InfoRow(
                icon: CupertinoIcons.arrow_2_squarepath,
                label: 'Units',
                value: 'Kilometres',
              ),
              _RowDivider(),
              _AutoPlayRow(),
            ],
          ),
        ),

        // ── Account settings link
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: _Row(
              icon: CupertinoIcons.settings,
              label: 'Account settings',
              onTap: () => Navigator.push(context,
                  CupertinoPageRoute(
                      builder: (_) => const _AccountSettingsScreen())),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// History / My personalized tours screen
// ---------------------------------------------------------------------------

class _HistoryScreen extends StatefulWidget {
  const _HistoryScreen({required this.title});
  final String title;

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
      backgroundColor: PGColors.rawiPaper,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NavHeader(title: widget.title),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(
              color: PGColors.rawiInk3, strokeWidth: 2));
    }
    if (_error != null || _tours.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.map, size: 44, color: PGColors.rawiInk4),
            const SizedBox(height: 14),
            Text('No tours yet',
                style: GoogleFonts.sourceSans3(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: PGColors.rawiInk3)),
            const SizedBox(height: 6),
            Text('Your tours will appear here.',
                style: GoogleFonts.sourceSans3(
                    fontSize: 13, color: PGColors.rawiInk4)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _tours.length,
      separatorBuilder: (_, __) => const Divider(
          color: PGColors.rawiHair, height: 1, thickness: 1,
          indent: 20, endIndent: 20),
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
              width: 60,
              height: 60,
              child: _coverUrl != null
                  ? Image.network(_coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title,
                    style: GoogleFonts.sourceSans3(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: PGColors.rawiInk),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                if (_city.isNotEmpty) ...[
                  Text(_city,
                      style: GoogleFonts.sourceSans3(
                          fontSize: 13, color: PGColors.rawiInk3)),
                  const SizedBox(height: 2),
                ],
                Text(
                  [
                    if (_date.isNotEmpty) _date,
                    _days == 1 ? '1 day' : '$_days days',
                  ].join(' · '),
                  style: GoogleFonts.sourceSans3(
                      fontSize: 12, color: PGColors.rawiInk4),
                ),
              ],
            ),
          ),
          const Icon(CupertinoIcons.chevron_right,
              size: 14, color: PGColors.rawiInk4),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        color: PGColors.rawiPaper2,
        child: const Icon(CupertinoIcons.map,
            color: PGColors.rawiInk4, size: 22),
      );
}

// ---------------------------------------------------------------------------
// Account Settings screen
// ---------------------------------------------------------------------------

class _AccountSettingsScreen extends StatelessWidget {
  const _AccountSettingsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PGColors.rawiPaper,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NavHeader(title: 'Account settings'),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 8),

                  // Link account (placeholder)
                  _Section(
                    label: 'LINKED ACCOUNTS',
                    rows: [
                      _Row(
                        icon: CupertinoIcons.link,
                        label: 'Link account',
                        trailing: _badge('Soon'),
                        onTap: () {},
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Sign out
                  _Section(
                    rows: [
                      _Row(
                        icon: CupertinoIcons.arrow_right_square,
                        label: 'Sign Out',
                        labelColor: PGColors.rawiInk,
                        onTap: () => _confirmSignOut(context),
                        showChevron: false,
                      ),
                    ],
                  ),

                  // Large spacer — Delete is kept far from Sign Out
                  const SizedBox(height: 120),

                  // Delete account — kept far from Sign Out (App Store requirement)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DANGER ZONE',
                          style: GoogleFonts.sourceSans3(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFD45B5B).withOpacity(0.7),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _DestructiveRow(
                          icon: CupertinoIcons.trash,
                          label: 'Delete Account',
                          onTap: () => Navigator.push(
                            context,
                            CupertinoPageRoute(
                                builder: (_) => const _DeleteAccountScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: PGColors.rawiHairSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: GoogleFonts.sourceSans3(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: PGColors.rawiInk4,
              letterSpacing: 0.3)),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: PGColors.rawiPaper,
        title: Text('Sign Out?',
            style: GoogleFonts.sourceSans3(
                color: PGColors.rawiInk, fontWeight: FontWeight.w700)),
        content: Text(
          'You will need to sign in again to access your account.',
          style: GoogleFonts.sourceSans3(
              color: PGColors.rawiInk3, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.sourceSans3(color: PGColors.rawiInk3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sign Out',
                style: GoogleFonts.sourceSans3(
                    color: const Color(0xFFD45B5B))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService().logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Delete Account screen
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
      await _auth.logout(); // clears tokens even if backend call fails
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to delete account. Please try again.')));
      }
    }
  }

  Future<bool?> _showConfirmSheet() {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: PGColors.rawiPaper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Delete Account?',
                  style: GoogleFonts.sourceSans3(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: PGColors.rawiInk)),
              const SizedBox(height: 12),
              Text(
                'This will permanently delete your account and anonymise your '
                'personal data. Your tours will remain but will no longer be '
                'linked to you. You can create a new account at any time.',
                style: GoogleFonts.sourceSans3(
                    fontSize: 14, color: PGColors.rawiInk3, height: 1.55),
              ),
              const SizedBox(height: 28),
              _SheetBtn(
                label: 'Cancel',
                bg: PGColors.rawiPaper2,
                textColor: PGColors.rawiInk,
                onTap: () => Navigator.pop(ctx, false),
              ),
              const SizedBox(height: 10),
              _SheetBtn(
                label: 'Delete Account',
                bg: const Color(0xFFD45B5B).withOpacity(0.12),
                textColor: const Color(0xFFD45B5B),
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
    const red = Color(0xFFD45B5B);
    return Scaffold(
      backgroundColor: PGColors.rawiPaper,
      body: SafeArea(
        child: Column(
          children: [
            _NavHeader(title: 'Delete Account'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ConsequenceBlock(
                      title: 'WHAT WILL BE DELETED',
                      isWarning: true,
                      items: [
                        'All active sessions and sign-in access',
                        'Your personal data (email & name) will be anonymised',
                      ],
                    ),
                    const SizedBox(height: 16),
                    _ConsequenceBlock(
                      title: 'WHAT WILL REMAIN',
                      isWarning: false,
                      items: [
                        'Your tour history (kept, but unlinked from your identity)',
                        'You can create a new account at any time',
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Confirmation checkbox
                    GestureDetector(
                      onTap: () => setState(() => _confirmed = !_confirmed),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _confirmed
                                ? CupertinoIcons.checkmark_square_fill
                                : CupertinoIcons.square,
                            size: 22,
                            color: _confirmed ? red : PGColors.rawiInk4,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'I understand this is permanent and cannot be undone.',
                              style: GoogleFonts.sourceSans3(
                                  fontSize: 14,
                                  color: PGColors.rawiInk3,
                                  height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: _deleting
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: red, strokeWidth: 2))
                          : ElevatedButton(
                              onPressed: _confirmed ? _handleDelete : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _confirmed
                                    ? red.withOpacity(0.1)
                                    : PGColors.rawiPaper2,
                                disabledBackgroundColor: PGColors.rawiPaper2,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: _confirmed
                                        ? red.withOpacity(0.4)
                                        : PGColors.rawiHair,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Delete My Account',
                                style: GoogleFonts.sourceSans3(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _confirmed ? red : PGColors.rawiInk4,
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
// Shared building-block widgets
// ---------------------------------------------------------------------------

/// Section with an optional LABEL and a card containing [rows].
class _Section extends StatelessWidget {
  const _Section({this.label, required this.rows});
  final String? label;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: GoogleFonts.sourceSans3(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: PGColors.rawiInk4,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Container(
            decoration: BoxDecoration(
              color: PGColors.rawiPaper2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: rows,
            ),
          ),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
        color: PGColors.rawiHair, height: 1, thickness: 1,
        indent: 52, endIndent: 0);
  }
}

/// Standard tappable row with icon, label, optional trailing widget, chevron.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    this.trailing,
    this.labelColor,
    this.showChevron = true,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Widget? trailing;
  final Color? labelColor;
  final bool showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: PGColors.rawiHairSoft,
        highlightColor: PGColors.rawiHairSoft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              _IconBubble(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.sourceSans3(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: labelColor ?? PGColors.rawiInk,
                  ),
                ),
              ),
              if (trailing != null) ...[trailing!, const SizedBox(width: 6)],
              if (showChevron)
                const Icon(CupertinoIcons.chevron_right,
                    size: 14, color: PGColors.rawiInk4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only row with a displayed value and a lock indicator.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          _IconBubble(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: GoogleFonts.sourceSans3(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: PGColors.rawiInk)),
          ),
          Text(value,
              style: GoogleFonts.sourceSans3(
                  fontSize: 15, color: PGColors.rawiInk4)),
          const SizedBox(width: 6),
          const Icon(CupertinoIcons.lock, size: 12, color: PGColors.rawiInk4),
        ],
      ),
    );
  }
}

/// Auto-play row — the one interactive preference, stored locally.
class _AutoPlayRow extends StatefulWidget {
  @override
  State<_AutoPlayRow> createState() => _AutoPlayRowState();
}

class _AutoPlayRowState extends State<_AutoPlayRow> {
  bool _autoPlay = true;
  static const _key = 'pref_autoplay_next_stop';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _autoPlay = prefs.getBool(_key) ?? true);
  }

  Future<void> _toggle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _autoPlay = !_autoPlay);
    await prefs.setBool(_key, _autoPlay);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _IconBubble(icon: CupertinoIcons.playpause),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Auto-play next stop',
                style: GoogleFonts.sourceSans3(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: PGColors.rawiInk)),
          ),
          CupertinoSwitch(
            value: _autoPlay,
            onChanged: (_) => _toggle(),
            activeColor: PGColors.rawiAccent,
          ),
        ],
      ),
    );
  }
}

/// Destructive red row (no card background, border only).
class _DestructiveRow extends StatelessWidget {
  const _DestructiveRow({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFD45B5B);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: red.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: red.withOpacity(0.7)),
              const SizedBox(width: 12),
              Text(label,
                  style: GoogleFonts.sourceSans3(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: red.withOpacity(0.85))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small rounded icon bubble.
class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: PGColors.rawiPaper3,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 16, color: PGColors.rawiInk2),
    );
  }
}

/// Back-button + title navigation header.
class _NavHeader extends StatelessWidget {
  const _NavHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 20, 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: const Icon(CupertinoIcons.chevron_back,
                color: PGColors.rawiInk, size: 28),
          ),
          const SizedBox(width: 2),
          Text(
            title,
            style: GoogleFonts.sourceSans3(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: PGColors.rawiInk,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered avatar circle with provider badge overlay.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, this.pictureUrl, required this.isApple});
  final String initials;
  final String? pictureUrl;
  final bool isApple;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main circle
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFC9A67A), Color(0xFF8A6040)],
            ),
          ),
          alignment: Alignment.center,
          child: pictureUrl != null && pictureUrl!.isNotEmpty
              ? ClipOval(
                  child: Image.network(pictureUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _initials()))
              : _initials(),
        ),
        // Provider badge — bottom-right
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: PGColors.rawiPaper, width: 2),
            ),
            alignment: Alignment.center,
            child: isApple
                ? const Text('',
                    style: TextStyle(fontSize: 11, color: Color(0xFF1B1915)))
                : Text('G',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4285F4),
                    )),
          ),
        ),
      ],
    );
  }

  Widget _initials() => Text(
        initials,
        style: GoogleFonts.sourceSans3(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
}

/// Consequence info block for the delete account screen.
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
    const red = Color(0xFFD45B5B);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.sourceSans3(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isWarning ? red.withOpacity(0.75) : PGColors.rawiInk4,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isWarning ? red.withOpacity(0.06) : PGColors.rawiPaper2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isWarning ? red.withOpacity(0.18) : PGColors.rawiHair,
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
                        size: 14,
                        color: isWarning
                            ? red.withOpacity(0.55)
                            : PGColors.rawiInk4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.value,
                        style: GoogleFonts.sourceSans3(
                          fontSize: 14,
                          color: isWarning
                              ? PGColors.rawiInk3
                              : PGColors.rawiInk4,
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

class _SheetBtn extends StatelessWidget {
  const _SheetBtn({
    required this.label,
    required this.bg,
    required this.textColor,
    required this.onTap,
  });
  final String label;
  final Color bg;
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
          backgroundColor: bg,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label,
            style: GoogleFonts.sourceSans3(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor)),
      ),
    );
  }
}
