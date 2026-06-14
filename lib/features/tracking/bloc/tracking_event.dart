abstract class TrackingEvent {}

/// Dispatched in the bloc constructor to check if the background service
/// survived an app kill — restores the correct button state on cold open.
class CheckTrackingStatus extends TrackingEvent {}

class StartTracking extends TrackingEvent {}

class StopTracking extends TrackingEvent {}

class LocationReceived extends TrackingEvent {
  final Map<String, dynamic> data;
  LocationReceived(this.data);
}

/// Dispatched by HomeScreen when the app resumes after the user visited
/// GPS or app-permission Settings, so the bloc can silently re-check state.
class RecheckPermissions extends TrackingEvent {}
