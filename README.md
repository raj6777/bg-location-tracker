<img width="1080" height="2412" alt="9" src="https://github.com/user-attachments/assets/86aa20c3-a29e-44da-8ebf-3d1a486a1eb7" />
<img width="1080" height="2412" alt="8" src="https://github.com/user-attachments/assets/25346b74-6cab-475d-98f8-9bcde441055b" />
<img width="716" height="1600" alt="7" src="https://github.com/user-attachments/assets/10addf70-0f7a-4fcb-ad8a-e3ef95e48efd" />
<img width="716" height="1600" alt="6" src="https://github.com/user-attachments/assets/260dc035-19a7-443e-b5c4-b313d3afc1f8" />
<img width="716" height="1600" alt="5" src="https://github.com/user-attachments/assets/b0c28e30-4df3-451a-9371-df299bdeb65b" />
<img width="716" height="1600" alt="4" src="https://github.com/user-attachments/assets/e7b74a87-6e51-4dfd-b9f0-ce98caba0d84" />
<img width="1080" height="2412" alt="3" src="https://github.com/user-attachments/assets/18a0ae01-acf7-442f-a272-3202fe7f5556" />
<img width="716" height="1600" alt="2" src="https://github.com/user-attachments/assets/b9c2334b-22bf-490b-a25d-949b93e49ddf" />
<img width="1080" height="2412" alt="1" src="https://github.com/user-attachments/assets/78031292-96b2-457b-9026-a7a7604f488a" />
﻿# Background Location Tracker
A production-quality Flutter app that continuously records GPS location **every 60 seconds** — even when backgrounded, minimized, screen-locked, or force-killed (Android). Features real-time battery percentage via a native Platform Channel, local storage with Hive, and BLoC-based state management.
## Features
- 📍 **Continuous Location Tracking** — Records GPS every 60 seconds in a background foreground service
- 🔌 **Battery Level Monitor** — Real-time battery percentage via native Platform Channel
- 📝 **Local Storage** — Persistent location history with Hive
- 🎨 **BLoC Architecture** — Clean state management with flutter_bloc
- 🔐 **Permission Handling** — Complete location, background location, and notification permission flow
- 📸 **Location List View** — Browse recorded GPS points with timestamp and accuracy
- 🏗️ **Scalable Architecture** — Separation of concerns with core, data, and features layers
- 🔄 **Multi-Isolate Safe** — Background isolate as sole writer to prevent Hive corruption
- 📱 **Cross-Platform** — Native implementations for Android (Kotlin) and iOS (Swift)
---
## Getting Started
### Prerequisites
- Flutter SDK 3.13+
- Dart 3.13+
- For Android: API 29+ (or API 34+ for full foreground service location type support)
- For iOS: iOS 13+
### Installation
1. **Clone the repository**
   `bash
   git clone <repo-url>
   cd task_thinkalternate
   `
2. **Install dependencies**
   `bash
   flutter pub get
   `
3. **Generate Hive adapters** (required for LocationRecord model)
   `bash
   flutter pub run build_runner build
   `
4. **Run the app**
   `bash
   flutter run
   `
---
## Project Structure
\\\
lib/
├── main.dart                               # App entry point, Hive initialization
├── app.dart                                # MaterialApp configuration
├── dart_plugin_registrant.dart            # Generated plugin registry
│
├── core/
│   ├── constants/
│   │   └── app_constants.dart             # App-wide constants (channel names, intervals)
│   ├── di/
│   │   └── service_locator.dart           # Dependency injection with get_it
│   ├── platform/
│   │   └── battery_channel.dart           # Platform channel wrapper for battery
│   ├── services/
│   │   ├── location_service.dart          # Geolocator wrapper for GPS
│   │   ├── background_service.dart        # Background service configuration
│   │   └── notification_service.dart      # Foreground notification setup
│   └── utils/
│       └── permission_helper.dart         # Location and notification permission requests
│
├── data/
│   ├── models/
│   │   ├── location_record.dart           # Hive model for GPS records
│   │   └── location_record.g.dart         # Generated Hive adapter
│   └── repositories/
│       └── location_repository.dart       # Repository for location storage/retrieval
│
└── features/
    ├── tracking/
    │   ├── bloc/
    │   │   ├── tracking_bloc.dart         # Main tracking BLoC
    │   │   ├── tracking_event.dart        # Tracking events
    │   │   └── tracking_state.dart        # Tracking states
    │   └── view/
    │       └── home_screen.dart           # Home UI with START/STOP controls
    │
    ├── battery/
    │   ├── cubit/
    │   │   ├── battery_cubit.dart         # Battery level polling logic
    │   │   └── battery_state.dart         # Battery states
    │   └── widgets/
    │       └── battery_indicator.dart     # Battery display widget
    │
    └── locations/
        ├── bloc/
        │   ├── locations_bloc.dart        # Locations list BLoC
        │   ├── locations_event.dart       # Locations events
        │   └── locations_state.dart       # Locations states
        └── view/
            └── locations_list_screen.dart # Recorded locations display
android/app/src/main/
├── kotlin/.../MainActivity.kt             # Battery channel implementation (Kotlin)
└── AndroidManifest.xml                    # Permissions and service declarations
ios/Runner/
├── AppDelegate.swift                      # Battery channel implementation (Swift)
└── Info.plist                             # Background modes and usage descriptions
\\\
---
## Tech Stack
| Concern | Package | Version | Purpose |
|---------|---------|---------|---------|
| State Management | flutter_bloc | 9.1.1 | BLoC + Cubit for clean architecture |
| Location Services | geolocator | 13.0.2 | GPS retrieval and permission handling |
| Background Service | flutter_background_service | 5.0.9 | Persistent foreground service for tracking |
| Notifications | flutter_local_notifications | 18.0.1 | Foreground service persistent notification |
| Local Storage | hive, hive_flutter | 2.2.3, 1.1.0 | Fast typed key-value storage |
| Geocoding | geocoding | 3.0.0 | Reverse geocoding (lat/lng → address) |
| Permissions | permission_handler | 11.4.0 | Runtime permission requests |
| DI | get_it | 8.0.3 | Service locator for dependency injection |
| UI | flutter_slidable | 4.0.3 | Swipeable list items for locations |
---
## Architecture & Key Concepts
### Multi-Isolate Data Flow
The app uses flutter_background_service which runs location capture in a **separate Dart isolate**:
\\\
[Background Isolate — flutter_background_service]
  Timer (every 60s)
    → Geolocator.getCurrentPosition()
    → LocationRepository.add(LocationRecord)  ← SOLE WRITER
    → service.invoke('onLocation', map)       ← emits to UI
[UI Isolate]
  TrackingBloc
    ← service.on('onLocation')                 ← listens for live updates
  LocationsBloc
    ← LocationRepository.getAll()              ← reads stored records
\\\
**Critical Design:** The background isolate is the only writer to Hive to prevent data corruption from concurrent access.
### Native Platform Channel
Battery level is fetched via a native platform channel (no third-party battery package):
- **Android:** BatteryManager.BATTERY_PROPERTY_CAPACITY in MainActivity.kt
- **iOS:** UIDevice.current.batteryLevel × 100 in AppDelegate.swift
- **Channel Name:** com.example.tracker/battery
### Foreground Service
On Android, a persistent foreground service (with notification) keeps the app tracking even when backgrounded or screen-locked. This is required to survive Android's battery optimization.
### iOS Limitations
iOS does not allow arbitrary timers to run indefinitely after force-quit. The app uses UIBackgroundModes for best-effort background execution. For guaranteed periodic tracking on iOS, implement significant-location-change monitoring or region-based geofencing.
---
## Usage
### Starting Location Tracking
1. Tap **START TRACKING** on the home screen
2. Grant location, background location, and notification permissions
3. The foreground service starts immediately
4. Location is captured immediately and then every 60 seconds
5. Battery percentage updates every 15 seconds
### Stopping Tracking
1. Tap **STOP TRACKING**
2. The timer is cancelled and the foreground service stops
3. Recorded locations remain in local storage
### Viewing Recorded Locations
1. Navigate to the **Locations** tab
2. Scroll through all recorded GPS points
3. Each entry shows: latitude, longitude, timestamp, and accuracy (in meters)
4. Tap the **Clear All** button to delete the entire history
---
## Platform Configuration
### Android
**Permissions** in AndroidManifest.xml:
- ACCESS_FINE_LOCATION — Precise GPS
- ACCESS_COARSE_LOCATION — Network-based location
- ACCESS_BACKGROUND_LOCATION — Background tracking
- FOREGROUND_SERVICE — Required for foreground service
- FOREGROUND_SERVICE_LOCATION — Location foreground service type (API 34+)
- POST_NOTIFICATIONS — Permission to show notifications
- WAKE_LOCK — Prevent device sleep during capture
- RECEIVE_BOOT_COMPLETED — Auto-start on device reboot
**Service Declaration:**
\\\xml
<service
    android:name="id.flutter.flutter_background_service.BackgroundService"
    android:foregroundServiceType="location"
    android:exported="false" />
\\\
### iOS
**Info.plist Configuration:**
\\\xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We track your location every 60 seconds during your trip.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We continue recording your location in the background.</string>
<key>UIBackgroundModes</key>
<array>
  <string>location</string>
  <string>fetch</string>
  <string>processing</string>
</array>
\\\
---
## Development
### Generate Code
After modifying models, regenerate adapters:
\\\ash
flutter pub run build_runner build --delete-conflicting-outputs
\\\
### Run Tests
\\\ash
flutter test
\\\
### Build APK (Android)
\\\ash
flutter build apk --release
\\\
### Build IPA (iOS)
\\\ash
flutter build ios --release
\\\
---
## Architecture Decisions
### Why BLoC?
- Clear separation of business logic from UI
- Testable and scalable
- Easy to explain in technical interviews
- Supports state immutability
### Why Hive?
- Zero SQL boilerplate
- Type-safe with adapters
- Fast performance
- The only caveat: single-writer (background isolate) to prevent corruption
### Why Foreground Service?
- Android's background app limitations require a visible persistent notification
- Alternative: JobScheduler (less reliable for fixed 60s intervals)
### Why Platform Channel for Battery?
- Task explicitly forbids third-party battery packages
- Direct access to native APIs provides accuracy and control
---
## Troubleshooting
### App stops tracking when minimized (Android)
- Ensure the foreground service notification is visible
- Check that FOREGROUND_SERVICE_LOCATION permission is granted
- Verify battery optimization settings in device settings don't restrict the app
### iOS not tracking in background
- iOS does not guarantee fixed 60-second intervals after force-quit
- Background modes are best-effort; use significant-location-change for reliable background tracking
- Test with the app in the background task queue, not force-quit
### Hive corruption errors
- Ensure only the background isolate writes to the Hive box
- Never call box.add() from multiple isolates simultaneously
- If corrupted, delete the app data and restart
### Location permission keeps being requested
- Check AndroidManifest.xml has all required location permissions
- On Android 12+, ensure POST_NOTIFICATIONS permission is granted
- Verify app has permission granted in device settings
---
## License
This project is provided as a reference implementation for background location tracking in Flutter.
---
## Support & Contributions
For issues, questions, or suggestions, please open an issue in the repository.
