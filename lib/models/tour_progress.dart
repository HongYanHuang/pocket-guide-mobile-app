class POICompletionStatus {
  final String poiId;
  final String poiName;
  final int day;
  final bool completed;
  final DateTime? completedAt;

  POICompletionStatus({
    required this.poiId,
    required this.poiName,
    required this.day,
    required this.completed,
    this.completedAt,
  });

  factory POICompletionStatus.fromJson(Map<String, dynamic> json) {
    return POICompletionStatus(
      poiId: json['poi_id'],
      poiName: json['poi_name'],
      day: json['day'],
      completed: json['completed'],
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
    );
  }
}

class TourProgress {
  final String tourId;
  final List<POICompletionStatus> completions;
  final int totalPois;
  final int completedCount;
  final double completionPercentage;

  TourProgress({
    required this.tourId,
    required this.completions,
    required this.totalPois,
    required this.completedCount,
    required this.completionPercentage,
  });

  factory TourProgress.fromJson(Map<String, dynamic> json) {
    return TourProgress(
      tourId: json['tour_id'],
      completions: (json['completions'] as List)
          .map((c) => POICompletionStatus.fromJson(c))
          .toList(),
      totalPois: json['total_pois'],
      completedCount: json['completed_count'],
      completionPercentage: json['completion_percentage'].toDouble(),
    );
  }
}
