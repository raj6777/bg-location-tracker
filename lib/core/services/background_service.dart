import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../dart_plugin_registrant.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/location_record.dart';
import '../constants/app_constants.dart';

class BackgroundServiceManager {
  final _service = FlutterBackgroundService();

  Future<void> configure() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: AppConstants.notificationChannelId,
        initialNotificationTitle: 'Location Tracker',
        initialNotificationContent: 'Tracking your location...',
        foregroundServiceNotificationId: 1,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  Future<bool> start() async {
    if (await _service.isRunning()) {
      _service.invoke('startTracking');
      return true;
    }
    final started = await _service.startService();
    if (!started) return false;

    // Wait for the background isolate to signal it is fully initialized before
    // sending 'startTracking'. The fixed 500 ms delay was not enough on cold
    // start — Hive init + box open can take longer, causing the message to
    // arrive before the listener is registered and be silently dropped.
    final completer = Completer<void>();
    StreamSubscription? sub;
    final timeout = Timer(const Duration(seconds: 8), () {
      sub?.cancel();
      if (!completer.isCompleted) completer.complete();
    });
    sub = _service.on('ready').listen((_) {
      timeout.cancel();
      sub?.cancel();
      if (!completer.isCompleted) completer.complete();
    });
    await completer.future;

    _service.invoke('startTracking');
    return true;
  }

  Future<void> stop() async {
    _service.invoke('stopService');
  }

  Future<bool> isRunning() => _service.isRunning();

  Stream<Map<String, dynamic>?> get onLocation => _service.on('onLocation');

  // Ask the background isolate (sole Hive writer) to delete a record.
  void deleteRecord(dynamic key) {
    _service.invoke('deleteRecord', {'key': key.toString()});
  }

  // Fires once per delete; carries the key that was deleted.
  Stream<Map<String, dynamic>?> get onRecordDeleted =>
      _service.on('recordDeleted');

  // Ask the background isolate to wipe the whole box.
  void clearRecords() {
    _service.invoke('clearRecords');
  }

  Stream<Map<String, dynamic>?> get onRecordsCleared =>
      _service.on('recordsCleared');
}

// Called on iOS when the app moves to background — return true to keep alive
@pragma('vm:entry-point')
bool _onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

// Background isolate entry point — must be top-level and annotated.
// This isolate is the SOLE WRITER to the Hive box; the UI isolate only reads.
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(LocationRecordAdapter());
  final box = await Hive.openBox<LocationRecord>(AppConstants.locationBoxName);

  // Hive init + box open are complete — tell the UI isolate we're ready.
  service.invoke('ready');

  Timer? timer;

  Future<void> capture() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final record = LocationRecord(
        latitude: pos.latitude,
        longitude: pos.longitude,
        timestamp: DateTime.now(),
        accuracy: pos.accuracy,
      );
      await box.add(record);
      // Emit live event across the isolate boundary to the UI
      service.invoke('onLocation', record.toMap());
    } catch (_) {
      // GPS unavailable this tick — skip silently
    }
  }

  service.on('startTracking').listen((_) async {
    timer?.cancel();
    await capture(); // immediate first fix
    timer = Timer.periodic(AppConstants.trackingInterval, (_) => capture());
  });

  // UI asks the background (sole Hive writer) to delete a single record.
  service.on('deleteRecord').listen((data) async {
    if (data == null) return;
    final keyStr = data['key'] as String?;
    if (keyStr != null) {
      final key = int.tryParse(keyStr);
      if (key != null) await box.delete(key);
      service.invoke('recordDeleted', {'key': keyStr});
    }
  });

  // UI asks the background to clear all records.
  service.on('clearRecords').listen((_) async {
    await box.clear();
    service.invoke('recordsCleared');
  });

  // stopService stops the timer AND the foreground service itself.
  service.on('stopService').listen((_) async {
    timer?.cancel();
    if (service is AndroidServiceInstance) {
      service.stopSelf();
    }
  });
}
