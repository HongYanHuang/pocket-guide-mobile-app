import 'package:flutter/cupertino.dart';
import 'package:pocket_guide_api/pocket_guide_api.dart';
import 'package:pocket_guide_mobile/design_system/colors.dart';
import 'package:pocket_guide_mobile/design_system/spacing.dart';
import 'package:pocket_guide_mobile/design_system/typography.dart';
import 'package:pocket_guide_mobile/services/api_service.dart';

const _kGradients = [
  [Color(0xFFC9A67A), Color(0xFF6E5733)],
  [Color(0xFF8C9A86), Color(0xFF2F3E33)],
  [Color(0xFFD9A27A), Color(0xFF7A3E2A)],
  [Color(0xFFE0A764), Color(0xFF693718)],
  [Color(0xFF7A8C9A), Color(0xFF2A3E4A)],
];

class ContinueWalkingBanner extends StatelessWidget {
  final TourSummary tour;
  final int currentDay;
  final VoidCallback onTap;

  const ContinueWalkingBanner({
    super.key,
    required this.tour,
    required this.currentDay,
    required this.onTap,
  });

  List<Color> _gradient() {
    return _kGradients[tour.tourId.hashCode.abs() % _kGradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _gradient();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Continue walking', style: RawiTypography.sectionTitle()),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PGColors.rawiPaper,
                borderRadius: BorderRadius.circular(PGRadius.rawiCard - 2),
                border: Border.all(color: PGColors.rawiHair, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: PGColors.rawiInk.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: gradient,
                              ),
                            ),
                          ),
                          if (tour.coverImageUrl != null &&
                              tour.coverImageUrl!.isNotEmpty)
                            Image.network(
                              '${ApiService.baseUrl}${tour.coverImageUrl}',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tour.titleDisplay ?? tour.tourId,
                          style: RawiTypography.cardTitleSmall(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Day $currentDay of ${tour.durationDays} · ${tour.city}',
                          style: RawiTypography.meta(),
                        ),
                        const SizedBox(height: 8),
                        // Progress bar (visual only — based on day progress)
                        _ProgressBar(
                            value: currentDay / tour.durationDays.clamp(1, 99)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Play button
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: PGColors.rawiAccent,
                    ),
                    child: const Icon(CupertinoIcons.play_fill,
                        size: 12, color: PGColors.rawiPaper),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value; // 0.0 – 1.0

  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        color: PGColors.rawiHair,
        borderRadius: BorderRadius.circular(PGRadius.pill),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: PGColors.rawiAccent,
            borderRadius: BorderRadius.circular(PGRadius.pill),
          ),
        ),
      ),
    );
  }
}
