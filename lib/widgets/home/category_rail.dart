import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:pocket_guide_mobile/design_system/colors.dart';
import 'package:pocket_guide_mobile/design_system/spacing.dart';
import 'package:pocket_guide_mobile/design_system/typography.dart';

class CategoryRail extends StatelessWidget {
  final List<String> categories;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  const CategoryRail({
    super.key,
    required this.categories,
    required this.activeIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final active = i == activeIndex;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: active ? PGColors.rawiInk : Colors.transparent,
                borderRadius: BorderRadius.circular(PGRadius.pill),
                border: Border.all(
                  color: active
                      ? Colors.transparent
                      : PGColors.rawiHair,
                  width: 0.5,
                ),
              ),
              child: Text(
                categories[i],
                style: RawiTypography.chip(active: active),
              ),
            ),
          );
        },
      ),
    );
  }
}
