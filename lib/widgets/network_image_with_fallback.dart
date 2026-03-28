import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pocket_guide_mobile/design_system/colors.dart';
import 'package:pocket_guide_mobile/design_system/typography.dart';

/// Network image widget with loading and error fallbacks
class NetworkImageWithFallback extends StatelessWidget {
  final String? imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final IconData fallbackIcon;

  const NetworkImageWithFallback({
    super.key,
    this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.fallbackIcon = CupertinoIcons.photo,
  });

  @override
  Widget build(BuildContext context) {
    // Show fallback if no image URL
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallback();
    }

    Widget image = Image.network(
      imageUrl!,
      height: height,
      width: width,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;

        return Container(
          height: height,
          width: width,
          color: PGColors.gray100,
          child: Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CupertinoActivityIndicator(
                color: PGColors.brand,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildFallback();
      },
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }

  Widget _buildFallback() {
    if (placeholder != null) {
      return placeholder!;
    }

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: PGColors.gray100,
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Icon(
          fallbackIcon,
          size: 48,
          color: PGColors.gray400,
        ),
      ),
    );
  }
}
