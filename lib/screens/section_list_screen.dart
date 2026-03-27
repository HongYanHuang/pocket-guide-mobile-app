import 'package:flutter/material.dart';
import 'package:pocket_guide_api/pocket_guide_api.dart';
import 'package:pocket_guide_mobile/services/api_service.dart';
import 'package:pocket_guide_mobile/services/background_audio_service.dart';

class SectionListScreen extends StatefulWidget {
  final String tourId;
  final String poiId;
  final String poiName;
  final List<TranscriptSection> sections;
  final Map<int, String?> audioUrls; // section number -> audio URL

  const SectionListScreen({
    super.key,
    required this.tourId,
    required this.poiId,
    required this.poiName,
    required this.sections,
    required this.audioUrls,
  });

  @override
  State<SectionListScreen> createState() => _SectionListScreenState();
}

class _SectionListScreenState extends State<SectionListScreen> {
  int? _playingSectionNumber;
  final _audioService = BackgroundAudioService.instance;

  @override
  void initState() {
    super.initState();
    // Listen to playback state to update UI
    _audioService.playbackStateStream.listen((state) {
      if (mounted) {
        if (state == PlaybackState.completed || state == PlaybackState.paused) {
          setState(() {
            // Keep track of which section was playing
          });
        }
      }
    });
  }

  Future<void> _playSection(TranscriptSection section) async {
    final audioUrl = widget.audioUrls[section.sectionNumber];
    if (audioUrl == null) {
      print('No audio URL for section ${section.sectionNumber}');
      return;
    }

    try {
      // Stop current if playing different section
      if (_playingSectionNumber != null && _playingSectionNumber != section.sectionNumber) {
        await _audioService.stop();
      }

      // Toggle play/pause
      if (_playingSectionNumber == section.sectionNumber) {
        await _audioService.stop();
        setState(() {
          _playingSectionNumber = null;
        });
      } else {
        print('🎵 Playing section ${section.sectionNumber}: $audioUrl');
        await _audioService.play(
          url: audioUrl,
          title: section.title,
          subtitle: widget.poiName,
        );
        setState(() {
          _playingSectionNumber = section.sectionNumber;
        });
      }
    } catch (e) {
      print('❌ Error playing audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play audio: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.poiName),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.sections.length,
        itemBuilder: (context, index) {
          final section = widget.sections[index];
          final audioUrl = widget.audioUrls[section.sectionNumber];
          final isPlaying = _playingSectionNumber == section.sectionNumber;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: isPlaying ? 4 : 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isPlaying ? Colors.blue.shade600 : Colors.blue.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${section.sectionNumber}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isPlaying ? Colors.white : Colors.blue.shade900,
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
                              section.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isPlaying ? Colors.blue.shade900 : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              section.knowledgePoint,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Play button
                      if (audioUrl != null)
                        IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                            color: Colors.blue.shade600,
                            size: 48,
                          ),
                          onPressed: () => _playSection(section),
                        ),
                    ],
                  ),

                  // Duration
                  if (audioUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 44, top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '~${(section.estimatedDurationSeconds / 60).ceil()} min',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
