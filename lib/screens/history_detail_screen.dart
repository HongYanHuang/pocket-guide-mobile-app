import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pocket_guide_mobile/design_system/colors.dart';
import 'package:pocket_guide_mobile/services/auth_service.dart';
import 'package:pocket_guide_mobile/services/api_service.dart';
import 'package:pocket_guide_mobile/services/tour_session_service.dart';
import 'package:pocket_guide_mobile/screens/tour_detail_screen.dart';

class HistoryDetailScreen extends StatefulWidget {
  final String sessionId;
  final String tourId;

  const HistoryDetailScreen({
    super.key,
    required this.sessionId,
    required this.tourId,
  });

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  final _auth = AuthService();
  late final TourSessionService _sessions;

  Map<String, dynamic>? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sessions = TourSessionService(ApiService().dio);
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = await _auth.getAccessToken();
      if (token == null) throw Exception('Not signed in');
      final detail = await _sessions.getHistoryDetail(
        sessionId: widget.sessionId,
        accessToken: token,
      );
      if (mounted) setState(() { _detail = detail; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PGColors.rawiPaper,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _error != null
                ? _buildError()
                : _buildContent(),
      ),
    );
  }

  Widget _buildError() {
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
              'Could not load session',
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
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Go back',
                style: GoogleFonts.sourceSans3(
                  fontSize: 15,
                  color: PGColors.rawiAccent,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final d = _detail!;
    final title = d['tour_title'] as String? ?? 'Tour';
    final city = d['city'] as String? ?? '';
    final status = d['status'] as String? ?? 'ended';
    final durationDays = (d['duration_days'] as num?)?.toInt() ?? 1;
    final totalPois = (d['total_pois'] as num?)?.toInt() ?? 0;
    final poisCompleted = (d['pois_completed'] as num?)?.toInt() ?? 0;
    final totalSec = (d['total_duration_seconds'] as num?)?.toInt();
    final startedAt = _parseDate(d['started_at'] as String?);
    final endedAt = _parseDate(d['ended_at'] as String?);
    final poiProgress = (d['poi_progress'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    final resume = d['resume'] as Map<String, dynamic>?;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            // ── Top bar ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    _BackButton(onTap: () => Navigator.pop(context)),
                    const Spacer(),
                    // Open tour button
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 0,
                      onPressed: () => Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) =>
                              TourDetailScreen(tourId: widget.tourId),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: PGColors.rawiPaper3,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          'Open Tour',
                          style: GoogleFonts.sourceSans3(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: PGColors.rawiInk2,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusBadge(status: status),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: GoogleFonts.sourceSans3(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.03 * 26,
                        height: 1.2,
                        color: PGColors.rawiInk,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$city · ${durationDays == 1 ? '1 day' : '$durationDays days'}',
                      style: GoogleFonts.sourceSans3(
                        fontSize: 14,
                        color: PGColors.rawiInk3,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Stats row ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    _StatTile(
                      icon: CupertinoIcons.flag_fill,
                      label: 'Stops',
                      value: '$poisCompleted / $totalPois',
                    ),
                    const SizedBox(width: 10),
                    if (totalSec != null && totalSec > 0)
                      _StatTile(
                        icon: CupertinoIcons.time,
                        label: 'Duration',
                        value: _formatDuration(totalSec),
                      ),
                    if (totalSec != null && totalSec > 0)
                      const SizedBox(width: 10),
                    if (startedAt != null)
                      _StatTile(
                        icon: CupertinoIcons.calendar,
                        label: 'Date',
                        value: DateFormat('d MMM').format(startedAt),
                      ),
                  ],
                ),
              ),
            ),

            // ── Timeline (started → ended) ───────────────────────────────
            if (startedAt != null || endedAt != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(
                    children: [
                      if (startedAt != null) ...[
                        _TimeLabel(
                            prefix: 'Started',
                            time: DateFormat('HH:mm').format(startedAt)),
                      ],
                      if (startedAt != null && endedAt != null) ...[
                        Expanded(
                          child: Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            color: PGColors.rawiHair,
                          ),
                        ),
                        _TimeLabel(
                            prefix: 'Ended',
                            time: DateFormat('HH:mm').format(endedAt)),
                      ],
                    ],
                  ),
                ),
              ),

            // ── Divider ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 1, color: PGColors.rawiHairSoft),
                    const SizedBox(height: 20),
                    Text(
                      'STOPS',
                      style: GoogleFonts.sourceSans3(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.18,
                        color: PGColors.rawiInk4,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── POI list ────────────────────────────────────────────────
            if (poiProgress.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Text(
                    'No stop data recorded.',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 14,
                      color: PGColors.rawiInk4,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _PoiProgressTile(
                    poi: poiProgress[i],
                    index: i,
                    isLast: i == poiProgress.length - 1,
                  ),
                  childCount: poiProgress.length,
                ),
              ),

            // bottom padding
            SliverPadding(
              padding: EdgeInsets.only(
                  bottom: (resume != null ? 100 : 0) + bottomPad + 32),
            ),
          ],
        ),

        // ── Resume / continue button ───────────────────────────────────
        if (resume != null)
          Positioned(
            left: 20,
            right: 20,
            bottom: bottomPad + 20,
            child: _ResumeButton(
              resume: resume,
              tourId: widget.tourId,
            ),
          ),
      ],
    );
  }

  DateTime? _parseDate(String? s) =>
      s == null ? null : DateTime.tryParse(s);

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 0,
      onPressed: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: PGColors.rawiPaper3,
          shape: BoxShape.circle,
        ),
        child: const Icon(CupertinoIcons.chevron_left,
            size: 17, color: PGColors.rawiInk),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: PGColors.rawiPaper2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PGColors.rawiHairSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: PGColors.rawiInk3),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.sourceSans3(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: PGColors.rawiInk,
                decoration: TextDecoration.none,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.sourceSans3(
                fontSize: 11,
                color: PGColors.rawiInk4,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeLabel extends StatelessWidget {
  final String prefix;
  final String time;
  const _TimeLabel({required this.prefix, required this.time});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prefix,
          style: GoogleFonts.sourceSans3(
            fontSize: 11,
            color: PGColors.rawiInk4,
            decoration: TextDecoration.none,
          ),
        ),
        Text(
          time,
          style: GoogleFonts.sourceSans3(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: PGColors.rawiInk2,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}

class _PoiProgressTile extends StatefulWidget {
  final Map<String, dynamic> poi;
  final int index;
  final bool isLast;
  const _PoiProgressTile(
      {required this.poi, required this.index, required this.isLast});

  @override
  State<_PoiProgressTile> createState() => _PoiProgressTileState();
}

class _PoiProgressTileState extends State<_PoiProgressTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final poi = widget.poi;
    final name = poi['poi_name'] as String? ?? 'Stop ${widget.index + 1}';
    final visited = poi['visited'] as bool? ?? false;
    final allDone = poi['all_sections_completed'] as bool? ?? false;
    final sections = (poi['sections'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final visitedAt = _parseDate(poi['visited_at'] as String?);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Row: dot/check + name + chevron
          GestureDetector(
            onTap: sections.isNotEmpty
                ? () => setState(() => _expanded = !_expanded)
                : null,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                // Step indicator
                SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: allDone
                              ? PGColors.rawiAccent
                              : visited
                                  ? PGColors.rawiPaper3
                                  : PGColors.rawiPaper2,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: allDone
                                ? PGColors.rawiAccent
                                : PGColors.rawiHair,
                          ),
                        ),
                        child: Center(
                          child: allDone
                              ? const Icon(CupertinoIcons.checkmark_alt,
                                  size: 12, color: PGColors.rawiPaper)
                              : Text(
                                  '${widget.index + 1}',
                                  style: GoogleFonts.sourceSans3(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: visited
                                        ? PGColors.rawiInk3
                                        : PGColors.rawiInk4,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                        ),
                      ),
                      if (!widget.isLast)
                        Container(
                          width: 1,
                          height: 12,
                          margin: const EdgeInsets.only(top: 4),
                          color: PGColors.rawiHairSoft,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.sourceSans3(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: visited ? PGColors.rawiInk : PGColors.rawiInk3,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      if (visited && visitedAt != null)
                        Text(
                          'Visited ${DateFormat('HH:mm').format(visitedAt)}',
                          style: GoogleFonts.sourceSans3(
                            fontSize: 11,
                            color: PGColors.rawiInk4,
                            decoration: TextDecoration.none,
                          ),
                        )
                      else if (!visited)
                        Text(
                          'Not visited',
                          style: GoogleFonts.sourceSans3(
                            fontSize: 11,
                            color: PGColors.rawiInk4,
                            decoration: TextDecoration.none,
                          ),
                        ),
                    ],
                  ),
                ),
                if (sections.isNotEmpty)
                  Icon(
                    _expanded
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: 13,
                    color: PGColors.rawiInk4,
                  ),
              ],
            ),
          ),

          // Section breakdown
          if (_expanded && sections.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Column(
                children: sections.map((s) => _SectionRow(section: s)).toList(),
              ),
            ),
          ],

          if (!widget.isLast) const SizedBox(height: 0),
        ],
      ),
    );
  }

  DateTime? _parseDate(String? s) =>
      s == null ? null : DateTime.tryParse(s);
}

class _SectionRow extends StatelessWidget {
  final Map<String, dynamic> section;
  const _SectionRow({required this.section});

  @override
  Widget build(BuildContext context) {
    final idx = (section['section_index'] as num?)?.toInt() ?? 0;
    final completed = section['completed'] as bool? ?? false;
    final played = section['played'] as bool? ?? false;
    final positionSec = (section['position_seconds'] as num?)?.toDouble() ?? 0;
    final totalSec = (section['total_seconds'] as num?)?.toDouble() ?? 0;
    final progress = totalSec > 0 ? (positionSec / totalSec).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            completed
                ? CupertinoIcons.checkmark_circle_fill
                : played
                    ? CupertinoIcons.circle_lefthalf_fill
                    : CupertinoIcons.circle,
            size: 14,
            color: completed
                ? PGColors.rawiAccent
                : played
                    ? PGColors.rawiInk3
                    : PGColors.rawiInk4,
          ),
          const SizedBox(width: 8),
          Text(
            'Section ${idx + 1}',
            style: GoogleFonts.sourceSans3(
              fontSize: 12,
              color: played ? PGColors.rawiInk3 : PGColors.rawiInk4,
              decoration: TextDecoration.none,
            ),
          ),
          if (played && totalSec > 0) ...[
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: PGColors.rawiPaper3,
                  valueColor:
                      const AlwaysStoppedAnimation(PGColors.rawiAccent),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _fmt(positionSec.toInt()),
              style: GoogleFonts.sourceSans3(
                fontSize: 11,
                color: PGColors.rawiInk4,
                decoration: TextDecoration.none,
              ),
            ),
          ] else
            const Spacer(),
        ],
      ),
    );
  }

  String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _ResumeButton extends StatelessWidget {
  final Map<String, dynamic> resume;
  final String tourId;
  const _ResumeButton({required this.resume, required this.tourId});

  @override
  Widget build(BuildContext context) {
    final poiName = resume['poi_name'] as String? ?? 'last stop';

    return GestureDetector(
      onTap: () {
        // Navigate to TourDetailScreen which will let user restart.
        // The resume field is context for where audio should seek to —
        // full resume-in-place requires the MapTourScreen + audio seek
        // integration which will be wired up when that feature ships.
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => TourDetailScreen(tourId: tourId),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: PGColors.rawiAccent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x30000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.play_circle_fill,
                size: 22, color: PGColors.rawiPaper),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Continue tour',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: PGColors.rawiPaper,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  Text(
                    'Last at $poiName',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 12,
                      color: PGColors.rawiPaper.withOpacity(0.7),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right,
                size: 14, color: PGColors.rawiPaper),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'completed' => ('Completed', const Color(0xFFE8F5E9), PGColors.success),
      'in_progress' =>
        ('In Progress', const Color(0xFFFFF8E1), const Color(0xFFEF6C00)),
      'abandoned' => ('Abandoned', PGColors.rawiPaper3, PGColors.rawiInk4),
      _ => ('Ended', PGColors.rawiPaper3, PGColors.rawiInk3),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: GoogleFonts.sourceSans3(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
