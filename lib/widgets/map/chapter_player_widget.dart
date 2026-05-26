import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocket_guide_mobile/design_system/colors.dart';
import 'package:pocket_guide_mobile/services/background_audio_service.dart';
import 'package:pocket_guide_mobile/services/geofence_service.dart';

/// Full audio player shown in the active-tour bottom sheet.
///
/// Layout (top → bottom):
///   Row 1 — chapter title · download dot | list icon | speed pill
///   Row 2 — scrubber + time labels
///   Row 3 — prev · large play/pause · next
class ChapterPlayerWidget extends StatefulWidget {
  const ChapterPlayerWidget({
    super.key,
    required this.geofenceService,
    this.onShowChapterList,
  });

  final GeofenceService geofenceService;
  final VoidCallback? onShowChapterList;

  @override
  State<ChapterPlayerWidget> createState() => _ChapterPlayerWidgetState();
}

class _ChapterPlayerWidgetState extends State<ChapterPlayerWidget> {
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _speed = BackgroundAudioService.instance.currentSpeed;
  }

  void _showSpeedSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: const Color(0x6B1B1915),
      builder: (_) => _SpeedSheet(
        initial: _speed,
        onPick: (s) {
          setState(() => _speed = s);
          BackgroundAudioService.instance.setSpeed(s);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: BackgroundAudioService.instance.playbackStateStream,
      builder: (context, playbackSnap) {
        final isPlaying = playbackSnap.data == PlaybackState.playing;
        final isBuffering = playbackSnap.data == PlaybackState.buffering;

        return StreamBuilder<Duration>(
          stream: BackgroundAudioService.instance.positionStream,
          builder: (context, posSnap) {
            return StreamBuilder<Duration?>(
              stream: BackgroundAudioService.instance.durationStream,
              builder: (context, durSnap) {
                final position = posSnap.data ?? Duration.zero;
                final duration = durSnap.data;
                final progress = (duration != null && duration.inMilliseconds > 0)
                    ? (position.inMilliseconds / duration.inMilliseconds)
                        .clamp(0.0, 1.0)
                    : 0.0;

                final chapterTitle =
                    widget.geofenceService.currentSectionTitle ?? '—';
                final chapterIdx =
                    widget.geofenceService.currentSectionIndex + 1;
                final chapterTotal =
                    widget.geofenceService.currentSectionTotal;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Row 1: title + list + speed ──────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      chapterTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.sourceSans3(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: PGColors.rawiInk,
                                        letterSpacing: -0.02,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Download indicator (always shown as
                                  // "ready" — offline cache tracking is
                                  // a future feature)
                                  Icon(
                                    Icons.download_done_rounded,
                                    size: 14,
                                    color: PGColors.rawiAccent,
                                  ),
                                ],
                              ),
                              if (chapterTotal > 0) ...[
                                const SizedBox(height: 3),
                                Text(
                                  'Chapter $chapterIdx of $chapterTotal',
                                  style: GoogleFonts.sourceSans3(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: PGColors.rawiInk3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Chapter list button
                        _SquareButton(
                          onTap: widget.onShowChapterList,
                          child: const Icon(Icons.format_list_bulleted_rounded,
                              size: 18, color: PGColors.rawiInk),
                        ),
                        const SizedBox(width: 6),

                        // Speed pill
                        _SquareButton(
                          onTap: () => _showSpeedSheet(context),
                          child: Text(
                            '$_speed×',
                            style: GoogleFonts.sourceSans3(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: PGColors.rawiInk,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Row 2: scrubber ───────────────────────────────────
                    _Scrubber(progress: progress, position: position, duration: duration),

                    const SizedBox(height: 14),

                    // ── Row 3: prev · play · next ─────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Previous chapter
                        _TransportButton(
                          size: 52,
                          onTap: () =>
                              widget.geofenceService.playPreviousSection(),
                          child: const Icon(Icons.skip_previous_rounded,
                              size: 26, color: PGColors.rawiInk),
                        ),

                        const SizedBox(width: 32),

                        // Play / pause
                        GestureDetector(
                          onTap: () {
                            if (isPlaying) {
                              BackgroundAudioService.instance.pause();
                            } else {
                              BackgroundAudioService.instance.resume();
                            }
                          },
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: const BoxDecoration(
                              color: PGColors.rawiAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x381B1915),
                                  blurRadius: 18,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: isBuffering
                                ? const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: PGColors.rawiPaper,
                                    ),
                                  )
                                : Icon(
                                    isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 34,
                                    color: PGColors.rawiPaper,
                                  ),
                          ),
                        ),

                        const SizedBox(width: 32),

                        // Next chapter
                        _TransportButton(
                          size: 52,
                          onTap: () =>
                              widget.geofenceService.playNextSection(),
                          child: const Icon(Icons.skip_next_rounded,
                              size: 26, color: PGColors.rawiInk),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: PGColors.rawiPaper2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PGColors.rawiHair),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({required this.size, required this.child, this.onTap});
  final double size;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: child),
      ),
    );
  }
}

// ── Speed bottom sheet ────────────────────────────────────────────────────────

class _SpeedSheet extends StatefulWidget {
  const _SpeedSheet({required this.initial, required this.onPick});
  final double initial;
  final ValueChanged<double> onPick;

  @override
  State<_SpeedSheet> createState() => _SpeedSheetState();
}

class _SpeedSheetState extends State<_SpeedSheet> {
  static const _speeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  late double _val;

  @override
  void initState() {
    super.initState();
    _val = widget.initial;
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
  }

  void _pick(double v) {
    setState(() => _val = v);
    widget.onPick(v);
  }

  // Converts a horizontal drag/tap x position into a snapped speed value.
  // [totalWidth] is the full width of the scale row from LayoutBuilder.
  void _handleDragX(double localX, double totalWidth) {
    const trackInset = 19.0; // half of 38px tick button
    final usable = totalWidth - trackInset * 2;
    final clamped = (localX - trackInset).clamp(0.0, usable);
    final frac = usable > 0 ? clamped / usable : 0.0;
    final idx =
        (frac * (_speeds.length - 1)).round().clamp(0, _speeds.length - 1);
    _pick(_speeds[idx]);
  }

  @override
  Widget build(BuildContext context) {
    final idx = _speeds.indexWhere((s) => (s - _val).abs() < 0.01);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.42,
      ),
      decoration: const BoxDecoration(
        color: PGColors.rawiPaper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
            child: Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: PGColors.rawiInk.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Row(
              children: [
                Text(
                  'Speed',
                  style: GoogleFonts.sourceSans3(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: PGColors.rawiInk,
                    letterSpacing: -0.02,
                    decoration: TextDecoration.none,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: PGColors.rawiPaper2,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: PGColors.rawiInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 0.5, color: PGColors.rawiHair),

          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Big numeral
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _fmt(_val),
                      style: GoogleFonts.sourceSans3(
                        fontSize: 56,
                        fontWeight: FontWeight.w700,
                        color: PGColors.rawiInk,
                        letterSpacing: -0.04,
                        height: 1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '×',
                      style: GoogleFonts.sourceSans3(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: PGColors.rawiInk3,
                        letterSpacing: -0.02,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Scale
                _buildScale(idx),
              ],
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildScale(int currentIdx) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final totalWidth = constraints.maxWidth;
        const trackInset = 19.0; // half of 38px tick button
        final trackUsable = totalWidth - trackInset * 2;
        final fillFraction = currentIdx >= 0
            ? currentIdx / (_speeds.length - 1)
            : 0.0;

        // Single GestureDetector covers the whole scale — handles both
        // tap-to-snap and horizontal drag. onPanStart fires on first touch
        // (handles taps too); onPanUpdate fires as the finger moves.
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _handleDragX(d.localPosition.dx, totalWidth),
          onPanUpdate: (d) => _handleDragX(d.localPosition.dx, totalWidth),
          child: Column(
            children: [
              // Track + ticks (visual only — no nested GestureDetectors)
              SizedBox(
                height: 38,
                child: Stack(
                  children: [
                    // Track background
                    Positioned(
                      left: trackInset,
                      right: trackInset,
                      top: 17,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: PGColors.rawiHair,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    // Track fill
                    if (currentIdx > 0)
                      Positioned(
                        left: trackInset,
                        top: 17,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          height: 4,
                          width: trackUsable * fillFraction,
                          decoration: BoxDecoration(
                            color: PGColors.rawiAccent,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    // Tick visuals (pure display, no GestureDetector)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_speeds.length, (i) {
                        final active = i == currentIdx;
                        final passed = i < currentIdx;
                        return SizedBox(
                          width: 38,
                          height: 38,
                          child: Center(
                            child: active
                                ? Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: PGColors.rawiAccent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: PGColors.rawiPaper,
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: PGColors.rawiInk
                                              .withValues(alpha: 0.20),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  )
                                : Opacity(
                                    opacity: passed ? 0.55 : 0.85,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: passed
                                            ? PGColors.rawiAccent
                                            : PGColors.rawiInk4,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

              // Labels
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_speeds.length, (i) {
                  final active = i == currentIdx;
                  return SizedBox(
                    width: 38,
                    child: Text(
                      '${_speeds[i]}×',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.sourceSans3(
                        fontSize: 11,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? PGColors.rawiInk : PGColors.rawiInk3,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: -0.01,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Scrubber ───────────────────────────────────────────────────────────────────

class _Scrubber extends StatelessWidget {
  const _Scrubber({
    required this.progress,
    required this.position,
    this.duration,
  });

  final double progress;
  final Duration position;
  final Duration? duration;

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Track
        LayoutBuilder(
          builder: (_, constraints) {
            final trackWidth = constraints.maxWidth;
            final thumbX = (trackWidth * progress).clamp(0.0, trackWidth);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Background
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: PGColors.rawiHair,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                // Progress fill
                Container(
                  height: 3,
                  width: trackWidth * progress,
                  decoration: BoxDecoration(
                    color: PGColors.rawiAccent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                // Thumb
                Positioned(
                  left: thumbX - 6,
                  top: -4.5,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: PGColors.rawiAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: PGColors.rawiInk.withValues(alpha: 0.18),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 6),

        // Time labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _fmt(position),
              style: GoogleFonts.sourceSans3(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: PGColors.rawiInk3,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              duration != null ? _fmt(duration!) : '—',
              style: GoogleFonts.sourceSans3(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: PGColors.rawiInk3,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
