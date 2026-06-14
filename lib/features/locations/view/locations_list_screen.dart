import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:geocoding/geocoding.dart';
import '../bloc/locations_bloc.dart';
import '../bloc/locations_event.dart';
import '../bloc/locations_state.dart';
import '../../../data/models/location_record.dart';
import 'locations_map_screen.dart';

class LocationsListScreen extends StatelessWidget {
  const LocationsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LocationsBloc()..add(LoadLocations()),
      child: const _LocationsListView(),
    );
  }
}

class _LocationsListView extends StatelessWidget {
  const _LocationsListView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationsBloc, LocationsState>(
      listener: (context, state) {
        // ── Success: deletingKey just cleared → a delete completed ──────────
        // Detect the transition: was deleting → now loaded with no deletingKey
        if (state is LocationsLoaded && state.deletingKey == null) {
          // Only show SnackBar if we know a delete just happened (handled by
          // checking the BLoC logged it; the SnackBar is triggered by the
          // prior state having a deletingKey — tracked below via listenWhen).
        }

        // ── Error: show red SnackBar and reload ─────────────────────────────
        if (state is LocationsDeleteError) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
          // Reload from Hive to restore the list.
          context.read<LocationsBloc>().add(LoadLocations());
        }
      },
      // Separate listener purely for the success SnackBar: fires when
      // deletingKey transitions from non-null → null (delete completed).
      child: BlocListener<LocationsBloc, LocationsState>(
        listenWhen: (prev, next) =>
            prev is LocationsLoaded &&
            prev.deletingKey != null &&
            next is LocationsLoaded &&
            next.deletingKey == null,
        listener: (context, _) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Record deleted successfully'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Recorded Locations'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            actions: [
              IconButton(
                icon: const Icon(Icons.map_outlined),
                tooltip: 'Map view',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LocationsMapScreen()),
                ),
              ),
              BlocBuilder<LocationsBloc, LocationsState>(
                builder: (context, state) {
                  final hasRecords = state is LocationsLoaded &&
                      state.records.isNotEmpty;
                  return IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: 'Clear all',
                    onPressed: hasRecords
                        ? () async {
                            final confirmed = await _showDeleteDialog(
                              context,
                              title: 'Delete All Records',
                              subtitle:
                                  'Are you sure you want to delete all recorded locations? This action cannot be undone.',
                            );
                            if (confirmed && context.mounted) {
                              context
                                  .read<LocationsBloc>()
                                  .add(ClearLocations());
                            }
                          }
                        : null,
                  );
                },
              ),
            ],
          ),
          body: BlocBuilder<LocationsBloc, LocationsState>(
            // Rebuild for both LocationsLoaded and LocationsDeleteError
            buildWhen: (_, next) =>
                next is LocationsLoaded || next is LocationsDeleteError,
            builder: (context, state) {
              final records = state is LocationsLoaded
                  ? state.records
                  : state is LocationsDeleteError
                      ? state.records
                      : <LocationRecord>[];
              final deletingKey = state is LocationsLoaded
                  ? state.deletingKey
                  : null;

              if (records.isEmpty && state is! LocationsDeleteError) {
                if (state is LocationsInitial) {
                  return const Center(child: CircularProgressIndicator());
                }
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No locations recorded yet.',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return SlidableAutoCloseBehavior(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: records.length,
                  itemBuilder: (_, i) {
                    // Newest first
                    final record = records[records.length - 1 - i];
                    // Use the stable Hive auto-increment key (+1 so it starts at 1)
                    // so fix numbers never shift when other records are deleted.
                    final fixNumber = (record.key as int) + 1;
                    final isDeleting = deletingKey == record.key;

                    return _LocationCard(
                      key: ValueKey(record.key),
                      record: record,
                      fixNumber: fixNumber,
                      isDeleting: isDeleting,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Shared confirmation dialog ────────────────────────────────────────────────

Future<bool> _showDeleteDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.delete_outline_rounded, color: Colors.teal),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      content: Text(subtitle),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _LocationCard extends StatefulWidget {
  final LocationRecord record;
  final int fixNumber;
  final bool isDeleting;

  const _LocationCard({
    super.key,
    required this.record,
    required this.fixNumber,
    required this.isDeleting,
  });

  @override
  State<_LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<_LocationCard> {
  // Memoised so the geocoding call does not re-fire on every BLoC rebuild.
  late final Future<String> _addressFuture;

  @override
  void initState() {
    super.initState();
    _addressFuture = _resolveAddress();
  }

  Future<String> _resolveAddress() async {
    try {
      final placemarks = await placemarkFromCoordinates(
        widget.record.latitude,
        widget.record.longitude,
      );
      if (placemarks.isEmpty) return 'Address unavailable';
      final p = placemarks.first;
      final parts = <String>[
        if (p.name?.isNotEmpty == true && p.name != p.street) p.name!,
        if (p.street?.isNotEmpty == true) p.street!,
        if (p.subLocality?.isNotEmpty == true) p.subLocality!,
        if (p.locality?.isNotEmpty == true) p.locality!,
        if (p.subAdministrativeArea?.isNotEmpty == true)
          p.subAdministrativeArea!,
        if (p.administrativeArea?.isNotEmpty == true) p.administrativeArea!,
        if (p.postalCode?.isNotEmpty == true) p.postalCode!,
        if (p.country?.isNotEmpty == true) p.country!,
      ];
      return parts.isEmpty ? 'Address unavailable' : parts.join(', ');
    } catch (_) {
      return 'Address unavailable';
    }
  }

  // The BuildContext from SlidableAction is the action-pane context, which is
  // removed from the tree as soon as the slidable collapses. Using it after
  // `await` would always find it unmounted. We discard it and use the card
  // state's own `context` instead, which lives until the card is disposed.
  Future<void> _onDeleteTapped(BuildContext _) async {
    if (widget.isDeleting) return;
    final confirmed = await _showDeleteDialog(
      context,
      title: 'Delete Record',
      subtitle:
          'Are you sure you want to delete Fix #${widget.fixNumber}? This action cannot be undone.',
    );
    if (confirmed && mounted) {
      context.read<LocationsBloc>().add(DeleteLocation(widget.record.key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Slidable(
        key: ValueKey(widget.record.key),
        // Disable sliding while this record is being deleted
        enabled: !widget.isDeleting,
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.28,
          children: [
            // Show spinner during delete, delete icon otherwise
            widget.isDeleting
                ? Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.horizontal(
                            right: Radius.circular(12)),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  )
                : SlidableAction(
                    onPressed: _onDeleteTapped,
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    icon: Icons.delete_rounded,
                    label: 'Delete',
                    borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(12)),
                  ),
          ],
        ),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 2,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          // Slightly dim the card while deleting
          color: widget.isDeleting
              ? theme.colorScheme.surface.withValues(alpha: 0.6)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: widget.isDeleting
                          ? Colors.grey
                          : theme.colorScheme.primary,
                      child: Text(
                        '${widget.fixNumber}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location #${widget.fixNumber}',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _fmt(widget.record.timestamp),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    if (widget.isDeleting)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '±${widget.record.accuracy.toStringAsFixed(1)} m',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color:
                                  theme.colorScheme.onSecondaryContainer),
                        ),
                      ),
                  ],
                ),

                const Divider(height: 20),

                // ── Full address ─────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FutureBuilder<String>(
                        future: _addressFuture,
                        builder: (context, snap) {
                          if (snap.connectionState ==
                              ConnectionState.waiting) {
                            return const Text('Resolving address…',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 13));
                          }
                          return Text(
                            snap.data ?? 'Address unavailable',
                            style: theme.textTheme.bodyMedium,
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ── Coordinates ──────────────────────────────────────────
                Row(
                  children: [
                    Icon(Icons.my_location,
                        size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.record.latitude.toStringAsFixed(6)},  '
                      '${widget.record.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${p(dt.month)}-${p(dt.day)}  '
        '${p(dt.hour)}:${p(dt.minute)}:${p(dt.second)}';
  }
}
