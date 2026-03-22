import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pocket_guide_api/pocket_guide_api.dart';
import 'package:pocket_guide_mobile/services/location_service.dart';
import 'package:pocket_guide_mobile/services/tour_progress_service.dart';
import 'package:pocket_guide_mobile/services/trail_upload_manager.dart';
import 'package:pocket_guide_mobile/services/progress_manager.dart';
import 'package:pocket_guide_mobile/services/auth_service.dart';
import 'package:pocket_guide_mobile/models/gps_trail_point.dart';
import 'package:pocket_guide_mobile/widgets/poi_map_bottom_sheet.dart';

class MapTourScreen extends StatefulWidget {
  final TourDetail tourDetail;
  final bool isActiveMode; // true = active mode (with GPS), false = preview mode

  const MapTourScreen({
    super.key,
    required this.tourDetail,
    this.isActiveMode = false,
  });

  @override
  State<MapTourScreen> createState() => _MapTourScreenState();
}

class _MapTourScreenState extends State<MapTourScreen> with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final AuthService _authService = AuthService();

  late TourProgressService _progressService;
  TrailUploadManager? _trailManager;
  ProgressManager? _progressManager;

  int _selectedDay = 1;
  Position? _userPosition;
  bool _permissionDenied = false;
  List<TrailPoint> _trailPoints = []; // Trail points to display on map

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize with first day
    _selectedDay = 1;

    // Initialize everything in proper order
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    // Initialize services first (this loads progress)
    await _initializeServices();

    // Then initialize GPS and trail if in active mode
    if (widget.isActiveMode) {
      await _initializeGPS();
      await _loadExistingTrail();
    }
  }

  Future<void> _initializeServices() async {
    print('🔧 Initializing services for map tour...');

    var accessToken = await _authService.getAccessToken();
    print('🔑 Access token: ${accessToken?.substring(0, 20)}...');

    // Try to refresh token if it seems expired (you can add more logic here)
    if (accessToken == null) {
      print('❌ No access token found, cannot initialize services');
      return;
    }

    _progressService = TourProgressService(jwtToken: accessToken);

    // Initialize progress manager
    _progressManager = ProgressManager(
      progressService: _progressService,
      tourId: widget.tourDetail.metadata.tourId,
    );

    // Load progress for both active and preview mode
    print('📊 Loading progress...');
    final progressLoaded = await _progressManager!.loadProgress();

    if (progressLoaded != null) {
      print('✅ Progress loaded successfully: ${progressLoaded.completedCount}/${progressLoaded.totalPois}');
    } else {
      print('⚠️  Progress load returned null (might be 404 - no progress data yet)');
      print('ℹ️  This is normal for tours where no POI has been marked complete yet');
      print('ℹ️  Progress will be created when you mark the first POI as complete');

      // Don't show error dialog for 404 - it's expected for new tours
      // The backend will create progress data on the first POST /progress call
    }

    // Trigger rebuild to update marker colors
    if (mounted) {
      setState(() {});
    }
  }

  void _showTokenExpiredDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session Expired'),
        content: const Text(
          'Your session has expired. Please log out and log in again to continue using map features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeGPS() async {
    print('📍 Initializing GPS for active mode...');

    // Request location permission
    final hasPermission = await _locationService.hasPermission();
    if (!hasPermission) {
      final granted = await _locationService.requestPermission();

      if (!granted) {
        setState(() {
          _permissionDenied = true;
        });
        _showPermissionDeniedDialog();
        return;
      }
    }

    // Initialize trail upload manager (services are already initialized)
    _trailManager = TrailUploadManager(
      progressService: _progressService,
      tourId: widget.tourDetail.metadata.tourId,
    );
    _trailManager!.start();

    // Set up location update callback
    _locationService.onLocationUpdate = (Position position) {
      setState(() {
        _userPosition = position;
      });

      // Record trail point
      _trailManager?.addPoint(position);

      // Add to display trail (convert Position to TrailPoint for display)
      setState(() {
        _trailPoints.add(TrailPoint(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: DateTime.now(),
        ));
      });
    };

    // Start tracking
    final started = await _locationService.startTracking(isBackground: false);

    if (!started) {
      print('❌ Failed to start GPS tracking');
      _showLocationServiceDisabledDialog();
    } else {
      print('✅ GPS tracking started');
    }
  }

  // Load existing trail from backend
  Future<void> _loadExistingTrail() async {
    try {
      print('📥 Loading existing trail for tour: ${widget.tourDetail.metadata.tourId}');

      final trail = await _progressService.getTrail(
        tourId: widget.tourDetail.metadata.tourId,
      );

      setState(() {
        _trailPoints = trail.points;
      });

      print('✅ Loaded ${trail.points.length} trail points');
    } catch (e) {
      print('⚠️  Could not load existing trail: $e');
      // It's OK if there's no trail yet - user may be starting fresh
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'This app needs location access to track your position during the tour. '
          'Please grant location permission in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLocationServiceDisabledDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Service Disabled'),
        content: const Text(
          'Please enable location services in your device settings to use active tour mode.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.isActiveMode) return;

    if (state == AppLifecycleState.paused) {
      // App goes to background - switch to 30s intervals
      print('📱 App going to background, switching to 30s GPS intervals');
      _locationService.stopTracking();
      _locationService.startTracking(isBackground: true);
    } else if (state == AppLifecycleState.resumed) {
      // App comes to foreground - switch to 5s intervals
      print('📱 App resuming, switching to 5s GPS intervals');
      _locationService.stopTracking();
      _locationService.startTracking(isBackground: false);
    }
  }

  // Extract lat/lng from POI coordinates
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
      print('Error extracting coordinates for ${poi.poi}: $e');
    }
    return null;
  }

  // Get all POIs for the selected day
  List<TourPOI> _getPoisForDay(int day) {
    if (day <= 0 || day > widget.tourDetail.itinerary.length) {
      return [];
    }

    final tourDay = widget.tourDetail.itinerary[day - 1];
    return tourDay.pois.toList();
  }

  // Calculate center point of all POIs for initial camera position
  LatLng _calculateCenter() {
    final pois = _getPoisForDay(_selectedDay);
    final validLocations = pois
        .map((poi) => _getPoiLocation(poi))
        .where((loc) => loc != null)
        .cast<LatLng>()
        .toList();

    if (validLocations.isEmpty) {
      // Default to Rome if no valid coordinates
      return LatLng(41.9028, 12.4964);
    }

    final avgLat = validLocations.map((l) => l.latitude).reduce((a, b) => a + b) / validLocations.length;
    final avgLng = validLocations.map((l) => l.longitude).reduce((a, b) => a + b) / validLocations.length;

    return LatLng(avgLat, avgLng);
  }

  // Calculate zoom level to fit all POIs
  double _calculateZoom() {
    final pois = _getPoisForDay(_selectedDay);
    final validLocations = pois
        .map((poi) => _getPoiLocation(poi))
        .where((loc) => loc != null)
        .cast<LatLng>()
        .toList();

    if (validLocations.length < 2) {
      return 14.0; // Default zoom for single POI
    }

    // Calculate bounding box
    final lats = validLocations.map((l) => l.latitude).toList();
    final lngs = validLocations.map((l) => l.longitude).toList();

    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);

    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    // Rough zoom calculation (can be refined)
    if (maxDiff > 0.1) return 12.0;
    if (maxDiff > 0.05) return 13.0;
    if (maxDiff > 0.02) return 14.0;
    return 15.0;
  }

  // Build POI markers
  List<Marker> _buildMarkers() {
    final pois = _getPoisForDay(_selectedDay);
    final markers = <Marker>[];

    for (var i = 0; i < pois.length; i++) {
      final poi = pois[i];
      final location = _getPoiLocation(poi);

      if (location == null) continue;

      // Get POI ID - use poi.poiId if available, otherwise convert name
      final poiId = poi.poiId ?? _poiNameToId(poi.poi);

      // Check completion status
      final completed = _progressManager?.isPOICompleted(poiId, _selectedDay) ?? false;

      markers.add(
        Marker(
          point: location,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _onPoiTap(poi, i + 1, poiId),
            child: _buildMarkerWidget(i + 1, completed),
          ),
        ),
      );
    }

    // Add user location marker if in active mode and have position
    if (widget.isActiveMode && _userPosition != null) {
      markers.add(
        Marker(
          point: LatLng(_userPosition!.latitude, _userPosition!.longitude),
          width: 30,
          height: 30,
          child: _buildUserLocationMarker(),
        ),
      );
    }

    return markers;
  }

  // Convert POI name to kebab-case ID
  String _poiNameToId(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '') // Remove special chars
        .trim()
        .replaceAll(RegExp(r'\s+'), '-'); // Replace spaces with hyphens
  }

  // Build user location marker (blue dot)
  Widget _buildUserLocationMarker() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade600,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade600.withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.my_location,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }

  // Build marker widget with number
  Widget _buildMarkerWidget(int number, bool completed) {
    final color = completed ? Colors.green.shade600 : Colors.grey.shade400;

    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // Build polyline connecting POIs
  List<Polyline> _buildPolylines() {
    final polylines = <Polyline>[];

    // POI route line (planned route)
    final pois = _getPoisForDay(_selectedDay);
    final poiPoints = pois
        .map((poi) => _getPoiLocation(poi))
        .where((loc) => loc != null)
        .cast<LatLng>()
        .toList();

    if (poiPoints.length >= 2) {
      polylines.add(
        Polyline(
          points: poiPoints,
          color: Colors.blue.shade600.withValues(alpha: 0.5),
          strokeWidth: 3.0,
        ),
      );
    }

    // GPS trail line (actual path taken) - only in active mode
    if (widget.isActiveMode && _trailPoints.length >= 2) {
      polylines.add(
        Polyline(
          points: _trailPoints.map((tp) => tp.toLatLng()).toList(),
          color: Colors.green.shade600,
          strokeWidth: 4.0,
        ),
      );
    }

    return polylines;
  }

  // Handle POI marker tap
  void _onPoiTap(TourPOI poi, int number, String poiId) {
    print('🗺️ POI tapped: ${poi.poi} (Day $_selectedDay, #$number)');
    print('   POI ID: $poiId');
    print('   POI object poiId field: ${poi.poiId}');

    final completed = _progressManager?.isPOICompleted(poiId, _selectedDay) ?? false;
    print('   Completion status: $completed');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => POIMapBottomSheet(
        poi: poi,
        poiNumber: number,
        poiId: poiId,
        day: _selectedDay,
        tourId: widget.tourDetail.metadata.tourId,
        completed: completed,
        isActiveMode: widget.isActiveMode,
        onToggleCompletion: (newCompleted) async {
          await _togglePOICompletion(poiId, newCompleted);
        },
      ),
    );
  }

  // Toggle POI completion status
  Future<void> _togglePOICompletion(String poiId, bool completed) async {
    print('🔄 Toggling POI completion: $poiId (day $_selectedDay) -> $completed');

    final success = await _progressManager?.updatePOICompletion(
      poiId: poiId,
      day: _selectedDay,
      completed: completed,
    );

    print('   Update result: ${success == true ? "SUCCESS" : "FAILED"}');

    // Check the new status
    final newStatus = _progressManager?.isPOICompleted(poiId, _selectedDay);
    print('   New completion status from manager: $newStatus');

    if (mounted) {
      setState(() {}); // Rebuild to update marker color

      if (success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(completed ? 'POI marked as complete' : 'POI marked as incomplete'),
            duration: const Duration(seconds: 2),
            backgroundColor: completed ? Colors.green.shade600 : Colors.grey.shade600,
          ),
        );
      } else {
        // Failed to sync, but local update succeeded
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              completed
                  ? 'POI marked as complete (will sync when online)'
                  : 'POI marked as incomplete (will sync when online)',
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.orange.shade600,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isActiveMode ? 'Active Tour' : 'Tour Preview'),
        actions: [
          if (widget.tourDetail.itinerary.length > 1)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _buildDaySelector(),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _calculateCenter(),
              initialZoom: _calculateZoom(),
              minZoom: 10.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.pocketguide.mobile',
                maxZoom: 19,
              ),
              // Route polyline
              PolylineLayer(
                polylines: _buildPolylines(),
              ),
              // POI markers (includes user location if in active mode)
              MarkerLayer(
                markers: _buildMarkers(),
              ),
            ],
          ),

          // Permission denied warning
          if (widget.isActiveMode && _permissionDenied)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_off, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Location permission denied. Tour tracking disabled.',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Mode indicator
          Positioned(
            top: _permissionDenied ? 72 : 16,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.isActiveMode ? Colors.green.shade600 : Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isActiveMode ? Icons.navigation : Icons.visibility,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.isActiveMode ? 'Active' : 'Preview',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.isActiveMode && _locationService.isTracking)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'GPS Active',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (widget.isActiveMode && _trailPoints.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timeline,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Trail: ${_trailPoints.length} pts',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_progressManager?.currentProgress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade600,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_progressManager!.currentProgress!.completedCount}/${_progressManager!.currentProgress!.totalPois} POIs (${_progressManager!.getCompletionPercentage().toStringAsFixed(0)}%)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Center on user location button (active mode only)
          if (widget.isActiveMode && _userPosition != null && !_permissionDenied)
            Positioned(
              bottom: 24,
              right: 16,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: Colors.white,
                onPressed: _centerOnUserLocation,
                child: Icon(
                  Icons.my_location,
                  color: Colors.blue.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Center map on user's current location
  void _centerOnUserLocation() {
    if (_userPosition == null) return;

    _mapController.move(
      LatLng(_userPosition!.latitude, _userPosition!.longitude),
      16.0, // Zoom level for user location
    );
  }

  // Day selector widget
  Widget _buildDaySelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedDay,
          isDense: true,
          items: List.generate(
            widget.tourDetail.itinerary.length,
            (index) => DropdownMenuItem(
              value: index + 1,
              child: Text('Day ${index + 1}'),
            ),
          ),
          onChanged: (day) {
            if (day != null) {
              setState(() {
                _selectedDay = day;
              });
              // Re-center map on new day's POIs
              _mapController.move(_calculateCenter(), _calculateZoom());
            }
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationService.dispose();
    _trailManager?.dispose();
    _progressManager?.dispose();
    _mapController.dispose();
    super.dispose();
  }
}
