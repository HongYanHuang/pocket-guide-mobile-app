import 'package:flutter/cupertino.dart';
import '../colors.dart';
import '../typography.dart';
import '../spacing.dart';

/// Minimalist button with dark green accent
class PGButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isFullWidth;
  final IconData? icon;
  final bool isLoading;
  final PGButtonSize size;

  const PGButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isPrimary = true,
    this.isFullWidth = false,
    this.icon,
    this.isLoading = false,
    this.size = PGButtonSize.large,
  });

  @override
  Widget build(BuildContext context) {
    final double height = switch (size) {
      PGButtonSize.small => 36.0,
      PGButtonSize.medium => 44.0,
      PGButtonSize.large => 50.0,
    };

    final TextStyle textStyle = switch (size) {
      PGButtonSize.small => PGTypography.buttonSmall,
      PGButtonSize.medium => PGTypography.buttonSmall,
      PGButtonSize.large => PGTypography.button,
    };

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: height,
      child: CupertinoButton(
        padding: EdgeInsets.symmetric(
          horizontal: size == PGButtonSize.small ? PGSpacing.l : PGSpacing.xl,
          vertical: 0,
        ),
        color: isPrimary ? PGColors.brand : null,
        borderRadius: BorderRadius.circular(PGRadius.m),
        disabledColor: PGColors.gray300,
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CupertinoActivityIndicator(
                  color: isPrimary ? PGColors.white : PGColors.brand,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: size == PGButtonSize.small ? 16 : 20,
                      color: isPrimary ? PGColors.white : PGColors.brand,
                    ),
                    SizedBox(width: PGSpacing.s),
                  ],
                  Text(
                    text,
                    style: textStyle.copyWith(
                      color: isPrimary ? PGColors.white : PGColors.brand,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Secondary button (outlined style)
class PGButtonSecondary extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isFullWidth;
  final PGButtonSize size;

  const PGButtonSecondary({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isFullWidth = false,
    this.size = PGButtonSize.large,
  });

  @override
  Widget build(BuildContext context) {
    final double height = switch (size) {
      PGButtonSize.small => 36.0,
      PGButtonSize.medium => 44.0,
      PGButtonSize.large => 50.0,
    };

    final TextStyle textStyle = switch (size) {
      PGButtonSize.small => PGTypography.buttonSmall,
      PGButtonSize.medium => PGTypography.buttonSmall,
      PGButtonSize.large => PGTypography.button,
    };

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: height,
      child: CupertinoButton(
        padding: EdgeInsets.symmetric(
          horizontal: size == PGButtonSize.small ? PGSpacing.l : PGSpacing.xl,
          vertical: 0,
        ),
        color: null,
        borderRadius: BorderRadius.circular(PGRadius.m),
        onPressed: onPressed,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: onPressed != null ? PGColors.brand : PGColors.gray300,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(PGRadius.m),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: size == PGButtonSize.small ? PGSpacing.l : PGSpacing.xl,
            vertical: 0,
          ),
          height: height,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: size == PGButtonSize.small ? 16 : 20,
                  color: onPressed != null ? PGColors.brand : PGColors.gray300,
                ),
                SizedBox(width: PGSpacing.s),
              ],
              Text(
                text,
                style: textStyle.copyWith(
                  color: onPressed != null ? PGColors.brand : PGColors.gray300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text button (minimal, no background)
class PGButtonText extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;

  const PGButtonText({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.symmetric(
        horizontal: PGSpacing.m,
        vertical: PGSpacing.s,
      ),
      minSize: 0,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: onPressed != null ? PGColors.brand : PGColors.gray300,
            ),
            SizedBox(width: PGSpacing.xs),
          ],
          Text(
            text,
            style: PGTypography.calloutEmphasized.copyWith(
              color: onPressed != null ? PGColors.brand : PGColors.gray300,
            ),
          ),
        ],
      ),
    );
  }
}

enum PGButtonSize {
  small,
  medium,
  large,
}
