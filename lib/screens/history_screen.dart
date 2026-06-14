import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pocket_guide_mobile/design_system/colors.dart';
import 'package:pocket_guide_mobile/services/auth_service.dart';
import 'package:pocket_guide_mobile/services/api_service.dart';
import 'package:pocket_guide_mobile/services/tour_session_service.dart';
import 'package:pocket_guide_mobile/screens/history_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _auth = AuthService();
  late final TourSessionService _sessions;

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sessions = TourSessionService(ApiService().dio);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _auth.getAccessToken();
      if (token == null) throw Exception('Not signed in');
      final items = await _sessions.getHistory(accessToken: token);
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: PGColors.rawiPaper,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HISTORY',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.18,
                      color: PGColors.rawiInk4,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your tours.',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.03 * 34,
                      color: PGColors.rawiInk,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Body ────────────────────────────────────────────────────
            Expanded(
              child: _buildBody(bottomPad),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(double bottomPad) {
    if (_loading) {
      return const Center(
        child: CupertinoActivityIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.exclamationmark_circle,
                  size: 48, color: PGColors.rawiInk4),
              const SizedBox(height: 16),
              Text(
                'Could not load history',
                style: GoogleFonts.sourceSans3(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: PGColors.rawiInk,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: GoogleFonts.sourceSans3(
                  fontSize: 13,
                  color: PGColors.rawiInk3,
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                color: PGColors.rawiAccent,
                borderRadius: BorderRadius.circular(99),
                onPressed: _load,
                child: Text(
                  'Try again',
                  style: GoogleFonts.sourceSans3(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: PGColors.rawiPaper,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Compass icon made from outline circles
              Icon(CupertinoIcons.map,
                  size: 56, color: PGColors.rawiInk4),
              const SizedBox(height: 20),
              Text(
                'No tours yet',
                style: GoogleFonts.sourceSans3(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: PGColors.rawiInk,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start a tour and your history will appear here.',
                style: GoogleFonts.sourceSans3(
                  fontSize: 14,
                  color: PGColors.rawiInk3,
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator.adaptive(
      onRefresh: _load,
      color: PGColors.rawiAccent,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPad + 100),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _HistoryCard(
          item: _items[i],
          onTap: () => Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => HistoryDetailScreen(
                sessionId: _items[i]['session_id'] as String,
                tourId: _items[i]['tour_id'] as String,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _HistoryCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = item['tour_title'] as String? ?? 'Tour';
    final city = item['city'] as String? ?? '';
    final status = item['status'] as String? ?? 'ended';
    final totalPois = (item['total_pois'] as num?)?.toInt() ?? 0;
    final poisCompleted = (item['pois_completed'] as num?)?.toInt() ?? 0;
    final durationDays = (item['duration_days'] as num?)?.toInt() ?? 1;
    final totalSec = (item['total_duration_seconds'] as num?)?.toInt();
    final startedAt = _parseDate(item['started_at'] as String?);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PGColors.rawiPaper2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PGColors.rawiHairSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge + date row
            Row(
              children: [
                _StatusBadge(status: status),
                const Spacer(),
                if (startedAt != null)
                  Text(
                    DateFormat('d MMM yyyy').format(startedAt),
                    style: GoogleFonts.sourceSans3(
                      fontSize: 12,
                      color: PGColors.rawiInk4,
                      decoration: TextDecoration.none,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              title,
              style: GoogleFonts.sourceSans3(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.16,
                height: 1.25,
                color: PGColors.rawiInk,
                decoration: TextDecoration.none,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // City · days
            Text(
              '$city · ${durationDays == 1 ? '1 day' : '$durationDays days'}',
              style: GoogleFonts.sourceSans3(
                fontSize: 13,
                color: PGColors.rawiInk3,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 12),

            // Progress bar + meta row
            if (totalPois > 0) ...[
              _PoiProgressBar(completed: poisCompleted, total: totalPois),
              const SizedBox(height: 8),
            ],

            Row(
              children: [
                Text(
                  '$poisCompleted of $totalPois stops',
                  style: GoogleFonts.sourceSans3(
                    fontSize: 12,
                    color: PGColors.rawiInk3,
                    decoration: TextDecoration.none,
                  ),
                ),
                if (totalSec != null && totalSec > 0) ...[
                  Text(
                    '  ·  ',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 12,
                      color: PGColors.rawiInk4,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  Text(
                    _formatDuration(totalSec),
                    style: GoogleFonts.sourceSans3(
                      fontSize: 12,
                      color: PGColors.rawiInk3,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
                const Spacer(),
                Icon(CupertinoIcons.chevron_right,
                    size: 14, color: PGColors.rawiInk4),
              ],
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _parseDate(String? s) {
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

// ── POI progress bar ──────────────────────────────────────────────────────────

class _PoiProgressBar extends StatelessWidget {
  final int completed;
  final int total;
  const _PoiProgressBar({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 3,
          decoration: BoxDecoration(
            color: PGColors.rawiPaper3,
            borderRadius: BorderRadius.circular(99),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction,
            child: Container(
              decoration: BoxDecoration(
                color: PGColors.rawiAccent,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'completed' => ('Completed', const Color(0xFFE8F5E9), PGColors.success),
      'in_progress' => ('In Progress', const Color(0xFFFFF8E1), const Color(0xFFEF6C00)),
      'abandoned' => ('Abandoned', PGColors.rawiPaper3, PGColors.rawiInk4),
      _ => ('Ended', PGColors.rawiPaper3, PGColors.rawiInk3),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'in_progress') ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: fg,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ] else if (status == 'completed') ...[
            Icon(CupertinoIcons.checkmark_alt, size: 10, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: GoogleFonts.sourceSans3(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
