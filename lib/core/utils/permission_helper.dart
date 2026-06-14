import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Granular result of the permission + GPS check flow.
enum LocationPermissionStatus {
  gpsDisabled,                // Device GPS / location services are off
  foregroundDenied,           // "While using" denied — can re-request
  foregroundPermanentlyDenied, // Permanently blocked → must open app settings
  backgroundDenied,           // User chose "While using" only — guide to settings
  backgroundPermanentlyDenied, // "Always" permanently blocked → open app settings
  granted,                    // "Always Allow" — full background tracking OK
}

class PermissionHelper {
  /// Full flow used when the user taps START.
  /// GPS → foreground location → background location → notification
  Future<LocationPermissionStatus> requestAll() async {
    // ── 1. GPS / location service ─────────────────────────────────────────
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionStatus.gpsDisabled;
    }

    // ── 2. Foreground location ────────────────────────────────────────────
    var foreground = await ph.Permission.locationWhenInUse.status;
    if (foreground.isDenied) {
      foreground = await ph.Permission.locationWhenInUse.request();
    }
    if (foreground.isPermanentlyDenied) {
      return LocationPermissionStatus.foregroundPermanentlyDenied;
    }
    if (!foreground.isGranted) {
      return LocationPermissionStatus.foregroundDenied;
    }

    // ── 3. Background location (required for 60 s timer) ──────────────────
    // Must be requested AFTER foreground is granted (Android policy).
    var background = await ph.Permission.locationAlways.status;
    if (background.isDenied) {
      background = await ph.Permission.locationAlways.request();
    }
    if (background.isPermanentlyDenied) {
      return LocationPermissionStatus.backgroundPermanentlyDenied;
    }
    if (!background.isGranted) {
      // User selected "While using app" — not enough for background tracking.
      return LocationPermissionStatus.backgroundDenied;
    }

    // ── 4. Notification (Android 13+; no-op on older / iOS) ───────────────
    await ph.Permission.notification.request();

    return LocationPermissionStatus.granted;
  }

  /// Silent re-check — no permission dialogs shown.
  /// Called automatically when the app resumes after the user visited Settings.
  Future<LocationPermissionStatus> recheck() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionStatus.gpsDisabled;
    }
    final foreground = await ph.Permission.locationWhenInUse.status;
    if (foreground.isPermanentlyDenied) {
      return LocationPermissionStatus.foregroundPermanentlyDenied;
    }
    if (!foreground.isGranted) {
      return LocationPermissionStatus.foregroundDenied;
    }
    final background = await ph.Permission.locationAlways.status;
    if (background.isPermanentlyDenied) {
      return LocationPermissionStatus.backgroundPermanentlyDenied;
    }
    if (!background.isGranted) {
      return LocationPermissionStatus.backgroundDenied;
    }
    return LocationPermissionStatus.granted;
  }

  /// Opens the device Location / GPS settings screen.
  static Future<void> openGpsSettings() => Geolocator.openLocationSettings();

  /// Opens this app's permission settings page.
  static Future<void> openAppSettings() => ph.openAppSettings();
}
