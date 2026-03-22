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
  bool _showListView = false; // false = single section view, true = list view
  int _currentSectionIndex = 0; // Current section being displayed

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
        // Start with first section (index 0) - could be enhanced to find first uncompleted
        _currentSectionIndex = 0;
      });
    } catch (e) {
      print('Error loading sectioned transcript: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  void _goToPreviousSection() {
    if (_currentSectionIndex > 0) {
      setState(() {
        _currentSectionIndex--;
        _showListView = false;
      });
    }
  }

  void _goToNextSection() {
    if (_sectionedData != null && _currentSectionIndex < _sectionedData!.sections.length - 1) {
      setState(() {
        _currentSectionIndex++;
        _showListView = false;
      });
    }
  }

  void _toggleListView() {
    setState(() {
      _showListView = !_showListView;
    });
  }

  void _selectSection(int index) {
    setState(() {
      _currentSectionIndex = index;
      _showListView = false;
    });
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
                        ? Column(
                            children: [
                              // POI Reason
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                child: Text(
                                  widget.poi.reason,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),

                              // Navigation Buttons
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                child: Row(
                                  children: [
                                    // Previous Button
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _currentSectionIndex > 0 ? _goToPreviousSection : null,
                                        icon: const Icon(Icons.chevron_left, size: 20),
                                        label: const Text('Previous'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // List Button
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _toggleListView,
                                        icon: Icon(_showListView ? Icons.grid_view : Icons.list, size: 20),
                                        label: Text(_showListView ? 'Focus' : 'List'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Next Button
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _currentSectionIndex < _sectionedData!.sections.length - 1
                                            ? _goToNextSection
                                            : null,
                                        label: const Text('Next'),
                                        icon: const Icon(Icons.chevron_right, size: 20),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Content Area (Single Section or List)
                              Expanded(
                                child: _showListView ? _buildListView(scrollController) : _buildSingleSectionView(),
                              ),

                              // Completion Button (only in active mode)
                              if (widget.isActiveMode)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                                  child: SizedBox(
                                    width: double.infinity,
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
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
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

  // Build single section view (shows one section at a time)
  Widget _buildSingleSectionView() {
    if (_sectionedData == null || _sectionedData!.sections.isEmpty) {
      return const Center(child: Text('No sections available'));
    }

    final section = _sectionedData!.sections[_currentSectionIndex];
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: _AudioSectionCard(
        section: section,
        audioUrl: audioUrl,
        key: ValueKey('section_${section.sectionNumber}'), // Force rebuild when section changes
      ),
    );
  }

  // Build list view (shows all sections)
  Widget _buildListView(ScrollController scrollController) {
    if (_sectionedData == null || _sectionedData!.sections.isEmpty) {
      return const Center(child: Text('No sections available'));
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _sectionedData!.sections.length,
      itemBuilder: (context, index) {
        final section = _sectionedData!.sections[index];
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

        return GestureDetector(
          onTap: () => _selectSection(index),
          child: _AudioSectionCard(
            section: section,
            audioUrl: audioUrl,
            showSelectButton: true,
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
  final bool showSelectButton;

  const _AudioSectionCard({
    super.key,
    required this.section,
    this.audioUrl,
    this.showSelectButton = false,
  });

  @override
  State<_AudioSectionCard> createState() => _AudioSectionCardState();
}

class _AudioSectionCardState extends State<_AudioSectionCard> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isExpanded = false; // Default collapsed
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
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
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section number badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Section ${widget.section.sectionNumber}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Title (like song name)
            Text(
              widget.section.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),

            // Knowledge point (like artist name)
            Text(
              widget.section.knowledgePoint,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),

            // Audio player controls
            if (widget.audioUrl != null) ...[
              // Progress bar
              if (_duration > Duration.zero)
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()),
                    max: _duration.inSeconds.toDouble(),
                    activeColor: Colors.blue.shade600,
                    inactiveColor: Colors.grey.shade300,
                    onChanged: (value) async {
                      final newPosition = Duration(seconds: value.toInt());
                      await _audioPlayer.seek(newPosition);
                    },
                  ),
                ),

              // Time indicators
              if (_duration > Duration.zero)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // Play/Pause button (centered, large)
              Center(
                child: IconButton(
                  icon: Icon(
                    _isLoading
                        ? Icons.hourglass_empty
                        : _isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                    color: Colors.blue.shade600,
                    size: 64,
                  ),
                  onPressed: _togglePlayPause,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Transcript toggle button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                icon: Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 20,
                ),
                label: Text(_isExpanded ? 'Hide Transcript' : 'Show Transcript'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // Transcript content (collapsed by default)
            if (_isExpanded) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  widget.section.transcript,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                    height: 1.6,
                  ),
                ),
              ),
            ],

            // Select button (shown in list view)
            if (widget.showSelectButton) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {}, // Parent handles tap on whole card
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Select & Focus on This Section'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
