abstract class TrackingState {}

class TrackingInitial extends TrackingState {}

class TrackingRunning extends TrackingState {
  final int count;
  TrackingRunning(this.count);
}

class TrackingStopped extends TrackingState {}

// ── Permission / GPS states ───────────────────────────────────────────────────

/// Device GPS / location services are turned off.
class TrackingGpsDisabled extends TrackingState {}

/// Foreground location permission was denied — can request again.
class TrackingForegroundPermissionDenied extends TrackingState {}

/// Permission is permanently blocked (foreground or background).
/// [isBackground] = true  → user chose "While Using" / background blocked
/// [isBackground] = false → foreground permanently blocked
class TrackingPermissionPermanentlyDenied extends TrackingState {
  final bool isBackground;
  TrackingPermissionPermanentlyDenied({required this.isBackground});
}

/// User granted "While Using App" only — background tracking needs "Always Allow".
class TrackingBackgroundPermissionDenied extends TrackingState {}

/// Generic service / runtime error.
class TrackingError extends TrackingState {
  final String message;
  TrackingError(this.message);
}
