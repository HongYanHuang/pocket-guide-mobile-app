import 'package:flutter/material.dart';
import 'package:pocket_guide_mobile/design_system/colors.dart';
import 'package:pocket_guide_mobile/widgets/network_image_with_fallback.dart';

/// Pin state on the map route.
enum StopPinState { upcoming, current, completed }

/// Rawi-styled stop pin.
///
/// • Photo present  → rounded square (27% radius) with corner number badge
/// • No photo       → circle with number inside (quieter / smaller)
/// Three states: upcoming (paper border), current (accent ring + pulse),
/// completed (accent fill + checkmark badge).
class StopPinWidget extends StatefulWidget {
  const StopPinWidget({
    super.key,
    required this.number,
    required this.state,
    this.photoUrl,
    this.onTap,
  });

  final int number;
  final StopPinState state;

  /// HTTP URL of the stop cover photo. Null → number-only circle.
  final String? photoUrl;

  final VoidCallback? onTap;

  @override
  State<StopPinWidget> createState() => _StopPinWidgetState();
}

class _StopPinWidgetState extends State<StopPinWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.7).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    if (widget.state == StopPinState.current) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(StopPinWidget old) {
    super.didUpdateWidget(old);
    if (widget.state == StopPinState.current) {
      if (!_pulseController.isAnimating) _pulseController.repeat();
    } else {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool get _hasPhoto => widget.photoUrl != null && widget.photoUrl!.isNotEmpty;

  double get _photoSize {
    switch (widget.state) {
      case StopPinState.current:
        return 44;
      case StopPinState.completed:
        return 26;
      case StopPinState.upcoming:
        return 32;
    }
  }

  double get _circleSize {
    switch (widget.state) {
      case StopPinState.current:
        return 38;
      case StopPinState.completed:
        return 22;
      case StopPinState.upcoming:
        return 26;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: _hasPhoto ? _buildPhotoPin() : _buildCirclePin(),
    );
  }

  // ── Photo pin — rounded square ─────────────────────────────────────────

  Widget _buildPhotoPin() {
    final size = _photoSize;
    final radius = size * 0.27;
    final isCurrent = widget.state == StopPinState.current;
    final isCompleted = widget.state == StopPinState.completed;

    final borderColor = isCompleted || isCurrent
        ? PGColors.rawiAccent
        : PGColors.rawiInk;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Pulse ring (current only)
        if (isCurrent)
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (_, __) => Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: size + 16,
                height: size + 16,
                decoration: BoxDecoration(
                  color: PGColors.rawiAccent.withValues(alpha: 
                    0.25 * (1 - (_pulseAnimation.value - 0.85) / 0.85),
                  ),
                  borderRadius: BorderRadius.circular(radius + 8),
                ),
              ),
            ),
          ),

        // Photo square
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor,
              width: isCurrent ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: PGColors.rawiInk
                    .withValues(alpha: isCurrent ? 0.30 : 0.20),
                blurRadius: isCurrent ? 14 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius - 2),
            child: ColorFiltered(
              colorFilter: isCompleted
                  ? const ColorFilter.matrix([
                      0.35, 0.35, 0.35, 0, 0,
                      0.35, 0.35, 0.35, 0, 0,
                      0.35, 0.35, 0.35, 0, 0,
                      0,    0,    0,    1, 0,
                    ])
                  : const ColorFilter.mode(
                      Colors.transparent,
                      BlendMode.multiply,
                    ),
              child: NetworkImageWithFallback(
                imageUrl: widget.photoUrl!,
              ),
            ),
          ),
        ),

        // Corner badge (number or checkmark)
        Positioned(
          bottom: -3,
          right: -3,
          child: _buildBadge(isCurrent: isCurrent, isCompleted: isCompleted),
        ),
      ],
    );
  }

  // ── Circle pin — no photo ─────────────────────────────────────────────

  Widget _buildCirclePin() {
    final size = _circleSize;
    final isCurrent = widget.state == StopPinState.current;
    final isCompleted = widget.state == StopPinState.completed;

    final bg = isCurrent || isCompleted ? PGColors.rawiAccent : PGColors.rawiPaper;
    final fg = isCurrent || isCompleted ? PGColors.rawiPaper : PGColors.rawiInk;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (isCurrent)
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (_, __) => Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: size + 16,
                height: size + 16,
                decoration: BoxDecoration(
                  color: PGColors.rawiAccent.withValues(alpha: 
                    0.25 * (1 - (_pulseAnimation.value - 0.85) / 0.85),
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(
              color: isCurrent
                  ? PGColors.rawiAccent
                  : isCompleted
                      ? PGColors.rawiPaper
                      : PGColors.rawiInk,
              width: isCurrent ? 3 : isCompleted ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: PGColors.rawiInk.withValues(alpha: isCurrent ? 0.30 : 0.18),
                blurRadius: isCurrent ? 14 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, color: fg, size: size * 0.45)
                : Text(
                    '${widget.number}',
                    style: TextStyle(
                      color: fg,
                      fontSize: isCurrent ? 14 : 11,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ── Shared badge (corner of photo pin) ───────────────────────────────

  Widget _buildBadge({required bool isCurrent, required bool isCompleted}) {
    final size = isCurrent ? 20.0 : 16.0;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isCompleted ? PGColors.rawiAccent : PGColors.rawiInk,
        shape: BoxShape.circle,
        border: Border.all(color: PGColors.rawiPaper, width: 2),
      ),
      child: Center(
        child: isCompleted
            ? Icon(Icons.check, color: PGColors.rawiPaper, size: size * 0.45)
            : Text(
                '${widget.number}',
                style: TextStyle(
                  color: PGColors.rawiPaper,
                  fontSize: isCurrent ? 9 : 8,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
      ),
    );
  }
}
