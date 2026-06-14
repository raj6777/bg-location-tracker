# Background Location Tracker (Flutter + BLoC)

A Flutter app that records the device GPS location **every 60 seconds** — even when backgrounded, minimized, screen-locked, or force-killed (Android) — and shows the **live battery %** through a **native Platform Channel** (no third-party battery package).

> **Hiring challenge note:** AI may assist, but you must explain every line in Round 2. This README is built **phase-wise** so you can implement → understand → explain one chunk at a time. Don't paste the whole master prompt blindly; build a phase, read it, then move on.

---

## 0. How to use this README

This file contains:
1. A **Master Prompt** — paste into Claude Code / Cursor / any AI agent to scaffold the full project.
2. **Per-phase prompts** — smaller, safer prompts to build and verify one chunk at a time (recommended).
3. **Project structure**, **tech stack**, **native code**, and **platform config**.
4. A **Round-2 explanation cheat-sheet** so you can defend the architecture.

Recommended flow: run the Master Prompt to scaffold, then go phase by phase using the per-phase prompts to fill in and test each chunk.

---

## 1. Master Prompt (paste this)

```text
You are a senior Flutter engineer. Build a production-quality "Background Location Tracker"
app. Follow these rules exactly.

GOAL
- Track device GPS every 60 seconds and persist each fix locally.
- Continue tracking when the app is backgrounded, minimized, screen-locked, and
  force-killed on Android. On iOS, implement the maximum reliable background behavior
  and document the platform limitation honestly.
- Show the current battery percentage on the home screen using a NATIVE Platform Channel
  (Android Kotlin + iOS Swift). Do NOT use any third-party battery package.

ARCHITECTURE
- State management: flutter_bloc (Bloc + Cubit). No setState for business logic.
- Layering: core/ (platform, services, utils, di), data/ (models, repositories),
  features/ (tracking, battery, locations) — each feature has its own bloc/ and view/.
- Dependency injection with get_it.
- The 60s capture + persistence runs in a BACKGROUND ISOLATE via flutter_background_service
  as a FOREGROUND SERVICE (persistent notification). The background isolate is the single
  writer to local storage. The UI isolate only reads, and listens to live updates via
  service.on(...) events.

DATA
- Store each fix as { latitude, longitude, timestamp, accuracy } using Hive.
- LocationRecord is a Hive model with a typed adapter.
- LocationRepository wraps the box (add, getAll, clear, watch).

FEATURES
- Home screen: battery % (auto-refresh every ~15s), tracking status, START / STOP buttons,
  count of recorded fixes.
- Locations screen: scrollable list of records (lat, lng, time, accuracy). Add a map view
  (google_maps_flutter) as a second tab if an API key is configured; otherwise list only.
- START -> request permissions (location, background location, notifications) -> start
  foreground service -> capture immediately, then every 60s.
- STOP -> stop the service, finalize the session.

PLATFORM CHANNEL (battery)
- Channel name: "com.example.tracker/battery", method "getBatteryLevel" returning Int (0-100).
- Android: BatteryManager.BATTERY_PROPERTY_CAPACITY in MainActivity.kt.
- iOS: UIDevice.current.batteryLevel * 100 in AppDelegate.swift.

ANDROID CONFIG
- Permissions: ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, ACCESS_BACKGROUND_LOCATION,
  FOREGROUND_SERVICE, FOREGROUND_SERVICE_LOCATION, POST_NOTIFICATIONS, WAKE_LOCK,
  RECEIVE_BOOT_COMPLETED.
- Foreground service must declare android:foregroundServiceType="location" (API 34+).
- Configure flutter_background_service for foreground mode + autoStart on boot.

iOS CONFIG
- Info.plist: NSLocationWhenInUseUsageDescription, NSLocationAlwaysAndWhenInUseUsageDescription,
  UIBackgroundModes = [location, fetch, processing].
- Document clearly that iOS cannot run a fixed 60s timer indefinitely after force-kill;
  use allowsBackgroundLocationUpdates + significant-change as the documented fallback.

DELIVERABLES
- Full, compiling code for every file.
- Inline comments explaining WHY for the tricky parts (isolate boundary, foreground service,
  permission flow, platform channel).
- A short SUMMARY.md explaining the data flow between the background isolate and the UI.

Use clean, readable Dart. Handle permission denial gracefully. Do not invent packages.
```

---

## 2. Tech Stack

| Concern | Choice | Why |
|---|---|---|
| State management | `flutter_bloc` | Required by the task; clear event→state flow, easy to explain |
| Location | `geolocator` | Reliable cross-platform GPS + permission helpers |
| Background execution | `flutter_background_service` | Runs a foreground service that survives backgrounding & Android force-kill |
| Local notification | `flutter_local_notifications` | Mandatory persistent notification for the foreground service |
| Local storage | `hive` + `hive_flutter` | Fast, no SQL boilerplate (SQLite via `sqflite` is a valid alternative — see §8) |
| Permissions | `permission_handler` | Background location + notification runtime requests |
| DI | `get_it` | Decouples services from widgets |
| Map (optional) | `google_maps_flutter` | Map view of recorded points |
| Battery | **Platform Channel only** | Task forbids third-party battery packages |

Add them with (lets pub resolve current versions — verify on pub.dev):

```bash
flutter pub add flutter_bloc geolocator flutter_background_service \
  flutter_local_notifications hive hive_flutter permission_handler get_it
flutter pub add --dev hive_generator build_runner
# optional map:
flutter pub add google_maps_flutter
```

---

## 3. Project Structure

```
lib/
├── main.dart                          # init Hive, register adapter, configure bg service, runApp
├── app.dart                           # MaterialApp + BlocProviders
│
├── core/
│   ├── constants/
│   │   └── app_constants.dart         # channel name, box name, interval (60s)
│   ├── di/
│   │   └── service_locator.dart       # get_it registrations
│   ├── platform/
│   │   └── battery_channel.dart       # MethodChannel wrapper (Dart side)
│   ├── services/
│   │   ├── location_service.dart      # geolocator wrapper (permission + getCurrentPosition)
│   │   ├── background_service.dart    # flutter_background_service config + onStart entrypoint
│   │   └── notification_service.dart  # foreground notification channel
│   └── utils/
│       └── permission_helper.dart     # location / background / notification requests
│
├── data/
│   ├── models/
│   │   ├── location_record.dart       # @HiveType model
│   │   └── location_record.g.dart     # generated adapter (build_runner)
│   └── repositories/
│       └── location_repository.dart   # add / getAll / clear / watch over the Hive box
│
└── features/
    ├── tracking/
    │   ├── bloc/
    │   │   ├── tracking_bloc.dart
    │   │   ├── tracking_event.dart    # StartTracking, StopTracking, LocationReceived
    │   │   └── tracking_state.dart    # TrackingInitial / Running / Stopped
    │   └── view/
    │       └── home_screen.dart       # battery + START/STOP + status + count
    │
    ├── battery/
    │   ├── cubit/
    │   │   ├── battery_cubit.dart     # polls BatteryChannel every ~15s
    │   │   └── battery_state.dart
    │   └── widgets/
    │       └── battery_indicator.dart
    │
    └── locations/
        ├── bloc/
        │   ├── locations_bloc.dart
        │   ├── locations_event.dart   # LoadLocations, ClearLocations
        │   └── locations_state.dart
        └── view/
            ├── locations_list_screen.dart
            └── locations_map_screen.dart   # optional

android/app/src/main/kotlin/.../MainActivity.kt   # battery MethodChannel
android/app/src/main/AndroidManifest.xml          # permissions + foreground service
ios/Runner/AppDelegate.swift                       # battery MethodChannel
ios/Runner/Info.plist                              # background modes + usage strings
```

---

## 4. The hard part — data flow across the isolate boundary

`flutter_background_service` runs your capture loop in a **separate isolate** from the UI. Memory is **not** shared. So:

- **Background isolate** = the *only* writer. It opens Hive, captures GPS every 60s, writes the record, then emits a live event (`service.invoke('onLocation', map)`).
- **UI isolate** reads Hive for the full history and listens to `service.on('onLocation')` for live updates while the app is open.
- Never write to the same Hive box from both isolates at once — that is the #1 cause of corruption here.

```
[Background isolate]                         [UI isolate]
 Timer(60s)                                   TrackingBloc
   -> LocationService.getPosition()             listens service.on('onLocation')
   -> box.add(LocationRecord)        --event--> updates count / live marker
   -> service.invoke('onLocation')             LocationsBloc reads box.getAll() on open
```

This separation is exactly what you'll be asked to explain in Round 2 — know it cold.

---

## 5. Phase-wise / chunk-wise plan

Each phase has a **goal**, **chunks**, and a **paste-ready prompt**. Build, run, verify, then continue.

### Phase 0 — Scaffold & dependencies
**Goal:** project created, packages added, folders in place.
**Chunks:** create project → add packages → create the folder tree from §3 → set up `get_it` skeleton.
```text
Create a Flutter app named bg_location_tracker. Add flutter_bloc, geolocator,
flutter_background_service, flutter_local_notifications, hive, hive_flutter,
permission_handler, get_it, and dev deps hive_generator + build_runner. Create the
folder structure I provide. Add an empty service_locator.dart with a setupLocator() stub.
```

### Phase 1 — Battery Platform Channel (native)
**Goal:** real battery % from native, no package.
**Chunks:** Dart `BatteryChannel` → Kotlin handler → Swift handler → `BatteryCubit` polling every 15s → `BatteryIndicator` widget.
```text
Implement a battery platform channel named "com.example.tracker/battery" with method
"getBatteryLevel" returning an Int 0-100. Provide: Dart BatteryChannel wrapper,
Kotlin MainActivity using BatteryManager.BATTERY_PROPERTY_CAPACITY, Swift AppDelegate using
UIDevice.batteryLevel. Then a BatteryCubit that polls every 15s and a BatteryIndicator widget.
No third-party battery package.
```

### Phase 2 — Data layer
**Goal:** persistable model + repository.
**Chunks:** `LocationRecord` Hive model (lat, lng, timestamp, accuracy) → run build_runner → `LocationRepository` (add/getAll/clear/watch) → init Hive in `main.dart`.
```text
Create a Hive model LocationRecord with double latitude, double longitude,
DateTime timestamp, double accuracy, a typed adapter, toMap/fromMap, and a
LocationRepository over a box named "locations" with add, getAll, clear, watch.
Initialize Hive and register the adapter in main.dart. Run build_runner.
```

### Phase 3 — Location & permissions service
**Goal:** get a GPS fix on demand with proper permissions.
**Chunks:** `PermissionHelper` (location → background location → notifications) → `LocationService.getCurrentPosition()` with high accuracy.
```text
Create PermissionHelper that requests location, then background location, then notification
permission, returning a clear result. Create LocationService.getCurrentPosition() using
geolocator with high accuracy and a sensible timeout. Handle denied/forever-denied gracefully.
```

### Phase 4 — Background foreground service (the core)
**Goal:** 60s capture loop that survives background & force-kill (Android).
**Chunks:** `NotificationService` channel → `background_service.dart` config (foreground mode, autoStart) → `@pragma('vm:entry-point') onStart` with Hive init, `startTracking`/`stopTracking` listeners, immediate fix + `Timer.periodic(60s)`, write to box, `service.invoke('onLocation', ...)`.
```text
Configure flutter_background_service as a FOREGROUND service with a persistent notification.
In the onStart entrypoint (annotated @pragma('vm:entry-point')): ensure DartPluginRegistrant,
init Hive + register adapter + open the locations box. On 'startTracking', capture one fix
immediately then every 60s, write a LocationRecord, and service.invoke('onLocation', record map).
On 'stopTracking', cancel the timer. Keep the background isolate the only writer.
```

### Phase 5 — Tracking BLoC + Home UI
**Goal:** START/STOP wired to the service; live status.
**Chunks:** events (`StartTracking`, `StopTracking`, `LocationReceived`) → states (`Initial`/`Running`/`Stopped` with count) → bloc subscribes to `service.on('onLocation')` → `HomeScreen` with battery, status, START/STOP, count.
```text
Create TrackingBloc with events StartTracking, StopTracking, LocationReceived and states
TrackingInitial, TrackingRunning(count), TrackingStopped. On StartTracking: request permissions,
start the service, invoke 'startTracking', subscribe to service.on('onLocation') to dispatch
LocationReceived. On StopTracking: invoke 'stopTracking', stop service. Build HomeScreen with
BatteryIndicator, status text, START/STOP buttons, and live fix count.
```

### Phase 6 — Locations list / map
**Goal:** review recorded data.
**Chunks:** `LocationsBloc` (`LoadLocations`, `ClearLocations`) reading the repo → `LocationsListScreen` (lat, lng, formatted time, accuracy) → optional `LocationsMapScreen` with markers.
```text
Create LocationsBloc with LoadLocations and ClearLocations reading LocationRepository.
Build LocationsListScreen showing each record's lat, lng, formatted timestamp, accuracy,
with a clear-all action. Add an optional LocationsMapScreen using google_maps_flutter that
plots all recorded points (guard behind an API key check).
```

### Phase 7 — Platform config & force-kill hardening
**Goal:** permissions, FGS type, boot restart, iOS honesty.
**Chunks:** AndroidManifest permissions + `foregroundServiceType="location"` + boot receiver → iOS Info.plist usage strings + `UIBackgroundModes` → test matrix below.
```text
Update AndroidManifest with all location/foreground/notification/boot permissions and declare
the service with android:foregroundServiceType="location". Enable autoStart on boot. Update
iOS Info.plist with the two location usage descriptions and UIBackgroundModes [location, fetch,
processing]. Add a SUMMARY.md documenting the iOS force-kill limitation and the significant-change
fallback.
```

### Phase 8 — Verify, polish, document
**Goal:** prove it works + prep Round 2.
**Chunks:** run the test matrix → clean up logs → write `SUMMARY.md` (data flow + decisions) → self-quiz from §9.

---

## 6. Key native code

**`lib/core/platform/battery_channel.dart`**
```dart
import 'package:flutter/services.dart';

class BatteryChannel {
  static const _channel = MethodChannel('com.example.tracker/battery');

  Future<int> getBatteryLevel() async {
    final level = await _channel.invokeMethod<int>('getBatteryLevel');
    return level ?? -1;
  }
}
```

**`android/app/src/main/kotlin/.../MainActivity.kt`**
```kotlin
import android.content.Context
import android.os.BatteryManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.example.tracker/battery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                if (call.method == "getBatteryLevel") {
                    val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                    val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                    if (level != -1) result.success(level)
                    else result.error("UNAVAILABLE", "Battery level unavailable", null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
```

**`ios/Runner/AppDelegate.swift`**
```swift
import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let batteryChannel = FlutterMethodChannel(
      name: "com.example.tracker/battery",
      binaryMessenger: controller.binaryMessenger)

    batteryChannel.setMethodCallHandler { (call, result) in
      guard call.method == "getBatteryLevel" else {
        result(FlutterMethodNotImplemented); return
      }
      let device = UIDevice.current
      device.isBatteryMonitoringEnabled = true
      if device.batteryState == .unknown {
        result(FlutterError(code: "UNAVAILABLE",
                            message: "Battery info unavailable", details: nil))
      } else {
        result(Int(device.batteryLevel * 100))
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

**Background entrypoint shape (`background_service.dart`)**
```dart
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(LocationRecordAdapter());
  final box = await Hive.openBox<LocationRecord>('locations');

  Timer? timer;

  Future<void> capture() async {
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final record = LocationRecord(
      latitude: pos.latitude,
      longitude: pos.longitude,
      timestamp: DateTime.now(),
      accuracy: pos.accuracy,
    );
    await box.add(record);
    service.invoke('onLocation', record.toMap());
  }

  service.on('startTracking').listen((_) async {
    timer?.cancel();
    await capture();                       // immediate first fix
    timer = Timer.periodic(const Duration(seconds: 60), (_) => capture());
  });

  service.on('stopTracking').listen((_) => timer?.cancel());
}
```

---

## 7. Platform config

**AndroidManifest.xml** (inside `<manifest>` / `<application>`)
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>

<!-- The foreground service MUST declare its type on API 34+ -->
<service
    android:name="id.flutter.flutter_background_service.BackgroundService"
    android:foregroundServiceType="location"
    android:exported="false" />
```

**iOS Info.plist**
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We track your location to record your trip every 60 seconds.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We continue recording your location in the background.</string>
<key>UIBackgroundModes</key>
<array>
  <string>location</string>
  <string>fetch</string>
  <string>processing</string>
</array>
```

> **iOS honesty (put this in SUMMARY.md):** iOS does **not** allow an arbitrary 60-second timer to run indefinitely in the background, and it does **not** relaunch your app after the user force-quits it the way Android does. The reliable iOS fallback is `allowsBackgroundLocationUpdates` + significant-location-change / region monitoring, which wakes the app on meaningful movement rather than on a fixed clock. State this limitation rather than claiming parity with Android — it's the correct engineering answer and it reads well in Round 2.

---

## 8. Hive vs SQLite

Hive is chosen for speed and zero SQL. The one caveat is the multi-isolate boundary (§4): keep the background isolate as the sole writer. If you prefer `sqflite` (SQLite), the architecture is identical — just swap `LocationRepository`'s implementation. SQLite tolerates concurrent file access slightly more gracefully, but adds SQL boilerplate. Either satisfies the task; be ready to justify your pick.
