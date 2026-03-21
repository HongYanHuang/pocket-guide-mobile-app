import 'package:pocket_guide_mobile/models/gps_trail_point.dart';

class TrailUploadRequest {
  final List<GPSPoint> points;

  TrailUploadRequest({required this.points});

  Map<String, dynamic> toJson() {
    return {
      'points': points.map((p) => p.toJson()).toList(),
    };
  }
}
