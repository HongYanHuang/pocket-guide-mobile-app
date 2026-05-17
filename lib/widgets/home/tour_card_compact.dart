import 'package:flutter/cupertino.dart';
import 'package:pocket_guide_api/pocket_guide_api.dart';
import 'package:pocket_guide_mobile/design_system/colors.dart';
import 'package:pocket_guide_mobile/design_system/spacing.dart';
import 'package:pocket_guide_mobile/design_system/typography.dart';
import 'star_rating.dart';

// Same gradient palette as the large card for consistency.
const _kGradients = [
  [Color(0xFFC9A67A), Color(0xFF6E5733)],
  [Color(0xFF8C9A86), Color(0xFF2F3E33)],
  [Color(0xFFD9A27A), Color(0xFF7A3E2A)],
  [Color(0xFFE0A764), Color(0xFF693718)],
  [Color(0xFF7A8C9A), Color(0xFF2A3E4A)],
];

class TourCardCompact extends StatelessWidget {
  final TourSummary tour;
  final VoidCallback onTap;

  const TourCardCompact({super.key, required this.tour, required this.onTap});

  List<Color> _gradient() {
    return _kGradients[tour.tourId.hashCode.abs() % _kGradients.length];
  }

  String _formatHours(num h) {
    final d = h.toDouble();
    if (d == d.floorToDouble()) return '${d.toInt()} hr';
    return '${d.toStringAsFixed(1)} hr';
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _gradient();
    final stops = tour.totalStops ?? tour.totalPois;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 200,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(PGRadius.rawiChip + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover
              AspectRatio(
                aspectRatio: 3 / 2,
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
                    // Duration overlay pill at bottom-left
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: PGColors.rawiInk.withOpacity(0.55),
                          borderRadius:
                              BorderRadius.circular(PGRadius.pill),
                        ),
                        child: Text(
                          tour.walkingHours != null
                              ? '${_formatHours(tour.walkingHours!)} · $stops stops'
                              : '$stops stops',
                          style: const TextStyle(
                            fontSize: 11,
                            color: PGColors.rawiPaper,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Info
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(4, 10, 4, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tour.titleDisplay ?? tour.tourId,
                      style: RawiTypography.cardTitleSmall(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (tour.rating != null) ...[
                          StarRating(rating: tour.rating!.toDouble()),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            tour.city,
                            style: RawiTypography.meta(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
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
