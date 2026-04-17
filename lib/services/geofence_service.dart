import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:pocket_guide_api/pocket_guide_api.dart';
import 'package:pocket_guide_mobile/models/geofence_event.dart';
import 'package:pocket_guide_mobile/services/api_service.dart';
import 'package:pocket_guide_mobile/services/background_audio_service.dart';
import 'package:pocket_guide_mobile/services/progress_manager.dart';

class GeofenceService {
  final ProgressManager _progressManager;
  final ApiService _apiService;
  final String _tourId;
  final String _language;
  final String _city;

  // Trigger radius and GPS accuracy guard
  static const double _radiusMeters = 80.0;
  static const double _maxAccuracyMeters = 50.0;

  // Active day state
  int _activeDay = 1;
  List<TourPOI> _poisForDay = [];

  // Triggered POIs per day — prevents re-triggering
  final Map<int, Set<String>> _triggeredByDay = {};

  // Current geofence-managed playback state
  String? _currentPoiId;
  String? _currentPoiName;
  List<TranscriptSection> _currentSections = [];
  int _currentSectionIndex = 0;
  StreamSubscription<PlaybackState>? _audioSubscription;
  bool _isFetchingSections = false;

  // Section transcript cache — avoids re-fetching on re-entry
  final Map<String, SectionedTranscriptData> _sectionCache = {};

  // Section resume progress — poiId -> sectionIndex to resume from
  final Map<String, int> _sectionProgress = {};

  // Event stream for MapTourScreen (snackbar + marker refresh)
  final _eventController = StreamController<GeofenceEvent>.broadcast();
  Stream<GeofenceEvent> get events => _eventController.stream;

  final String _accessToken;

  // Total sections per POI — needed for progress POST after sections are cleared
  final Map<String, int> _totalSections = {};

  GeofenceService({
    required ProgressManager progressManager,
    required ApiService apiService,
    required String tourId,
    required String language,
    required String city,
    required String accessToken,
  })  : _progressManager = progressManager,
        _apiService = apiService,
        _tourId = tourId,
        _language = language,
        _city = city,
        _accessToken = accessToken;

  /// Update which day is active and which POIs to monitor.
  /// Called by MapTourScreen on init and when user switches days.
  void updateActiveDay(int day, List<TourPOI> pois) {
    _activeDay = day;
    _poisForDay = pois;
    _triggeredByDay[day] ??= {};
    print('📍 Geofence: monitoring day $day — ${pois.length} POIs');
  }

  /// Called on every GPS update from LocationService.
  /// Only active when tour is in active mode.
  void onLocationUpdate(Position position) {
    // Ignore poor GPS readings (urban canyon drift)
    if (position.accuracy > _maxAccuracyMeters) return;
    if (_poisForDay.isEmpty) return;

    _triggeredByDay[_activeDay] ??= {};

    for (final poi in _poisForDay) {
      final poiId = _getPoiId(poi);

      // Skip if already triggered this session for this day
      if (_triggeredByDay[_activeDay]!.contains(poiId)) continue;

      // Skip if POI already completed
      if (_progressManager.isPOICompleted(poiId, _activeDay)) continue;

      final poiLocation = _getPoiLocation(poi);
      if (poiLocation == null) continue;

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        poiLocation.latitude,
        poiLocation.longitude,
      );

      if (distance <= _radiusMeters) {
        print('🎯 Geofence entered: ${poi.poi} (${distance.toStringAsFixed(0)}m)');
        // Mark as triggered immediately to prevent race on next location update
        _triggeredByDay[_activeDay]!.add(poiId);
        _triggerPOIAudio(poi, poiId);
        break; // Only one POI per location update
      }
    }
  }

  /// Save in-progress section state to backend.
  /// Called on AppLifecycleState.paused so progress survives app restart.
  void saveProgressSnapshot() {
    if (_currentPoiId == null) return;
    final total = _totalSections[_currentPoiId!] ?? _currentSections.length;
    if (total == 0) return;
    print('💾 Saving progress snapshot: $_currentPoiId @ index $_currentSectionIndex');
    _postAudioProgress(
      poiId: _currentPoiId!,
      day: _activeDay,
      lastSectionIndex: _currentSectionIndex,
      totalSections: total,
      allSectionsCompleted: false,
    );
  }

  /// Load audio section progress from backend on session start.
  /// Seeds _sectionProgress so geofence auto-resumes from the right section.
  Future<void> loadAudioProgress() async {
    final records = await _apiService.getAudioProgress(
      accessToken: _accessToken,
      tourId: _tourId,
    );
    for (final record in records) {
      final poiId = record['poi_id'] as String;
      final lastIndex = record['last_section_index'] as int;
      final allDone = record['all_sections_completed'] as bool;
      if (!allDone) {
        _sectionProgress[poiId] = lastIndex;
        print('📖 Restored section progress: $poiId → resume at index $lastIndex');
      }
    }
    if (records.isNotEmpty) {
      print('✅ Audio progress loaded for ${records.length} POIs');
    }
  }

  /// POST audio section progress to backend (fire and forget, fails silently).
  void _postAudioProgress({
    required String poiId,
    required int day,
    required int lastSectionIndex,
    required int totalSections,
    required bool allSectionsCompleted,
  }) {
    final completedSections = List<int>.generate(lastSectionIndex + 1, (i) => i + 1);
    _apiService.saveAudioProgress(
      accessToken: _accessToken,
      tourId: _tourId,
      poiId: poiId,
      day: day,
      lastSectionIndex: lastSectionIndex,
      completedSections: completedSections,
      totalSections: totalSections,
      allSectionsCompleted: allSectionsCompleted,
    );
    // Intentionally not awaited — fire and forget
  }

  Future<void> _triggerPOIAudio(TourPOI poi, String poiId) async {
    // Don't interrupt audio the user started manually
    if (BackgroundAudioService.instance.isPlaying && _currentPoiId == null) {
      print('⚠️  Manual audio playing — emitting notification only, not interrupting');
      _eventController.add(GeofenceEvent(
        type: GeofenceEventType.poiEntered,
        poiId: poiId,
        poiName: poi.poi,
      ));
      return;
    }

    // Don't interrupt a different geofence-managed POI already in progress
    if (_currentPoiId != null && _currentPoiId != poiId) {
      print('⚠️  Already playing geofence audio for $_currentPoiId — skipping ${poi.poi}');
      return;
    }

    if (_isFetchingSections) return;
    _isFetchingSections = true;
    _currentPoiId = poiId;
    _currentPoiName = poi.poi;

    // Notify map screen immediately (shows snackbar)
    _eventController.add(GeofenceEvent(
      type: GeofenceEventType.poiEntered,
      poiId: poiId,
      poiName: poi.poi,
    ));

    try {
      // Use cached transcript or fetch from API
      SectionedTranscriptData? data = _sectionCache[poiId];
      if (data == null) {
        print('📡 Fetching transcript for geofence trigger: $poiId');
        data = await _apiService.fetchSectionedTranscript(
          _city,
          poiId,
          _tourId,
          _language,
        );
      }

      if (data == null || data.sections.isEmpty) {
        print('⚠️  No transcript available for: $poiId');
        _currentPoiId = null;
        _currentPoiName = null;
        return;
      }

      _sectionCache[poiId] = data;
      _currentSections = data.sections.toList();
      _totalSections[poiId] = _currentSections.length;

      // Resume from saved section index, or start from beginning
      _currentSectionIndex = _sectionProgress[poiId] ?? 0;
      if (_currentSectionIndex >= _currentSections.length) {
        _currentSectionIndex = 0;
      }

      print('▶️  Starting playback from section ${_currentSectionIndex + 1}/${_currentSections.length}');

      // Subscribe to audio completion to advance sections
      _audioSubscription?.cancel();
      _audioSubscription = BackgroundAudioService.instance.playbackStateStream.listen(
        (state) async {
          if (state == PlaybackState.completed && _currentPoiId == poiId) {
            await _onSectionCompleted(poiId);
          }
        },
      );

      await _playCurrentSection(poiId);
    } catch (e) {
      print('❌ Geofence audio error for $poiId: $e');
      _currentPoiId = null;
      _currentPoiName = null;
    } finally {
      _isFetchingSections = false;
    }
  }

  Future<void> _playCurrentSection(String poiId) async {
    if (_currentSectionIndex >= _currentSections.length) {
      _onAllSectionsCompleted(poiId);
      return;
    }

    final section = _currentSections[_currentSectionIndex];

    // Skip sections without an audio file
    if (section.audioFile == null) {
      print('⏭️  Section ${_currentSectionIndex + 1} has no audio, skipping');
      _currentSectionIndex++;
      _sectionProgress[poiId] = _currentSectionIndex;
      await _playCurrentSection(poiId);
      return;
    }

    final url = _apiService.getAudioUrl(_city, poiId, section.audioFile!);
    print('🎵 Section ${_currentSectionIndex + 1}/${_currentSections.length}: ${section.title}');

    await BackgroundAudioService.instance.play(
      url: url,
      title: section.title,
      subtitle: _currentPoiName ?? poiId,
    );
  }

  Future<void> _onSectionCompleted(String poiId) async {
    _currentSectionIndex++;
    _sectionProgress[poiId] = _currentSectionIndex;
    print('✅ Section complete. Progress: $_currentSectionIndex/${_currentSections.length}');

    if (_currentSectionIndex < _currentSections.length) {
      await _playCurrentSection(poiId);
    } else {
      _onAllSectionsCompleted(poiId);
    }
  }

  void _onAllSectionsCompleted(String poiId) {
    print('🎉 All sections complete for: $poiId');

    _audioSubscription?.cancel();
    _audioSubscription = null;

    final total = _totalSections[poiId] ?? _currentSections.length;

    // Sync audio section progress to backend
    _postAudioProgress(
      poiId: poiId,
      day: _activeDay,
      lastSectionIndex: total - 1,
      totalSections: total,
      allSectionsCompleted: true,
    );

    // Mark POI complete — syncs to backend via existing progress endpoint
    _progressManager.updatePOICompletion(
      poiId: poiId,
      day: _activeDay,
      completed: true,
    );

    final completedPoiName = _currentPoiName ?? poiId;

    // Reset current playback state
    _currentPoiId = null;
    _currentPoiName = null;
    _currentSections = [];
    _currentSectionIndex = 0;
    // Keep _sectionProgress[poiId] so re-entry check works correctly

    _eventController.add(GeofenceEvent(
      type: GeofenceEventType.poiCompleted,
      poiId: poiId,
      poiName: completedPoiName,
    ));
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _getPoiId(TourPOI poi) {
    return poi.poiId ?? _poiNameToId(poi.poi);
  }

  String _poiNameToId(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
  }

  LatLng? _getPoiLocation(TourPOI poi) {
    final coords = poi.coordinates;
    if (coords == null) return null;
    try {
      final lat = coords['lat']?.asNum ?? coords['latitude']?.asNum;
      final lng = coords['lng']?.asNum ?? coords['longitude']?.asNum;
      if (lat != null && lng != null) {
        return LatLng(lat.toDouble(), lng.toDouble());
      }
    } catch (e) {
      print('Error parsing coordinates for ${poi.poi}: $e');
    }
    return null;
  }

  void dispose() {
    _audioSubscription?.cancel();
    if (!_eventController.isClosed) {
      _eventController.close();
    }
  }
}
