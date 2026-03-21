class ProgressUpdateRequest {
  final String poiId;
  final int day;
  final bool completed;

  ProgressUpdateRequest({
    required this.poiId,
    required this.day,
    required this.completed,
  });

  Map<String, dynamic> toJson() {
    return {
      'poi_id': poiId,
      'day': day,
      'completed': completed,
    };
  }
}
