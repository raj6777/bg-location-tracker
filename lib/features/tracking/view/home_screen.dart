import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../bloc/tracking_bloc.dart';
import '../bloc/tracking_event.dart';
import '../bloc/tracking_state.dart';
import '../../battery/cubit/battery_cubit.dart';
import '../../battery/cubit/battery_state.dart';
import '../../battery/widgets/battery_indicator.dart';
import '../../locations/view/locations_list_screen.dart';
import '../../../core/utils/permission_helper.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => TrackingBloc()),
        BlocProvider(create: (_) => BatteryCubit()),
      ],
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> with WidgetsBindingObserver {
  bool _waitingForSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle != AppLifecycleState.resumed || !_waitingForSettings) return;
    _waitingForSettings = false;
    context.read<TrackingBloc>().add(RecheckPermissions());
  }

  void _sendToSettings(Future<void> Function() openFn) {
    _waitingForSettings = true;
    openFn();
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showGpsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.gps_off, size: 44, color: Colors.teal),
        title: const Text('GPS is Disabled'),
        content: const Text(
          'Location services are turned off on your device.\n\n'
          'Please enable GPS so the app can record your position every 60 seconds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Now'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.settings),
            label: const Text('Enable GPS'),
            onPressed: () {
              Navigator.pop(context);
              _sendToSettings(Geolocator.openLocationSettings);
            },
          ),
        ],
      ),
    );
  }

  void _showForegroundDeniedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.location_off, size: 44, color: Colors.teal),
        title: const Text('Location Permission Required'),
        content: const Text(
          'This app needs location access to record your GPS position.\n\n'
          'Tap "Grant Permission" and select "While using the app" or '
          '"Allow all the time" when prompted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.location_on),
            label: const Text('Grant Permission'),
            onPressed: () {
              Navigator.pop(context);
              context.read<TrackingBloc>().add(StartTracking());
            },
          ),
        ],
      ),
    );
  }

  void _showBackgroundDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.location_searching, size: 44, color: Colors.orange),
        title: const Text('"Always Allow" Needed'),
        content: const Text(
          'You selected "While Using App", but background tracking requires '
          '"Allow all the time".\n\n'
          'Go to:\nSettings → Apps → [This App] → Permissions → Location\n'
          'and select "Allow all the time".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Now'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Settings'),
            onPressed: () {
              Navigator.pop(context);
              _sendToSettings(PermissionHelper.openAppSettings);
            },
          ),
        ],
      ),
    );
  }

  void _showPermanentlyDeniedDialog({required bool isBackground}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: Icon(
          isBackground ? Icons.location_searching : Icons.block,
          size: 44,
          color: Colors.red,
        ),
        title: Text(isBackground
            ? 'Background Location Blocked'
            : 'Location Permission Blocked'),
        content: Text(
          isBackground
              ? 'Background location is permanently blocked.\n\n'
                  'Go to:\nSettings → Apps → [This App] → Permissions → Location\n'
                  'and select "Allow all the time".'
              : 'Location permission is permanently blocked.\n\n'
                  'Go to:\nSettings → Apps → [This App] → Permissions → Location\n'
                  'and select "Allow" to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Now'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Settings'),
            onPressed: () {
              Navigator.pop(context);
              _sendToSettings(PermissionHelper.openAppSettings);
            },
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocListener<TrackingBloc, TrackingState>(
      listener: (context, state) {
        if (state is TrackingGpsDisabled) {
          _showGpsDialog();
        } else if (state is TrackingForegroundPermissionDenied) {
          _showForegroundDeniedDialog();
        } else if (state is TrackingBackgroundPermissionDenied) {
          _showBackgroundDeniedDialog();
        } else if (state is TrackingPermissionPermanentlyDenied) {
          _showPermanentlyDeniedDialog(isBackground: state.isBackground);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('BG Location Tracker'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: BlocBuilder<BatteryCubit, BatteryState>(
                builder: (_, s) => BatteryIndicator(level: s.level),
              ),
            ),
          ],
        ),
        body: BlocBuilder<TrackingBloc, TrackingState>(
          builder: (ctx, state) => _buildBody(ctx, state),
        ),
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, TrackingState state) {
    final isRunning = state is TrackingRunning;

    return Column(
      children: [
        // ── Status area ────────────────────────────────────────────────────
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: _buildStatus(context, state),
            ),
          ),
        ),

        // ── Always-visible START / STOP buttons ────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  // Enabled only when NOT running
                  onPressed: isRunning
                      ? null
                      : () => context.read<TrackingBloc>().add(StartTracking()),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('START'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.teal,
                    disabledBackgroundColor: Colors.teal.withValues(alpha: 0.3),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  // Enabled only when running
                  onPressed: isRunning
                      ? () => context.read<TrackingBloc>().add(StopTracking())
                      : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('STOP'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.redAccent,
                    disabledBackgroundColor:
                        Colors.redAccent.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── View locations ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LocationsListScreen()),
            ),
            icon: const Icon(Icons.list_alt),
            label: const Text('View Recorded Locations'),
          ),
        ),
      ],
    );
  }

  Widget _buildStatus(BuildContext context, TrackingState state) {
    if (state is TrackingInitial) {
      return _statusBlock(
        context,
        icon: Icons.location_on_outlined,
        color: Colors.grey,
        title: 'Idle',
        subtitle: 'Tap START to begin location tracking.',
      );
    }

    if (state is TrackingRunning) {
      return _statusBlock(
        context,
        icon: Icons.my_location,
        color: Colors.teal,
        title: 'Tracking…',
        subtitle: '${state.count} fix(es) recorded this session.',
      );
    }

    if (state is TrackingStopped) {
      return _statusBlock(
        context,
        icon: Icons.location_disabled,
        color: Colors.grey,
        title: 'Stopped',
        subtitle: 'Tap START to resume tracking.',
      );
    }

    if (state is TrackingGpsDisabled) {
      return _statusBlock(
        context,
        icon: Icons.gps_off,
        color: Colors.orange,
        title: 'GPS is Disabled',
        subtitle: 'Enable location services on your device, then tap START again.',
      );
    }

    if (state is TrackingForegroundPermissionDenied) {
      return _statusBlock(
        context,
        icon: Icons.location_off,
        color: Colors.orange,
        title: 'Location Permission Needed',
        subtitle: 'Tap START to grant location permission.',
      );
    }

    if (state is TrackingBackgroundPermissionDenied) {
      return _statusBlock(
        context,
        icon: Icons.location_searching,
        color: Colors.orange,
        title: '"Always Allow" Required',
        subtitle:
            'Change location permission to "Allow all the time" in Settings, '
            'then tap START again.',
      );
    }

    if (state is TrackingPermissionPermanentlyDenied) {
      return _statusBlock(
        context,
        icon: state.isBackground ? Icons.location_searching : Icons.block,
        color: Colors.red,
        title: state.isBackground
            ? 'Background Location Blocked'
            : 'Permission Permanently Blocked',
        subtitle: 'Open app Settings, grant the required location permission, '
            'then tap START again.',
      );
    }

    if (state is TrackingError) {
      return _statusBlock(
        context,
        icon: Icons.error_outline,
        color: Colors.red,
        title: 'Error',
        subtitle: state.message,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _statusBlock(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 72, color: color),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }
}
