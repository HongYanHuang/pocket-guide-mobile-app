import 'package:flutter/material.dart';
import 'package:pocket_guide_api/pocket_guide_api.dart';
import 'package:pocket_guide_mobile/services/api_service.dart';
import 'package:audioplayers/audioplayers.dart';

class POIMapBottomSheet extends StatefulWidget {
  final TourPOI poi;
  final int poiNumber;
  final String poiId;
  final int day;
  final String tourId;
  final bool completed;
  final bool isActiveMode; // true = show complete button, false = hide it
  final Function(bool) onToggleCompletion;

  const POIMapBottomSheet({
    super.key,
    required this.poi,
    required this.poiNumber,
    required this.poiId,
    required this.day,
    required this.tourId,
    required this.completed,
    required this.isActiveMode,
    required this.onToggleCompletion,
  });

  @override
  State<POIMapBottomSheet> createState() => _POIMapBottomSheetState();
}

class _POIMapBottomSheetState extends State<POIMapBottomSheet> {
  final ApiService _apiService = ApiService();
  SectionedTranscriptData? _sectionedData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSectionedTranscript();
  }

  Future<void> _loadSectionedTranscript() async {
    try {
      // Extract city from tourId (format: rome-tour-...)
      final city = widget.tourId.split('-').first;

      final data = await _apiService.fetchSectionedTranscript(
        city,
        widget.poiId,
        widget.tourId,
        'en',
      );

      setState(() {
        _sectionedData = data;
        _loading = false;
      });
    } catch (e) {
      print('Error loading sectioned transcript: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: widget.completed ? Colors.green.shade600 : Colors.grey.shade400,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${widget.poiNumber}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.poi.poi,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Content
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _sectionedData != null && _sectionedData!.sections.isNotEmpty
                        ? ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: _sectionedData!.sections.length + 2, // +2 for reason and completion button
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                // POI reason
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Text(
                                    widget.poi.reason,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                );
                              } else if (index == _sectionedData!.sections.length + 1) {
                                // Completion button (only in active mode)
                                if (!widget.isActiveMode) return const SizedBox.shrink();

                                return Padding(
                                  padding: const EdgeInsets.only(top: 16, bottom: 24),
                                  child: TextButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      widget.onToggleCompletion(!widget.completed);
                                    },
                                    icon: Icon(
                                      widget.completed ? Icons.check_circle : Icons.check_circle_outline,
                                      size: 18,
                                    ),
                                    label: Text(widget.completed ? 'Mark as Incomplete' : 'Mark as Complete'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: widget.completed ? Colors.grey.shade700 : Colors.green.shade700,
                                    ),
                                  ),
                                );
                              } else {
                                // Audio sections
                                final section = _sectionedData!.sections[index - 1];
                                String? audioUrl;

                                // Use POI audio URL for "Full Narrative" section if available
                                if (section.title == 'Full Narrative' &&
                                    widget.poi.audioAvailable == true &&
                                    widget.poi.audioUrl != null) {
                                  audioUrl = '${ApiService.baseUrl}${widget.poi.audioUrl}';
                                } else if (section.audioFile != null) {
                                  // Extract city from tourId
                                  final city = widget.tourId.split('-').first;
                                  audioUrl = _apiService.getAudioUrl(city, widget.poiId, section.audioFile!);
                                }

                                return _AudioSectionCard(
                                  section: section,
                                  audioUrl: audioUrl,
                                  isExpanded: index == 1, // Expand first section by default
                                );
                              }
                            },
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.poi.reason,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${widget.poi.estimatedHours} hours',
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                const Center(
                                  child: Text(
                                    'No audio sections available',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Audio Section Card Widget
class _AudioSectionCard extends StatefulWidget {
  final TranscriptSection section;
  final String? audioUrl;
  final bool isExpanded;

  const _AudioSectionCard({
    required this.section,
    this.audioUrl,
    this.isExpanded = false,
  });

  @override
  State<_AudioSectionCard> createState() => _AudioSectionCardState();
}

class _AudioSectionCardState extends State<_AudioSectionCard> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  late bool _isExpanded;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
          if (position > Duration.zero && _isLoading) {
            _isLoading = false;
          }
        });
      }
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (state != PlayerState.playing) {
            _isLoading = false;
          }
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  Future<void> _togglePlayPause() async {
    if (widget.audioUrl == null) return;

    try {
      if (_isPlaying) {
        setState(() {
          _isPlaying = false;
        });
        await _audioPlayer.pause();
      } else {
        setState(() {
          _isPlaying = true;
          _isLoading = _position == Duration.zero;
        });
        if (_position == Duration.zero) {
          await _audioPlayer.play(UrlSource(widget.audioUrl!));
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        } else {
          await _audioPlayer.resume();
        }
      }
    } catch (e) {
      print('Error playing audio: $e');
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isLoading = false;
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${widget.section.sectionNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.section.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.section.knowledgePoint,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Audio controls
                  if (widget.audioUrl != null) ...[
                    const SizedBox(width: 8),
                    if (_duration > Duration.zero)
                      Text(
                        _formatDuration(_duration),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        _isLoading
                            ? Icons.hourglass_empty
                            : _isPlaying
                                ? Icons.pause_circle
                                : Icons.play_circle,
                        color: Colors.blue.shade600,
                        size: 32,
                      ),
                      onPressed: _togglePlayPause,
                    ),
                  ],
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),

          // Audio progress bar
          if (widget.audioUrl != null && _duration > Duration.zero)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      value: _position.inSeconds.toDouble(),
                      max: _duration.inSeconds.toDouble(),
                      onChanged: (value) async {
                        final newPosition = Duration(seconds: value.toInt());
                        await _audioPlayer.seek(newPosition);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Transcript content
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                widget.section.transcript,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade800,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
