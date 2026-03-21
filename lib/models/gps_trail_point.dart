import 'package:latlong2/latlong.dart';

class GPSPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;

  GPSPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
  });

  Map<String, dynamic> toJson() {
    return {
      'lat': latitude,
      'lng': longitude,
      'timestamp': timestamp.toIso8601String(),
      if (accuracy != null) 'accuracy': accuracy,
    };
  }
}

class TrailPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  TrailPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory TrailPoint.fromJson(Map<String, dynamic> json) {
    return TrailPoint(
      latitude: json['lat'].toDouble(),
      longitude: json['lng'].toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  // Convert to LatLng for flutter_map
  LatLng toLatLng() {
    return LatLng(latitude, longitude);
  }
}

class TourTrail {
  final String tourId;
  final List<TrailPoint> points;
  final int totalPoints;

  TourTrail({
    required this.tourId,
    required this.points,
    required this.totalPoints,
  });

  factory TourTrail.fromJson(Map<String, dynamic> json) {
    return TourTrail(
      tourId: json['tour_id'],
      points: (json['points'] as List)
          .map((p) => TrailPoint.fromJson(p))
          .toList(),
      totalPoints: json['total_points'],
    );
  }
}
