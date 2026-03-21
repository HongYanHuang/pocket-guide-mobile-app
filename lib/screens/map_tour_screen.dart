import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:pocket_guide_api/pocket_guide_api.dart';

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

class _MapTourScreenState extends State<MapTourScreen> {
  final MapController _mapController = MapController();
  int _selectedDay = 1;

  @override
  void initState() {
    super.initState();
    // Initialize with first day
    _selectedDay = 1;
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

      markers.add(
        Marker(
          point: location,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _onPoiTap(poi, i + 1),
            child: _buildMarkerWidget(i + 1, false), // TODO: Add completion status
          ),
        ),
      );
    }

    return markers;
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
    final pois = _getPoisForDay(_selectedDay);
    final points = pois
        .map((poi) => _getPoiLocation(poi))
        .where((loc) => loc != null)
        .cast<LatLng>()
        .toList();

    if (points.length < 2) return [];

    return [
      Polyline(
        points: points,
        color: Colors.blue.shade600,
        strokeWidth: 3.0,
      ),
    ];
  }

  // Handle POI marker tap
  void _onPoiTap(TourPOI poi, int number) {
    print('🗺️ POI tapped: ${poi.poi} (Day $_selectedDay, #$number)');
    // TODO: Show bottom sheet with POI details
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
              // POI markers
              MarkerLayer(
                markers: _buildMarkers(),
              ),
              // TODO: Add user location marker in active mode
              // TODO: Add GPS trail polyline in active mode
            ],
          ),

          // Mode indicator
          Positioned(
            top: 16,
            left: 16,
            child: Container(
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
          ),
        ],
      ),
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
    _mapController.dispose();
    super.dispose();
  }
}
