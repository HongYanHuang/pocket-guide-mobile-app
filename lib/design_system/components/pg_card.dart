import 'package:flutter/cupertino.dart';
import '../colors.dart';
import '../typography.dart';
import '../spacing.dart';

/// Minimalist card component
class PGCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final bool elevated;

  const PGCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding ?? PGSpacing.paddingL,
      decoration: BoxDecoration(
        color: PGColors.surface,
        borderRadius: PGRadius.radiusM,
        border: Border.all(
          color: PGColors.border,
          width: 1,
        ),
        boxShadow: elevated ? PGShadows.card : PGShadows.none,
      ),
      child: child,
    );

    if (onTap != null) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: content,
      );
    }

    return content;
  }
}

/// Tour card - displays tour information with minimalist design
class PGTourCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? duration;
  final int? poiCount;
  final VoidCallback onTap;
  final bool isPrivate;

  const PGTourCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.duration,
    this.poiCount,
    required this.onTap,
    this.isPrivate = false,
  });

  @override
  Widget build(BuildContext context) {
    return PGCard(
      onTap: onTap,
      child: Row(
        children: [
          // Icon container
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: PGColors.gray100,
              borderRadius: PGRadius.radiusS,
              border: Border.all(
                color: PGColors.border,
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                isPrivate
                    ? CupertinoIcons.lock_fill
                    : CupertinoIcons.map_fill,
                color: PGColors.brand,
                size: 28,
              ),
            ),
          ),

          SizedBox(width: PGSpacing.l),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  title,
                  style: PGTypography.headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                SizedBox(height: PGSpacing.xs),

                // Subtitle
                Text(
                  subtitle,
                  style: PGTypography.subheadline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // Metadata row
                if (duration != null || poiCount != null) ...[
                  SizedBox(height: PGSpacing.s),
                  Row(
                    children: [
                      if (duration != null) ...[
                        Icon(
                          CupertinoIcons.time,
                          size: 14,
                          color: PGColors.textTertiary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          duration!,
                          style: PGTypography.caption1,
                        ),
                      ],
                      if (duration != null && poiCount != null)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: PGSpacing.s,
                          ),
                          child: Text(
                            '•',
                            style: PGTypography.caption1,
                          ),
                        ),
                      if (poiCount != null) ...[
                        Icon(
                          CupertinoIcons.placemark_fill,
                          size: 14,
                          color: PGColors.textTertiary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '$poiCount POIs',
                          style: PGTypography.caption1,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),

          SizedBox(width: PGSpacing.m),

          // Chevron
          Icon(
            CupertinoIcons.chevron_right,
            color: PGColors.gray400,
            size: 20,
          ),
        ],
      ),
    );
  }
}

/// POI card - displays point of interest
class PGPOICard extends StatelessWidget {
  final int number;
  final String name;
  final String? description;
  final bool completed;
  final VoidCallback onTap;

  const PGPOICard({
    super.key,
    required this.number,
    required this.name,
    this.description,
    this.completed = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PGCard(
      onTap: onTap,
      child: Row(
        children: [
          // Number badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: completed ? PGColors.brand : PGColors.gray100,
              borderRadius: PGRadius.radiusS,
              border: Border.all(
                color: completed ? PGColors.brand : PGColors.border,
                width: 1,
              ),
            ),
            child: Center(
              child: completed
                  ? Icon(
                      CupertinoIcons.checkmark,
                      color: PGColors.white,
                      size: 20,
                    )
                  : Text(
                      number.toString(),
                      style: PGTypography.headline.copyWith(
                        color: PGColors.textPrimary,
                      ),
                    ),
            ),
          ),

          SizedBox(width: PGSpacing.l),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: PGTypography.headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (description != null) ...[
                  SizedBox(height: PGSpacing.xs),
                  Text(
                    description!,
                    style: PGTypography.subheadline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          SizedBox(width: PGSpacing.m),

          // Chevron
          Icon(
            CupertinoIcons.chevron_right,
            color: PGColors.gray400,
            size: 20,
          ),
        ],
      ),
    );
  }
}

/// Simple content card
class PGContentCard extends StatelessWidget {
  final String? title;
  final Widget content;
  final EdgeInsets? padding;

  const PGContentCard({
    super.key,
    this.title,
    required this.content,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return PGCard(
      padding: padding ?? PGSpacing.paddingL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: PGTypography.headline,
            ),
            SizedBox(height: PGSpacing.m),
          ],
          content,
        ],
      ),
    );
  }
}
