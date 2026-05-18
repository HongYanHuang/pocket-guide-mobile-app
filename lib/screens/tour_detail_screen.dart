import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, MaterialPageRoute;
import 'package:pocket_guide_api/pocket_guide_api.dart';
import 'package:pocket_guide_mobile/design_system/colors.dart';
import 'package:pocket_guide_mobile/design_system/spacing.dart';
import 'package:pocket_guide_mobile/design_system/typography.dart';
import 'package:pocket_guide_mobile/services/api_service.dart';
import 'package:pocket_guide_mobile/screens/map_tour_screen.dart';

// Warm gradient fallbacks keyed by index — used when no cover image is provided.
const _kHeroGradients = [
  [Color(0xFFC9A67A), Color(0xFF6E5733)],
  [Color(0xFF8C9A86), Color(0xFF2F3E33)],
  [Color(0xFFD9A27A), Color(0xFF7A3E2A)],
  [Color(0xFFE0A764), Color(0xFF693718)],
  [Color(0xFF7A8C9A), Color(0xFF2A3E4A)],
];

const _kStopGradients = [
  [Color(0xFFC9A67A), Color(0xFF8B6437)],
  [Color(0xFFB89770), Color(0xFF6E5733)],
  [Color(0xFF9A7A4F), Color(0xFF4A3015)],
  [Color(0xFFC0A07A), Color(0xFF604222)],
  [Color(0xFFA88353), Color(0xFF523818)],
  [Color(0xFFD2A877), Color(0xFF6F4A23)],
];

class TourDetailScreen extends StatefulWidget {
  final String tourId;

  const TourDetailScreen({super.key, required this.tourId});

  @override
  State<TourDetailScreen> createState() => _TourDetailScreenState();
}

class _TourDetailScreenState extends State<TourDetailScreen> {
  final _api = ApiService();
  final _scrollController = ScrollController();

  TourDetail? _detail;
  List<TourReview> _reviews = [];
  bool _loading = true;
  String? _error;
  int _openStopIndex = 0;
  double _scrollOffset = 0;

  List<TourPOI> get _allStops =>
      _detail?.itinerary.expand((day) => day.pois).toList() ?? [];

  TourMetadata? get _meta => _detail?.metadata;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    if ((offset > 280) != (_scrollOffset > 280)) {
      setState(() => _scrollOffset = offset);
    } else {
      _scrollOffset = offset;
    }
  }

  Future<void> _loadData() async {
    try {
      final detail = await _api.getTourById(widget.tourId);
      final reviews = await _api.getReviews(widget.tourId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _reviews = reviews;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────

  List<Color> _heroGradient() {
    final idx = widget.tourId.hashCode.abs() % _kHeroGradients.length;
    return _kHeroGradients[idx];
  }

  List<Color> _stopGradient(int index) =>
      _kStopGradients[index % _kStopGradients.length];

  String _formatDuration(num? hours) {
    if (hours == null) return '—';
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  String _formatDistance(num? km) {
    if (km == null) return '—';
    return '${km.toStringAsFixed(1)} km';
  }

  String _formatAvgTime(num hours) {
    final minutes = (hours * 60).round();
    return '~$minutes min';
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ];
      return '${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  Color _avatarColor(String name) {
    const palette = [
      Color(0xFF8C6D4F), Color(0xFF5B6E5A), Color(0xFF6B5B7A),
      Color(0xFF4A6B7A), Color(0xFF7A5B4A),
    ];
    return palette[name.hashCode.abs() % palette.length];
  }

  void _onStartTour() {
    if (_detail == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MapTourScreen(tourDetail: _detail!, isActiveMode: false),
    ));
  }

  // ── Scaffold ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return CupertinoPageScaffold(
        backgroundColor: PGColors.rawiPaper,
        child: const Center(child: CupertinoActivityIndicator()),
      );
    }
    if (_error != null) {
      return CupertinoPageScaffold(
        backgroundColor: PGColors.rawiPaper,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Icon(CupertinoIcons.back, color: PGColors.rawiInk),
                ),
              ),
              const Spacer(),
              Text('Failed to load tour', style: RawiTypography.cardTitle()),
              const Spacer(),
            ],
          ),
        ),
      );
    }

    final statusBarH = MediaQuery.of(context).padding.top;
    final bottomPadH = MediaQuery.of(context).padding.bottom;
    final headerVisible = _scrollOffset > 280;

    return CupertinoPageScaffold(
      backgroundColor: PGColors.rawiPaper,
      child: Stack(
        children: [
          // ── Scrollable body ────────────────────────────────────
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHero(statusBarH),
                _buildSheet(),
                SizedBox(height: 100 + bottomPadH),
              ],
            ),
          ),
          // ── Sticky nav ─────────────────────────────────────────
          _buildNavBar(statusBarH, headerVisible),
          // ── Sticky CTA ─────────────────────────────────────────
          _buildCTA(bottomPadH),
        ],
      ),
    );
  }

  // ── Hero ───────────────────────────────────────────────────────────

  Widget _buildHero(double statusBarH) {
    final meta = _meta;
    final gradient = _heroGradient();
    final coverUrl = meta?.coverImageUrl;
    final title = meta?.titleDisplay ?? widget.tourId;
    final city = meta?.city ?? '';
    final category = _detail?.itinerary.isNotEmpty == true ? null : null;
    // Build the tag pill text: category · city or just city
    final tagText = category ?? city;

    return SizedBox(
      height: 360,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cover image or warm gradient
          if (coverUrl != null && coverUrl.isNotEmpty)
            Image.network(
              '${ApiService.baseUrl}$coverUrl',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildGradientBox(gradient),
            )
          else
            _buildGradientBox(gradient),

          // Gradient overlay: subtle at top, strong at bottom
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.4, 1.0],
                colors: [
                  const Color(0xFF1B1915).withOpacity(0.18),
                  Colors.transparent,
                  const Color(0xFF1B1915).withOpacity(0.78),
                ],
              ),
            ),
          ),

          // Bottom: tag pill + title
          Positioned(
            left: 20, right: 20, bottom: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tag pill
                if (tagText.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(PGRadius.pill),
                      border: Border.all(color: Colors.white.withOpacity(0.25), width: 0.5),
                    ),
                    child: Text(
                      tagText,
                      style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: Color(0xFFF6F1E7),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w700,
                    letterSpacing: -0.02 * 32, height: 1.05,
                    color: Color(0xFFF6F1E7),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientBox(List<Color> colors) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
    );
  }

  // ── Paper sheet ────────────────────────────────────────────────────

  Widget _buildSheet() {
    final meta = _meta;
    final stops = _allStops;

    return Container(
      margin: const EdgeInsets.only(top: -20),
      decoration: const BoxDecoration(
        color: PGColors.rawiPaper,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatsStrip(stops.length),
          _divider(),
          if (meta?.rating != null) ...[
            _buildRatingRow(),
            _divider(),
          ],
          if (meta?.blurb != null && meta!.blurb!.isNotEmpty) ...[
            _buildAbout(meta.blurb!),
            _divider(),
          ],
          _buildStopsSection(stops),
          _divider(),
          _buildReviewsSection(),
          if (meta?.narratorName != null) ...[
            _divider(),
            _buildNarrator(),
          ],
        ],
      ),
    );
  }

  // ── Stats strip ────────────────────────────────────────────────────

  Widget _buildStatsStrip(int stopCount) {
    final items = [
      ['DURATION', _formatDuration(_detail?.totalDurationHours)],
      ['DISTANCE', _formatDistance(_detail?.totalWalkingKm)],
      ['STOPS', '$stopCount'],
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(width: 0.5, height: 36, color: PGColors.rawiHair),
            Expanded(
              child: Column(
                children: [
                  Text(
                    items[i][1],
                    style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700,
                      color: PGColors.rawiInk, letterSpacing: -0.01 * 20,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    items[i][0],
                    style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: PGColors.rawiInk3, letterSpacing: 0.1 * 10,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Rating ─────────────────────────────────────────────────────────

  Widget _buildRatingRow() {
    final rating = _meta?.rating!;
    final count = _meta?.reviewCount ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          const Icon(CupertinoIcons.star_fill, size: 14, color: PGColors.rawiAccent),
          const SizedBox(width: 6),
          Text(
            rating!.toStringAsFixed(2),
            style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700,
              color: PGColors.rawiInk, decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(width: 6),
          Text('·', style: const TextStyle(color: PGColors.rawiInk3, decoration: TextDecoration.none)),
          const SizedBox(width: 6),
          Text(
            '$count reviews',
            style: const TextStyle(fontSize: 14, color: PGColors.rawiInk3, decoration: TextDecoration.none),
          ),
        ],
      ),
    );
  }

  // ── About ──────────────────────────────────────────────────────────

  Widget _buildAbout(String blurb) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About', style: RawiTypography.cardTitle()),
          const SizedBox(height: 10),
          Text(
            blurb,
            style: const TextStyle(
              fontSize: 15, height: 1.6, color: PGColors.rawiInk2,
              letterSpacing: -0.01 * 15,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  // ── Stops ──────────────────────────────────────────────────────────

  Widget _buildStopsSection(List<TourPOI> stops) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Stops', style: RawiTypography.cardTitle()),
              const Spacer(),
              Text(
                '${stops.length} along the route',
                style: const TextStyle(fontSize: 12, color: PGColors.rawiInk3, decoration: TextDecoration.none),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < stops.length; i++) ...[
            _buildStopCard(stops[i], i),
            if (i < stops.length - 1) _buildStopArrow(),
          ],
        ],
      ),
    );
  }

  Widget _buildStopCard(TourPOI stop, int index) {
    final isOpen = _openStopIndex == index;
    final gradient = _stopGradient(index);
    final num = (index + 1).toString().padLeft(2, '0');
    final chapterCount = stop.sectionCount ?? 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: PGColors.rawiPaper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PGColors.rawiHair, width: 0.5),
        boxShadow: isOpen
            ? [BoxShadow(color: PGColors.rawiInk.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))]
            : [],
      ),
      child: Column(
        children: [
          // Tap target: header row
          GestureDetector(
            onTap: () => setState(() => _openStopIndex = isOpen ? -1 : index),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 72 × 72 stop photo
                  _buildStopPhoto(stop, gradient, num),
                  const SizedBox(width: 12),
                  // Name + blurb + meta
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stop.poi,
                            style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600,
                              color: PGColors.rawiInk, letterSpacing: -0.01 * 15,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          if (stop.blurb != null && stop.blurb!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              stop.blurb!,
                              maxLines: isOpen ? null : 1,
                              overflow: isOpen ? TextOverflow.visible : TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12, color: PGColors.rawiInk3,
                                height: 1.4, fontStyle: FontStyle.italic,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          // Meta row: time · chapters
                          Row(
                            children: [
                              const Icon(CupertinoIcons.clock, size: 10, color: PGColors.rawiInk3),
                              const SizedBox(width: 4),
                              Text(
                                '${_formatAvgTime(stop.estimatedHours)} here',
                                style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600,
                                  color: PGColors.rawiInk3, decoration: TextDecoration.none,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text('·', style: TextStyle(fontSize: 11, color: PGColors.rawiInk3.withOpacity(0.4), decoration: TextDecoration.none)),
                              ),
                              Text(
                                '$chapterCount ${chapterCount == 1 ? "chapter" : "chapters"}',
                                style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600,
                                  color: PGColors.rawiInk3, decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Chevron
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 6),
                    child: AnimatedRotation(
                      turns: isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: const Icon(CupertinoIcons.chevron_down, size: 12, color: PGColors.rawiInk3),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expanded: chapter list
          if (isOpen && chapterCount > 0) _buildChapterList(chapterCount, index == 0),
        ],
      ),
    );
  }

  Widget _buildStopPhoto(TourPOI stop, List<Color> gradient, String num) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 72, height: 72,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient fallback
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
              ),
            ),
            // Photo overlay
            if (stop.coverImageUrl != null && stop.coverImageUrl!.isNotEmpty)
              Image.network(
                '${ApiService.baseUrl}${stop.coverImageUrl}',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            // Number badge
            Positioned(
              top: 6, left: 6,
              child: Container(
                constraints: const BoxConstraints(minWidth: 22),
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1915).withOpacity(0.78),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  num,
                  style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: Color(0xFFF6F1E7),
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterList(int count, bool isFirstStop) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: PGColors.rawiHair, width: 0.5)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          for (int j = 0; j < count; j++)
            Padding(
              padding: EdgeInsets.only(bottom: j < count - 1 ? 7 : 0),
              child: _buildChapterRow(j, isFirstStop && j == 0),
            ),
        ],
      ),
    );
  }

  Widget _buildChapterRow(int index, bool isFirstActive) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: PGColors.rawiPaper2,
        border: Border.all(color: PGColors.rawiHair, width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Play button
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFirstActive ? PGColors.rawiAccent : PGColors.rawiInk,
              boxShadow: [BoxShadow(color: PGColors.rawiInk.withOpacity(0.10), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: const Center(
              child: Icon(CupertinoIcons.play_fill, size: 10, color: Color(0xFFF6F1E7)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Chapter ${index + 1}',
              style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: PGColors.rawiInk, decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopArrow() {
    return SizedBox(
      height: 18,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Icon(CupertinoIcons.arrow_down, size: 11, color: PGColors.rawiInk4),
        ),
      ),
    );
  }

  // ── Reviews ────────────────────────────────────────────────────────

  Widget _buildReviewsSection() {
    final rating = _meta?.rating;
    final count = _meta?.reviewCount ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(CupertinoIcons.star_fill, size: 13, color: PGColors.rawiAccent),
              const SizedBox(width: 6),
              Text(
                rating != null
                    ? '${rating.toStringAsFixed(2)} · $count reviews'
                    : '$count reviews',
                style: RawiTypography.cardTitle(),
              ),
              const Spacer(),
              if (_reviews.isNotEmpty)
                Text(
                  'See all ›',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: PGColors.rawiAccent, decoration: TextDecoration.none,
                  ),
                ),
            ],
          ),
          if (_reviews.isEmpty) ...[
            const SizedBox(height: 14),
            Text('No reviews yet.', style: RawiTypography.meta()),
          ] else ...[
            for (int i = 0; i < _reviews.length.clamp(0, 3); i++)
              _buildReviewCard(_reviews[i], i),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewCard(TourReview review, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: index > 0
          ? const BoxDecoration(border: Border(top: BorderSide(color: PGColors.rawiHair, width: 0.5)))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar: image or colored initial circle
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _avatarColor(review.reviewerName),
                ),
                child: review.reviewerAvatarUrl != null && review.reviewerAvatarUrl!.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          '${ApiService.baseUrl}${review.reviewerAvatarUrl}',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildInitial(review.reviewerName),
                        ),
                      )
                    : _buildInitial(review.reviewerName),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.reviewerName,
                      style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: PGColors.rawiInk, letterSpacing: -0.01 * 14,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    Text(
                      _formatDate(review.createdAt),
                      style: const TextStyle(fontSize: 12, color: PGColors.rawiInk3, decoration: TextDecoration.none),
                    ),
                  ],
                ),
              ),
              // Star rating
              Row(
                children: List.generate(5, (j) => Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Icon(
                    CupertinoIcons.star_fill, size: 10,
                    color: j < review.rating ? PGColors.rawiAccent : PGColors.rawiHair,
                  ),
                )),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.text,
            style: const TextStyle(
              fontSize: 14, height: 1.55, color: PGColors.rawiInk2,
              fontStyle: FontStyle.italic, decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitial(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: Color(0xFFF6F1E7), decoration: TextDecoration.none,
        ),
      ),
    );
  }

  // ── Narrator footer ────────────────────────────────────────────────

  Widget _buildNarrator() {
    final name = _meta?.narratorName;
    final avatarUrl = _meta?.narratorAvatarUrl;
    if (name == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PGColors.rawiPaper2,
              border: Border.all(color: PGColors.rawiHair, width: 0.5),
            ),
            child: avatarUrl != null && avatarUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      '${ApiService.baseUrl}$avatarUrl',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildInitial(name),
                    ),
                  )
                : _buildInitial(name),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NARRATED BY',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: PGColors.rawiInk3, letterSpacing: 0.1 * 11,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: PGColors.rawiInk2, letterSpacing: -0.01 * 14,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Nav bar ────────────────────────────────────────────────────────

  Widget _buildNavBar(double statusBarH, bool headerVisible) {
    final title = _meta?.titleDisplay ?? widget.tourId;
    return Positioned(
      top: 0, left: 0, right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: headerVisible
              ? ImageFilter.blur(sigmaX: 18, sigmaY: 18)
              : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            color: headerVisible
                ? PGColors.rawiPaper.withOpacity(0.88)
                : Colors.transparent,
            child: Column(
              children: [
                SizedBox(height: statusBarH),
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      // Back button
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: headerVisible
                                ? PGColors.rawiPaper2
                                : const Color(0xFF1B1915).withOpacity(0.38),
                          ),
                          child: Icon(
                            CupertinoIcons.back,
                            size: 18,
                            color: headerVisible ? PGColors.rawiInk : const Color(0xFFF6F1E7),
                          ),
                        ),
                      ),
                      // Title (fades in on scroll)
                      Expanded(
                        child: AnimatedOpacity(
                          opacity: headerVisible ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600,
                              color: PGColors.rawiInk, letterSpacing: -0.01 * 15,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                      // Right spacer (symmetry)
                      const SizedBox(width: 64),
                    ],
                  ),
                ),
                if (headerVisible)
                  Container(height: 0.5, color: PGColors.rawiHair),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── CTA bar ────────────────────────────────────────────────────────

  Widget _buildCTA(double bottomPadH) {
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPadH),
            decoration: const BoxDecoration(
              color: Color(0xEDF6F1E7), // ~93% opacity paper
              border: Border(top: BorderSide(color: PGColors.rawiHair, width: 0.5)),
            ),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _onStartTour,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: PGColors.rawiAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.play_fill, size: 13, color: Color(0xFFF6F1E7)),
                    SizedBox(width: 10),
                    Text(
                      'Start tour',
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600,
                        color: Color(0xFFF6F1E7),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Shared ─────────────────────────────────────────────────────────

  Widget _divider() => Container(height: 0.5, color: PGColors.rawiHair);
}
