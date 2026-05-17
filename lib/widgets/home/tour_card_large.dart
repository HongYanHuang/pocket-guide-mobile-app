import 'package:flutter/cupertino.dart';
import 'package:pocket_guide_api/pocket_guide_api.dart';
import 'package:pocket_guide_mobile/design_system/colors.dart';
import 'package:pocket_guide_mobile/design_system/spacing.dart';
import 'package:pocket_guide_mobile/design_system/typography.dart';
import 'star_rating.dart';

// Deterministic warm gradients — picked by tourId hash so each tour
// gets a consistent colour without needing a cover image from the API.
const _kGradients = [
  [Color(0xFFC9A67A), Color(0xFF6E5733)],
  [Color(0xFF8C9A86), Color(0xFF2F3E33)],
  [Color(0xFFD9A27A), Color(0xFF7A3E2A)],
  [Color(0xFFE0A764), Color(0xFF693718)],
  [Color(0xFF7A8C9A), Color(0xFF2A3E4A)],
];

class TourCardLarge extends StatelessWidget {
  final TourSummary tour;
  final VoidCallback onTap;

  const TourCardLarge({super.key, required this.tour, required this.onTap});

  List<Color> _gradient() {
    return _kGradients[tour.tourId.hashCode.abs() % _kGradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _gradient();
    final isPersonalized = tour.isPersonalized == true;
    final stops = tour.totalStops ?? tour.totalPois;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PGRadius.rawiCard),
        child: ColoredBox(
          color: PGColors.rawiPaper,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cover (gradient placeholder) ───────────────────────
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: gradient,
                          ),
                        ),
                      ),
                    ),
                    // Tag / personalized pill
                    Positioned(
                      top: 14,
                      left: 14,
                      child: _TagPill(
                        label: isPersonalized
                            ? 'Personalized'
                            : (tour.category ?? 'Tour'),
                        isPersonalized: isPersonalized,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Info ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      tour.titleDisplay ?? tour.tourId,
                      style: RawiTypography.cardTitle(),
                    ),
                    const SizedBox(height: 2),
                    // City
                    Text(tour.city, style: RawiTypography.place()),
                    const SizedBox(height: 8),
                    // Meta row
                    _MetaRow(tour: tour, stops: stops),
                    // Narrator pill
                    if (tour.narratorName != null) ...[
                      const SizedBox(height: 12),
                      _NarratorPill(name: tour.narratorName!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tag pill on photo ────────────────────────────────────────────────────────

class _TagPill extends StatelessWidget {
  final String label;
  final bool isPersonalized;

  const _TagPill({required this.label, required this.isPersonalized});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isPersonalized
            ? PGColors.rawiAccent
            : CupertinoColors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(PGRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color:
                  isPersonalized ? PGColors.rawiPaper : PGColors.rawiInk,
            ),
          ),
          if (isPersonalized) ...[
            const SizedBox(width: 4),
            const Text('🔓', style: TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

// ── Meta row (rating · duration · stops) ────────────────────────────────────

class _MetaRow extends StatelessWidget {
  final TourSummary tour;
  final int stops;

  const _MetaRow({required this.tour, required this.stops});

  String _formatHours(num h) {
    final d = h.toDouble();
    if (d == d.floorToDouble()) return '${d.toInt()} hr';
    return '${d.toStringAsFixed(1)} hr';
  }

  Widget _dot() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Text('·',
            style: RawiTypography.meta(color: PGColors.rawiInk4)),
      );

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      children: [
        if (tour.rating != null) ...[
          StarRating(rating: tour.rating!.toDouble()),
          if (tour.reviewCount != null) ...[
            const SizedBox(width: 5),
            Text('(${tour.reviewCount})',
                style: RawiTypography.meta()),
          ],
          _dot(),
        ],
        if (tour.walkingHours != null) ...[
          Text(_formatHours(tour.walkingHours!),
              style: RawiTypography.meta()),
          _dot(),
        ],
        Text('$stops stops', style: RawiTypography.meta()),
      ],
    );
  }
}

// ── Narrator pill ────────────────────────────────────────────────────────────

class _NarratorPill extends StatelessWidget {
  final String name;

  const _NarratorPill({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: PGColors.rawiPaper2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Avatar circle
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PGColors.rawiAccent.withOpacity(0.3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Narrated by', style: RawiTypography.narratorLabel()),
                Text(name, style: RawiTypography.narratorName()),
              ],
            ),
          ),
          // Play button
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: PGColors.rawiAccent,
            ),
            child: const Icon(CupertinoIcons.play_fill,
                size: 10, color: PGColors.rawiPaper),
          ),
        ],
      ),
    );
  }
}
