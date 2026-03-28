import 'package:flutter/cupertino.dart';
import '../colors.dart';
import '../typography.dart';
import '../spacing.dart';

/// Minimalist iOS-style navigation bar (centered title for detail pages)
class PGNavigationBar extends StatelessWidget implements ObstructingPreferredSizeWidget {
  final String title;
  final Widget? leading;
  final Widget? trailing;
  final bool showBorder;

  const PGNavigationBar({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PGColors.background,
        border: showBorder
            ? Border(
                bottom: BorderSide(
                  color: PGColors.divider,
                  width: 0.5,
                ),
              )
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: PGSpacing.l),
          child: Row(
            children: [
              // Leading
              if (leading != null)
                leading!
              else
                SizedBox(width: 44),

              // Title (centered)
              Expanded(
                child: Text(
                  title,
                  style: PGTypography.headline,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Trailing
              if (trailing != null)
                trailing!
              else
                SizedBox(width: 44),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(44 + 50); // 44 + safe area approximation

  @override
  bool shouldFullyObstruct(BuildContext context) => true;
}

/// iOS-style large title navigation bar (left-aligned for main screens)
class PGLargeNavigationBar extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final VoidCallback? onTitleTap;
  final bool showChevron;

  const PGLargeNavigationBar({
    super.key,
    required this.title,
    this.trailing,
    this.onTitleTap,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: PGSpacing.l,
          right: PGSpacing.l,
          top: PGSpacing.s,
          bottom: PGSpacing.m,
        ),
        child: Row(
          children: [
            // Title (left-aligned, using title1 size)
            Expanded(
              child: GestureDetector(
                onTap: onTitleTap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: PGTypography.title1,
                    ),
                    if (showChevron) ...[
                      SizedBox(width: PGSpacing.xs),
                      Icon(
                        CupertinoIcons.chevron_down,
                        size: 18,
                        color: PGColors.textPrimary,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Trailing
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Back button for navigation
class PGBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? label;

  const PGBackButton({
    super.key,
    this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 44,
      onPressed: onPressed ?? () => Navigator.of(context).pop(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.chevron_left,
            color: PGColors.brand,
            size: 28,
          ),
          if (label != null)
            Text(
              label!,
              style: PGTypography.body.copyWith(
                color: PGColors.brand,
                decoration: TextDecoration.none,
              ),
            ),
        ],
      ),
    );
  }
}

/// Simple icon button for navigation bar
class PGNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? label;

  const PGNavButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 44,
      onPressed: onPressed,
      child: label != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label!,
                  style: PGTypography.body.copyWith(
                    color: PGColors.brand,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            )
          : Icon(
              icon,
              color: PGColors.brand,
              size: 24,
            ),
    );
  }
}

/// Bottom tab bar (iOS style)
class PGTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<PGTabItem> items;

  const PGTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PGColors.background,
        border: Border(
          top: BorderSide(
            color: PGColors.divider,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = currentIndex == index;

              return Expanded(
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => onTap(index),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? item.activeIcon : item.icon,
                        color: isSelected ? PGColors.brand : PGColors.gray500,
                        size: 24,
                      ),
                      SizedBox(height: 2),
                      Text(
                        item.label,
                        style: PGTypography.caption2.copyWith(
                          color: isSelected ? PGColors.brand : PGColors.gray500,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class PGTabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const PGTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
