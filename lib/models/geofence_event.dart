enum GeofenceEventType { poiEntered, poiCompleted }

class GeofenceEvent {
  final GeofenceEventType type;
  final String poiId;
  final String poiName;

  GeofenceEvent({
    required this.type,
    required this.poiId,
    required this.poiName,
  });
}
