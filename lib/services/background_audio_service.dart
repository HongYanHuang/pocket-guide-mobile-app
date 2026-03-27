import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Background audio service for playing POI audio sections
/// Supports background playback, lock screen controls, and media notifications
class BackgroundAudioService {
  static BackgroundAudioService? _instance;
  static BackgroundAudioService get instance {
    _instance ??= BackgroundAudioService._();
    return _instance!;
  }

  BackgroundAudioService._();

  AudioPlayer? _audioPlayer;
  AudioHandler? _audioHandler;
  bool _isInitialized = false;

  // Current playback state
  String? _currentUrl;
  String? _currentTitle;
  String? _currentSubtitle;

  // Stream controllers for UI updates
  final _playbackStateController = StreamController<PlaybackState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();

  Stream<PlaybackState> get playbackStateStream => _playbackStateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;

  /// Initialize the audio service
  Future<void> initialize() async {
    if (_isInitialized) return;

    print('🎵 Initializing background audio service...');

    try {
      // Initialize audio handler for background playback
      _audioHandler = await AudioService.init(
        builder: () => _AudioPlayerHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.pocketguide.audio',
          androidNotificationChannelName: 'Pocket Guide Audio',
          androidNotificationOngoing: false,
          androidShowNotificationBadge: true,
        ),
      );

      // Initialize audio player
      _audioPlayer = AudioPlayer();

      // Listen to player state changes
      _audioPlayer!.playerStateStream.listen((state) {
        final playing = state.playing;
        final processingState = state.processingState;

        PlaybackState playbackState;
        if (processingState == ProcessingState.loading ||
            processingState == ProcessingState.buffering) {
          playbackState = PlaybackState.buffering;
        } else if (playing) {
          playbackState = PlaybackState.playing;
        } else if (processingState == ProcessingState.completed) {
          playbackState = PlaybackState.completed;
        } else {
          playbackState = PlaybackState.paused;
        }

        _playbackStateController.add(playbackState);
        _updateMediaItem();
      });

      // Listen to position changes
      _audioPlayer!.positionStream.listen((position) {
        _positionController.add(position);
      });

      // Listen to duration changes
      _audioPlayer!.durationStream.listen((duration) {
        _durationController.add(duration);
      });

      _isInitialized = true;
      print('✅ Background audio service initialized');
    } catch (e) {
      print('❌ Error initializing audio service: $e');
      rethrow;
    }
  }

  /// Play audio from URL
  Future<void> play({
    required String url,
    required String title,
    String? subtitle,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      print('🎵 Playing audio: $title');
      print('   URL: $url');

      _currentUrl = url;
      _currentTitle = title;
      _currentSubtitle = subtitle;

      // Set audio source and play
      await _audioPlayer!.setUrl(url);
      await _audioPlayer!.play();

      // Update media notification
      _updateMediaItem();
    } catch (e) {
      print('❌ Error playing audio: $e');
      rethrow;
    }
  }

  /// Pause playback
  Future<void> pause() async {
    if (_audioPlayer == null) return;

    try {
      await _audioPlayer!.pause();
      print('⏸️  Audio paused');
    } catch (e) {
      print('❌ Error pausing audio: $e');
    }
  }

  /// Resume playback
  Future<void> resume() async {
    if (_audioPlayer == null) return;

    try {
      await _audioPlayer!.play();
      print('▶️  Audio resumed');
    } catch (e) {
      print('❌ Error resuming audio: $e');
    }
  }

  /// Stop playback
  Future<void> stop() async {
    if (_audioPlayer == null) return;

    try {
      await _audioPlayer!.stop();
      _currentUrl = null;
      _currentTitle = null;
      _currentSubtitle = null;
      print('⏹️  Audio stopped');
    } catch (e) {
      print('❌ Error stopping audio: $e');
    }
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    if (_audioPlayer == null) return;

    try {
      await _audioPlayer!.seek(position);
    } catch (e) {
      print('❌ Error seeking: $e');
    }
  }

  /// Get current playing state
  bool get isPlaying => _audioPlayer?.playing ?? false;

  /// Get current position
  Duration get currentPosition => _audioPlayer?.position ?? Duration.zero;

  /// Get total duration
  Duration? get duration => _audioPlayer?.duration;

  /// Update media notification with current audio info
  void _updateMediaItem() {
    if (_audioHandler == null || _currentTitle == null) return;

    final mediaItem = MediaItem(
      id: _currentUrl ?? '',
      title: _currentTitle!,
      artist: _currentSubtitle ?? 'Pocket Guide',
      duration: _audioPlayer?.duration,
      artUri: null, // Could add POI image here
    );

    _audioHandler!.updateMediaItem(mediaItem);
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _audioPlayer?.dispose();
    await _audioHandler?.stop();
    await _playbackStateController.close();
    await _positionController.close();
    await _durationController.close();
    _audioPlayer = null;
    _audioHandler = null;
    _isInitialized = false;
  }
}

/// Audio handler for managing background playback
class _AudioPlayerHandler extends BaseAudioHandler {
  _AudioPlayerHandler() {
    // Handle play button
    playbackState.add(playbackState.value.copyWith(
      controls: [MediaControl.play, MediaControl.pause, MediaControl.stop],
      processingState: AudioProcessingState.ready,
    ));
  }

  @override
  Future<void> play() async {
    await BackgroundAudioService.instance.resume();
  }

  @override
  Future<void> pause() async {
    await BackgroundAudioService.instance.pause();
  }

  @override
  Future<void> stop() async {
    await BackgroundAudioService.instance.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await BackgroundAudioService.instance.seek(position);
  }

  /// Update the media item shown in notification
  Future<void> updateMediaItem(MediaItem item) async {
    mediaItem.add(item);
  }
}

/// Playback state enum
enum PlaybackState {
  paused,
  playing,
  buffering,
  completed,
}
