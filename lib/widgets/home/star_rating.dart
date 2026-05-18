import 'package:flutter/cupertino.dart';
import 'package:pocket_guide_mobile/design_system/colors.dart';
import 'package:pocket_guide_mobile/design_system/typography.dart';

class StarRating extends StatelessWidget {
  final double rating;

  const StarRating({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(CupertinoIcons.star_fill, size: 11, color: PGColors.rawiAccent),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(2),
          style: RawiTypography.ratingValue(),
        ),
      ],
    );
  }
}
