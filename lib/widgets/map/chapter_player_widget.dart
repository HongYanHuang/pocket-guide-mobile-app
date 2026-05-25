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
  final List<double> _speeds = [0.75, 1.0, 1.25, 1.5];

  void _cycleSpeed() {
    setState(() {
      final idx = _speeds.indexOf(_speed);
      _speed = _speeds[(idx + 1) % _speeds.length];
    });
    // TODO: apply _speed to BackgroundAudioService when that API is added
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
                          onTap: _cycleSpeed,
                          child: Text(
                            '${_speed % 1 == 0 ? _speed.toInt() : _speed}×',
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
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: child),
      ),
    );
  }
}

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
