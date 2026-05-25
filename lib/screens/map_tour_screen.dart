import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pocket_guide_api/pocket_guide_api.dart' hide TrailPoint;
import 'package:pocket_guide_mobile/services/location_service.dart';
import 'package:pocket_guide_mobile/services/tour_progress_service.dart';
import 'package:pocket_guide_mobile/services/trail_upload_manager.dart';
import 'package:pocket_guide_mobile/services/progress_manager.dart';
import 'package:pocket_guide_mobile/services/auth_service.dart';
import 'package:pocket_guide_mobile/services/active_tour_service.dart';
import 'package:pocket_guide_mobile/services/geofence_service.dart';
import 'package:pocket_guide_mobile/services/notification_service.dart';
import 'package:pocket_guide_mobile/services/api_service.dart';
import 'package:pocket_guide_mobile/services/background_audio_service.dart';
import 'package:pocket_guide_mobile/models/gps_trail_point.dart';
import 'package:pocket_guide_mobile/models/geofence_event.dart';
import 'package:pocket_guide_mobile/design_system/colors.dart';
import 'package:pocket_guide_mobile/design_system/typography.dart';
import 'package:pocket_guide_mobile/design_system/spacing.dart';
import 'package:pocket_guide_mobile/widgets/map/stop_pin_widget.dart';
import 'package:pocket_guide_mobile/widgets/map/chapter_player_widget.dart';
import 'package:pocket_guide_mobile/widgets/network_image_with_fallback.dart';

// ─── Sheet states ─────────────────────────────────────────────────────────────
// preStart  → pre-tour overview (map + bottom card + Start CTA)
// active    → tour running, bottom sheet visible with audio player
// mini      → tour running, map fills screen, thin pill at bottom
enum _SheetState { preStart, active, mini }

class MapTourScreen extends StatefulWidget {
  final TourDetail tourDetail;
  final bool isActiveMode;
  final int initialDay;

  const MapTourScreen({
    super.key,
    required this.tourDetail,
    this.isActiveMode = false,
    this.initialDay = 1,
  });

  @override
  State<MapTourScreen> createState() => _MapTourScreenState();
}

class _MapTourScreenState extends State<MapTourScreen>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final AuthService _authService = AuthService();

  late TourProgressService _progressService;
  TrailUploadManager? _trailManager;
  ProgressManager? _progressManager;
  GeofenceService? _geofenceService;
  StreamSubscription<GeofenceEvent>? _geofenceSubscription;

  int _selectedDay = 1;
  Position? _userPosition;
  bool _permissionDenied = false;
  List<TrailPoint> _trailPoints = [];
  bool _autoFollowUser = true;
  bool _autoPlayNext = true;

  late _SheetState _sheetState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedDay = widget.initialDay;
    _sheetState =
        widget.isActiveMode ? _SheetState.active : _SheetState.preStart;
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _initializeServices();
    if (widget.isActiveMode) {
      await _initializeGPS();
      await _loadExistingTrail();
    }
  }

  Future<void> _initializeServices() async {
    final accessToken = await _authService.getAccessToken();
    if (accessToken == null) return;

    _progressService = TourProgressService(jwtToken: accessToken);
    _progressManager = ProgressManager(
      progressService: _progressService,
      tourId: widget.tourDetail.metadata.tourId,
    );
    await _progressManager!.loadProgress();

    if (widget.isActiveMode) {
      await ActiveTourService().saveActiveTour(
        tourId: widget.tourDetail.metadata.tourId,
        day: _selectedDay,
      );

      _geofenceService = GeofenceService(
        progressManager: _progressManager!,
        apiService: ApiService(),
        tourId: widget.tourDetail.metadata.tourId,
        language: _getTourLanguage(),
        city: widget.tourDetail.metadata.city,
        accessToken: accessToken,
      );
      await NotificationService.instance.requestPermission();
      await _geofenceService!.loadAudioProgress();
      _geofenceSubscription = _geofenceService!.events.listen((event) {
        if (!mounted) return;
        setState(() {});
      });
    }

    if (mounted) setState(() {});
  }

  String _getTourLanguage() {
    final langs = widget.tourDetail.metadata.languages;
    if (langs != null && langs.isNotEmpty) return langs.first;
    return 'en';
  }

  Future<void> _initializeGPS() async {
    final hasPermission = await _locationService.hasPermission();
    if (!hasPermission) {
      final granted = await _locationService.requestPermission();
      if (!granted) {
        setState(() => _permissionDenied = true);
        _showPermissionDeniedDialog();
        return;
      }
    }

    _trailManager = TrailUploadManager(
      progressService: _progressService,
      tourId: widget.tourDetail.metadata.tourId,
    );
    _trailManager!.start();

    _locationService.onLocationUpdate = (Position position) {
      setState(() => _userPosition = position);

      if (_autoFollowUser) {
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          _mapController.camera.zoom,
        );
      }

      _trailManager?.addPoint(position);
      setState(() {
        _trailPoints.add(TrailPoint(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: DateTime.now(),
        ));
      });

      _geofenceService?.onLocationUpdate(position);
    };

    final started =
        await _locationService.startTracking(isBackground: false);
    if (started) {
      _geofenceService?.updateActiveDay(
          _selectedDay, _getPoisForDay(_selectedDay));
    } else {
      _showLocationServiceDisabledDialog();
    }
  }

  Future<void> _loadExistingTrail() async {
    try {
      final trail = await _progressService
          .getTrail(tourId: widget.tourDetail.metadata.tourId);
      setState(() => _trailPoints = trail.points);
    } catch (_) {}
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBackPressed();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEFE8D8),
        body: Stack(
          children: [
            // ── Full-screen map ──────────────────────────────────────────
            _buildMap(),

            // ── Floating chrome: back + day selector ─────────────────────
            _buildTopChrome(),

            // ── Distance chip (active mode only) ─────────────────────────
            if (widget.isActiveMode && _userPosition != null)
              _buildDistanceChip(),

            // ── Permission denied banner ──────────────────────────────────
            if (widget.isActiveMode && _permissionDenied)
              _buildPermissionBanner(),

            // ── Recenter button ──────────────────────────────────────────
            if (widget.isActiveMode &&
                _userPosition != null &&
                !_autoFollowUser)
              _buildRecenterButton(),

            // ── Bottom overlay depending on sheet state ──────────────────
            // Positioned.fill gives AnimatedSwitcher tight constraints so that
            // Positioned(bottom: X) children anchor to the screen bottom on web.
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: switch (_sheetState) {
                  _SheetState.preStart => _buildPreStartCard(),
                  _SheetState.active   => _buildActiveSheet(),
                  _SheetState.mini     => _buildMiniPlayer(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Map layer ─────────────────────────────────────────────────────────────

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _calculateCenter(),
        initialZoom: _calculateZoom(),
        minZoom: 10.0,
        maxZoom: 18.0,
        onPositionChanged: (_, hasGesture) {
          if (hasGesture && _autoFollowUser) {
            setState(() => _autoFollowUser = false);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.pocketguide.mobile',
          maxZoom: 19,
        ),
        PolylineLayer(polylines: _buildPolylines()),
        MarkerLayer(markers: _buildMarkers()),
      ],
    );
  }

  // ── Top chrome ────────────────────────────────────────────────────────────

  Widget _buildTopChrome() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Back button
              _FloatingChrome(
                child: GestureDetector(
                  onTap: _onBackPressed,
                  child: const SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: PGColors.rawiInk),
                  ),
                ),
              ),

              const Spacer(),

              // Day selector (multi-day tours only)
              if (widget.tourDetail.itinerary.length > 1)
                _FloatingChrome(
                  child: GestureDetector(
                    onTap: _showDayPicker,
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Day $_selectedDay',
                            style: GoogleFonts.sourceSans3(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: PGColors.rawiInk,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.expand_more_rounded,
                              size: 16, color: PGColors.rawiInk3),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Distance chip ─────────────────────────────────────────────────────────

  Widget _buildDistanceChip() {
    final nextPoi = _getNextUncompletedPoi();
    if (nextPoi == null) {
      return const SizedBox.shrink();
    }

    final poiLoc = _getPoiLocation(nextPoi);
    if (poiLoc == null || _userPosition == null) {
      return const SizedBox.shrink();
    }

    final dist = Geolocator.distanceBetween(
      _userPosition!.latitude,
      _userPosition!.longitude,
      poiLoc.latitude,
      poiLoc.longitude,
    );

    final distStr = dist < 100
        ? '${dist.round()} m'
        : dist < 1000
            ? '${(dist / 100).round() * 100} m'
            : '${(dist / 1000).toStringAsFixed(1)} km';

    final arrived = dist <= 80;

    return Positioned(
      top: 88,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: PGColors.rawiInk.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: PGColors.rawiPaper.withValues(alpha: 0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: PGColors.rawiInk.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                arrived ? Icons.check_circle_outline_rounded
                        : Icons.place_outlined,
                size: 14,
                color: PGColors.rawiPaper,
              ),
              const SizedBox(width: 7),
              Text(
                arrived ? "You've arrived" : distStr,
                style: GoogleFonts.sourceSans3(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: PGColors.rawiPaper,
                  letterSpacing: -0.01,
                ),
              ),
              if (!arrived) ...[
                const SizedBox(width: 8),
                Container(width: 1, height: 12,
                    color: PGColors.rawiPaper.withValues(alpha: 0.3)),
                const SizedBox(width: 8),
                Text(
                  '~${(dist / 80).ceil()} min',
                  style: GoogleFonts.sourceSans3(
                    fontSize: 13,
                    color: PGColors.rawiPaper.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Pre-start bottom card ─────────────────────────────────────────────────

  Widget _buildPreStartCard() {
    final tour = widget.tourDetail;
    final totalStops = tour.itinerary
        .fold(0, (sum, day) => sum + day.pois.length);
    final distKm = tour.totalWalkingKm.toStringAsFixed(1);
    final durationHrs = tour.totalDurationHours.toStringAsFixed(1);
    final finishBy = _finishAround(tour.totalDurationHours.toDouble());

    final stats = [
      (label: 'Stops', value: '$totalStops', accent: false),
      (label: 'Distance', value: '$distKm km', accent: false),
      (label: 'Duration', value: '$durationHrs h', accent: false),
      (label: 'Finish by', value: '≈ $finishBy', accent: true),
    ];

    return Align(
      key: const ValueKey('preStart'),
      alignment: Alignment.bottomCenter,
      child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 22),
      child: Container(
        decoration: BoxDecoration(
          color: PGColors.rawiPaper,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: PGColors.rawiHair),
          boxShadow: [
            BoxShadow(
              color: PGColors.rawiInk.withValues(alpha: 0.22),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row + offline badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready to walk',
                        style: GoogleFonts.sourceSans3(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.14,
                          color: PGColors.rawiAccent,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tour.metadata.titleDisplay ??
                            tour.metadata.tourId,
                        style: GoogleFonts.sourceSans3(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.02,
                          height: 1.15,
                          color: PGColors.rawiInk,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Offline indicator
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: PGColors.rawiAccentSoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_done_rounded,
                          size: 10, color: PGColors.rawiAccent),
                      const SizedBox(width: 4),
                      Text(
                        'Offline',
                        style: GoogleFonts.sourceSans3(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.06,
                          color: PGColors.rawiAccent,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Stats strip
            Container(
              decoration: BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(color: PGColors.rawiHair),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    if (i > 0)
                      Container(
                          width: 0.5,
                          height: 32,
                          color: PGColors.rawiHair),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            stats[i].value,
                            style: GoogleFonts.sourceSans3(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: stats[i].accent
                                  ? PGColors.rawiAccent
                                  : PGColors.rawiInk,
                              letterSpacing: -0.01,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            stats[i].label.toUpperCase(),
                            style: GoogleFonts.sourceSans3(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: PGColors.rawiInk3,
                              letterSpacing: 0.1,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Start tour button
            GestureDetector(
              onTap: _onStartTourPressed,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: PGColors.rawiAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow_rounded,
                        size: 18, color: PGColors.rawiPaper),
                    const SizedBox(width: 8),
                    Text(
                      'Start tour now',
                      style: GoogleFonts.sourceSans3(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: PGColors.rawiPaper,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  // ── Active bottom sheet ───────────────────────────────────────────────────

  Widget _buildActiveSheet() {
    final currentPoi = _geofenceService?.currentPoi;
    final poiId = _geofenceService?.currentPoiId;
    final poiName = _geofenceService?.currentPoiName ?? '—';

    // Find stop number for the current POI
    final pois = _getPoisForDay(_selectedDay);
    final stopNumber = pois.indexWhere((p) =>
            (p.poiId ?? _poiNameToId(p.poi)) == poiId) +
        1;

    return Align(
      key: const ValueKey('active'),
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          color: PGColors.rawiPaper,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: PGColors.rawiHair)),
          boxShadow: [
            BoxShadow(
              color: PGColors.rawiInk.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, -12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle → tap to collapse to mini
            GestureDetector(
              onTap: () => setState(() => _sheetState = _SheetState.mini),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
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

            // Current stop header
            GestureDetector(
              onTap: () => setState(() => _sheetState = _SheetState.mini),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                child: Row(
                  children: [
                    // Stop thumbnail
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (currentPoi?.coverImageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 46,
                                height: 46,
                                child: NetworkImageWithFallback(
                                  imageUrl: currentPoi!.coverImageUrl!,
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: PGColors.rawiPaper2,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),

                          // Number badge at bottom-right
                          if (stopNumber > 0)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: PGColors.rawiAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: PGColors.rawiPaper,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '$stopNumber',
                                    style: const TextStyle(
                                      color: PGColors.rawiPaper,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Stop name + chapter info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stopNumber > 0
                                ? 'Current stop · $stopNumber of ${pois.length}'
                                : 'Current stop',
                            style: GoogleFonts.sourceSans3(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.14,
                              color: PGColors.rawiAccent,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            poiName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.sourceSans3(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.01,
                              color: PGColors.rawiInk,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 20, color: PGColors.rawiInk3),
                  ],
                ),
              ),
            ),

            // Audio player
            if (_geofenceService != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: PGColors.rawiHair)),
                ),
                child: ChapterPlayerWidget(
                  geofenceService: _geofenceService!,
                  onShowChapterList: () {
                    // TODO: open chapter list modal
                  },
                ),
              ),

            // Auto-play next stop chip
            GestureDetector(
              onTap: () =>
                  setState(() => _autoPlayNext = !_autoPlayNext),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _autoPlayNext
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 14,
                      color: _autoPlayNext
                          ? PGColors.rawiAccent
                          : PGColors.rawiInk3,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _autoPlayNext
                          ? 'Auto-play next stop'
                          : 'Auto-play next stop off',
                      style: GoogleFonts.sourceSans3(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _autoPlayNext
                            ? PGColors.rawiAccent
                            : PGColors.rawiInk3,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Safe-area padding
            SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
          ],
        ),
      ),
    );
  }

  // ── Mini player ──────────────────────────────────────────────────────────

  Widget _buildMiniPlayer() {
    final currentPoi = _geofenceService?.currentPoi;
    final chapterTitle =
        _geofenceService?.currentSectionTitle ?? '—';
    final chapterIdx = (_geofenceService?.currentSectionIndex ?? 0) + 1;
    final chapterTotal = _geofenceService?.currentSectionTotal ?? 0;
    final stopName = _geofenceService?.currentPoiName ?? '—';

    return Align(
      key: const ValueKey('mini'),
      alignment: Alignment.bottomCenter,
      child: Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 26 + MediaQuery.of(context).padding.bottom),
      child: GestureDetector(
        onTap: () => setState(() => _sheetState = _SheetState.active),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: PGColors.rawiPaper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PGColors.rawiHair),
            boxShadow: [
              BoxShadow(
                color: PGColors.rawiInk.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // Stop thumbnail
              if (currentPoi?.coverImageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: NetworkImageWithFallback(
                      imageUrl: currentPoi!.coverImageUrl!,
                    ),
                  ),
                )
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: PGColors.rawiPaper2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

              const SizedBox(width: 10),

              // Chapter + stop info + progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      chapterTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sourceSans3(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.01,
                        color: PGColors.rawiInk,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (chapterTotal > 0)
                          Text(
                            'Chapter $chapterIdx of $chapterTotal',
                            style: GoogleFonts.sourceSans3(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: PGColors.rawiAccent,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        const SizedBox(width: 5),
                        const Text('·',
                            style: TextStyle(
                                color: PGColors.rawiInk4, fontSize: 11)),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            stopName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.sourceSans3(
                              fontSize: 11,
                              color: PGColors.rawiInk3,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Tiny progress bar
                    StreamBuilder<Duration>(
                      stream: BackgroundAudioService.instance.positionStream,
                      builder: (_, posSnap) {
                        return StreamBuilder<Duration?>(
                          stream: BackgroundAudioService.instance.durationStream,
                          builder: (_, durSnap) {
                            final pos = posSnap.data ?? Duration.zero;
                            final dur = durSnap.data;
                            final progress =
                                (dur != null && dur.inMilliseconds > 0)
                                    ? (pos.inMilliseconds /
                                            dur.inMilliseconds)
                                        .clamp(0.0, 1.0)
                                    : 0.0;
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 2,
                                backgroundColor: PGColors.rawiHair,
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                        PGColors.rawiAccent),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Pause/play button
              StreamBuilder<PlaybackState>(
                stream: BackgroundAudioService.instance.playbackStateStream,
                builder: (_, snap) {
                  final playing = snap.data == PlaybackState.playing;
                  return GestureDetector(
                    onTap: () {
                      if (playing) {
                        BackgroundAudioService.instance.pause();
                      } else {
                        BackgroundAudioService.instance.resume();
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: PGColors.rawiAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 20,
                        color: PGColors.rawiPaper,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  // ── Markers ───────────────────────────────────────────────────────────────

  List<Marker> _buildMarkers() {
    final pois = _getPoisForDay(_selectedDay);
    final markers = <Marker>[];
    final currentPoiId = _geofenceService?.currentPoiId;

    for (var i = 0; i < pois.length; i++) {
      final poi = pois[i];
      final location = _getPoiLocation(poi);
      if (location == null) continue;

      final poiId = poi.poiId ?? _poiNameToId(poi.poi);
      final completed =
          _progressManager?.isPOICompleted(poiId, _selectedDay) ?? false;

      final state = completed
          ? StopPinState.completed
          : (poiId == currentPoiId)
              ? StopPinState.current
              : StopPinState.upcoming;

      // Build a full base URL for the cover image
      final photoUrl = poi.coverImageUrl != null
          ? _resolveImageUrl(poi.coverImageUrl!)
          : null;

      // Size the marker container large enough for the pulse ring
      const containerSize = 72.0;

      markers.add(Marker(
        point: location,
        width: containerSize,
        height: containerSize,
        child: Center(
          child: StopPinWidget(
            number: i + 1,
            state: state,
            photoUrl: photoUrl,
            onTap: () => _onPoiTap(poi, i + 1, poiId),
          ),
        ),
      ));
    }

    // User location dot (active mode)
    if (widget.isActiveMode && _userPosition != null) {
      markers.add(Marker(
        point: LatLng(_userPosition!.latitude, _userPosition!.longitude),
        width: 30,
        height: 30,
        child: _buildUserDot(),
      ));
    }

    return markers;
  }

  Widget _buildUserDot() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0x384583F0),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF4583F0),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Polyline> _buildPolylines() {
    final pois = _getPoisForDay(_selectedDay);
    final poiPoints = pois
        .map(_getPoiLocation)
        .whereType<LatLng>()
        .toList();

    final polylines = <Polyline>[];

    if (poiPoints.length >= 2) {
      // Split into completed and upcoming segments
      final currentPoiId = _geofenceService?.currentPoiId;
      int currentIdx = -1;
      for (var i = 0; i < pois.length; i++) {
        if ((pois[i].poiId ?? _poiNameToId(pois[i].poi)) == currentPoiId) {
          currentIdx = i;
          break;
        }
      }

      // Completed portion (dashed, faded)
      if (currentIdx > 0) {
        polylines.add(Polyline(
          points: poiPoints.sublist(0, currentIdx + 1),
          color: PGColors.rawiInk.withValues(alpha: 0.3),
          strokeWidth: 2.5,
          pattern: StrokePattern.dashed(segments: const [8, 6]),
        ));
      }

      // Upcoming portion (solid accent)
      final startIdx = math.max(0, currentIdx);
      if (startIdx < poiPoints.length - 1) {
        polylines.add(Polyline(
          points: poiPoints.sublist(startIdx),
          color: PGColors.rawiAccent.withValues(alpha: 0.7),
          strokeWidth: 4.5,
        ));
      }
    }

    // GPS trail (active mode)
    if (widget.isActiveMode && _trailPoints.length >= 2) {
      polylines.add(Polyline(
        points: _trailPoints.map((tp) => tp.toLatLng()).toList(),
        color: PGColors.rawiAccent.withValues(alpha: 0.5),
        strokeWidth: 3.0,
      ));
    }

    return polylines;
  }

  // ── Floating chrome helpers ───────────────────────────────────────────────

  Widget _buildPermissionBanner() {
    return Positioned(
      top: 80,
      left: 16,
      right: 16,
      child: SafeArea(
        child: Container(
          padding: PGSpacing.paddingL,
          decoration: BoxDecoration(
            color: PGColors.errorLight,
            borderRadius: PGRadius.radiusM,
            border: Border.all(color: PGColors.error),
          ),
          child: Row(
            children: [
              Icon(CupertinoIcons.location_slash,
                  color: PGColors.error, size: 20),
              SizedBox(width: PGSpacing.s),
              Expanded(
                child: Text(
                  'Location permission denied. Tour tracking disabled.',
                  style: PGTypography.footnote.copyWith(
                    color: PGColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecenterButton() {
    return Positioned(
      right: 16,
      bottom: _sheetState == _SheetState.preStart ? 300 : 100,
      child: GestureDetector(
        onTap: _centerOnUserLocation,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: PGColors.rawiPaper.withValues(alpha: 0.96),
            shape: BoxShape.circle,
            border: Border.all(color: PGColors.rawiHair),
            boxShadow: [
              BoxShadow(
                color: PGColors.rawiInk.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.my_location_rounded,
            size: 20,
            color: PGColors.rawiAccent,
          ),
        ),
      ),
    );
  }

  // ── Logic helpers ─────────────────────────────────────────────────────────

  String _finishAround(double durationHours) {
    final now = DateTime.now();
    final end = now.add(Duration(minutes: (durationHours * 60).round()));
    final roundedMins = ((end.minute / 15).round() * 15) % 60;
    final roundedHour =
        end.hour + ((end.minute / 15).round() * 15 >= 60 ? 1 : 0);
    final time = DateTime(
      end.year,
      end.month,
      end.day,
      roundedHour % 24,
      roundedMins,
    );
    final h = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final m = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  String _resolveImageUrl(String url) {
    if (url.startsWith('http')) return url;
    return '${ApiService.baseUrl}$url';
  }

  TourPOI? _getNextUncompletedPoi() {
    final pois = _getPoisForDay(_selectedDay);
    try {
      return pois.firstWhere((p) {
        final id = p.poiId ?? _poiNameToId(p.poi);
        return !(_progressManager?.isPOICompleted(id, _selectedDay) ?? false);
      });
    } catch (_) {
      return null;
    }
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
    } catch (_) {}
    return null;
  }

  List<TourPOI> _getPoisForDay(int day) {
    if (day <= 0 || day > widget.tourDetail.itinerary.length) return [];
    return widget.tourDetail.itinerary[day - 1].pois.toList();
  }

  LatLng _calculateCenter() {
    final locs = _getPoisForDay(_selectedDay)
        .map(_getPoiLocation)
        .whereType<LatLng>()
        .toList();

    if (locs.isEmpty) {
      if (widget.tourDetail.itinerary.isNotEmpty) {
        for (final poi in widget.tourDetail.itinerary[0].pois) {
          final loc = _getPoiLocation(poi);
          if (loc != null) return loc;
        }
      }
      return LatLng(0.0, 0.0);
    }

    final avgLat =
        locs.map((l) => l.latitude).reduce((a, b) => a + b) / locs.length;
    final avgLng =
        locs.map((l) => l.longitude).reduce((a, b) => a + b) / locs.length;
    return LatLng(avgLat, avgLng);
  }

  double _calculateZoom() {
    final locs = _getPoisForDay(_selectedDay)
        .map(_getPoiLocation)
        .whereType<LatLng>()
        .toList();

    if (locs.length < 2) return 14.0;

    final maxDiff = [
      locs.map((l) => l.latitude).reduce((a, b) => a > b ? a : b) -
          locs.map((l) => l.latitude).reduce((a, b) => a < b ? a : b),
      locs.map((l) => l.longitude).reduce((a, b) => a > b ? a : b) -
          locs.map((l) => l.longitude).reduce((a, b) => a < b ? a : b),
    ].reduce((a, b) => a > b ? a : b);

    if (maxDiff > 0.1) return 12.0;
    if (maxDiff > 0.05) return 13.0;
    if (maxDiff > 0.02) return 14.0;
    return 15.0;
  }

  String _poiNameToId(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
  }

  void _centerOnUserLocation() {
    if (_userPosition == null) return;
    setState(() => _autoFollowUser = true);
    _mapController.move(
      LatLng(_userPosition!.latitude, _userPosition!.longitude),
      16.0,
    );
  }

  // ── POI tap ───────────────────────────────────────────────────────────────

  Future<void> _onPoiTap(TourPOI poi, int number, String poiId) async {
    final completed =
        _progressManager?.isPOICompleted(poiId, _selectedDay) ?? false;

    if (!mounted) return;

    // TODO: Replace with rawi-styled POI bottom sheet when designed
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      barrierColor: Colors.black54,
      builder: (_) => _SimplePoiSheet(
        poi: poi,
        number: number,
        completed: completed,
        onToggle: (v) async {
          await _togglePOICompletion(poiId, v);
        },
      ),
    );
  }

  Future<void> _togglePOICompletion(String poiId, bool completed) async {
    await _progressManager?.updatePOICompletion(
      poiId: poiId,
      day: _selectedDay,
      completed: completed,
    );
    if (mounted) setState(() {});
  }

  // ── Start tour ────────────────────────────────────────────────────────────

  Future<void> _onStartTourPressed() async {
    final hasPermission = await _locationService.hasPermission();
    if (!hasPermission) {
      final granted = await _locationService.requestPermission();
      if (!granted) {
        _showPermissionDeniedDialog();
        return;
      }
    }

    Position? currentPosition;
    try {
      currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (_) {
      _showLocationServiceDisabledDialog();
      return;
    }

    final firstPoi = widget.tourDetail.itinerary.isNotEmpty &&
            widget.tourDetail.itinerary[0].pois.isNotEmpty
        ? widget.tourDetail.itinerary[0].pois.first
        : null;
    final firstLoc = firstPoi != null ? _getPoiLocation(firstPoi) : null;

    if (firstLoc != null) {
      final dist = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        firstLoc.latitude,
        firstLoc.longitude,
      );
      if (dist / 1000 > 1.0) {
        _showNotAtStartPointDialog(firstLoc, firstPoi!.poi);
        return;
      }
    }

    _startTourAnyway();
  }

  void _startTourAnyway() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MapTourScreen(
          tourDetail: widget.tourDetail,
          isActiveMode: true,
        ),
      ),
    );
  }

  // ── Back ──────────────────────────────────────────────────────────────────

  Future<void> _onBackPressed() async {
    if (!widget.isActiveMode) {
      Navigator.of(context).pop();
      return;
    }

    final finish = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('End the tour?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Finish'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );

    if (finish == true && mounted) {
      await ActiveTourService().clearActiveTour();
      Navigator.of(context).pop();
    }
  }

  // ── Day picker ────────────────────────────────────────────────────────────

  void _showDayPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 250,
        color: PGColors.rawiPaper,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoButton(
                  child: const Text('Done'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 40,
                scrollController:
                    FixedExtentScrollController(initialItem: _selectedDay - 1),
                onSelectedItemChanged: (idx) {
                  setState(() => _selectedDay = idx + 1);
                  _mapController.move(
                      _calculateCenter(), _calculateZoom());
                  _geofenceService?.updateActiveDay(
                      idx + 1, _getPoisForDay(idx + 1));
                  if (widget.isActiveMode) {
                    ActiveTourService().updateActiveDay(idx + 1);
                  }
                },
                children: List.generate(
                  widget.tourDetail.itinerary.length,
                  (i) => Center(
                    child: Text('Day ${i + 1}',
                        style: PGTypography.body),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
            'Please grant location permission in your device settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLocationServiceDisabledDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Location Service Disabled'),
        content: const Text(
            'Please enable location services to use active tour mode.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showNotAtStartPointDialog(LatLng firstPoiLocation, String poiName) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Not at start point'),
        content: Text('You are more than 1km from $poiName.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              _openAppleMaps(firstPoiLocation);
            },
            child: const Text('Get directions'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              _startTourAnyway();
            },
            child: const Text('Start anyway'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAppleMaps(LatLng dest) async {
    final uri = Uri.parse(
        'http://maps.apple.com/?daddr=${dest.latitude},${dest.longitude}&dirflg=d');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.isActiveMode) return;
    if (state == AppLifecycleState.paused) {
      _locationService.enterBackgroundMode();
      _geofenceService?.saveProgressSnapshot();
    } else if (state == AppLifecycleState.resumed) {
      _locationService.enterForegroundMode();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationService.dispose();
    _trailManager?.dispose();
    _progressManager?.dispose();
    _geofenceSubscription?.cancel();
    _geofenceService?.dispose();
    _mapController.dispose();
    super.dispose();
  }
}

// ─── Floating chrome container ────────────────────────────────────────────────

class _FloatingChrome extends StatelessWidget {
  const _FloatingChrome({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PGColors.rawiPaper.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PGColors.rawiHair),
        boxShadow: [
          BoxShadow(
            color: PGColors.rawiInk.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Simple POI tap sheet (placeholder until rawi detail sheet is designed) ───

class _SimplePoiSheet extends StatelessWidget {
  const _SimplePoiSheet({
    required this.poi,
    required this.number,
    required this.completed,
    required this.onToggle,
  });

  final TourPOI poi;
  final int number;
  final bool completed;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PGColors.rawiPaper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: PGColors.rawiInk.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: PGColors.rawiAccent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: PGColors.rawiPaper,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  poi.poi,
                  style: GoogleFonts.sourceSans3(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: PGColors.rawiInk,
                    letterSpacing: -0.02,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
          if (poi.blurb != null) ...[
            const SizedBox(height: 10),
            Text(
              poi.blurb!,
              style: GoogleFonts.sourceSans3(
                fontSize: 14,
                height: 1.55,
                color: PGColors.rawiInk2,
                decoration: TextDecoration.none,
              ),
            ),
          ],
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              onToggle(!completed);
              Navigator.pop(context);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: completed
                    ? PGColors.rawiPaper2
                    : PGColors.rawiAccent,
                borderRadius: BorderRadius.circular(14),
                border: completed
                    ? Border.all(color: PGColors.rawiHair)
                    : null,
              ),
              child: Center(
                child: Text(
                  completed ? 'Mark as not visited' : 'Mark as visited',
                  style: GoogleFonts.sourceSans3(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: completed ? PGColors.rawiInk2 : PGColors.rawiPaper,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
