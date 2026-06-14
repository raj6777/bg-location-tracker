import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/locations_bloc.dart';
import '../bloc/locations_event.dart';
import '../bloc/locations_state.dart';
import '../../../data/models/location_record.dart';

class LocationsMapScreen extends StatelessWidget {
  const LocationsMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LocationsBloc()..add(LoadLocations()),
      child: const _LocationsMapView(),
    );
  }
}

class _LocationsMapView extends StatelessWidget {
  const _LocationsMapView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location Plot')),
      body: BlocBuilder<LocationsBloc, LocationsState>(
        builder: (context, state) {
          if (state is LocationsInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is LocationsLoaded) {
            if (state.records.isEmpty) {
              return const Center(child: Text('No locations recorded yet.'));
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${state.records.length} point(s) — green = first, red = latest',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _PointsCanvas(records: state.records),
                  ),
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _PointsCanvas extends StatelessWidget {
  final List<LocationRecord> records;
  const _PointsCanvas({required this.records});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: _PointsPainter(records: records),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PointsPainter extends CustomPainter {
  final List<LocationRecord> records;

  _PointsPainter({required this.records});

  @override
  void paint(Canvas canvas, Size size) {
    if (records.isEmpty) return;

    final lats = records.map((r) => r.latitude).toList();
    final lngs = records.map((r) => r.longitude).toList();

    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);

    // Clamp range to avoid division by zero when all points are identical
    final latRange = (maxLat - minLat).clamp(1e-6, double.infinity);
    final lngRange = (maxLng - minLng).clamp(1e-6, double.infinity);

    const pad = 24.0;

    Offset toOffset(LocationRecord r) => Offset(
          pad + (r.longitude - minLng) / lngRange * (size.width - pad * 2),
          pad +
              (1 - (r.latitude - minLat) / latRange) *
                  (size.height - pad * 2),
        );

    // Draw connecting lines
    final linePaint = Paint()
      ..color = Colors.teal.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(toOffset(records[0]).dx, toOffset(records[0]).dy);
    for (int i = 1; i < records.length; i++) {
      final o = toOffset(records[i]);
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, linePaint);

    // Draw dots — middle points in teal, first in green, last in red
    for (int i = 0; i < records.length; i++) {
      final o = toOffset(records[i]);
      final isFirst = i == 0;
      final isLast = i == records.length - 1;
      final color = isFirst
          ? Colors.green
          : isLast
              ? Colors.red
              : Colors.teal;
      canvas.drawCircle(
        o,
        isFirst || isLast ? 7 : 5,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_PointsPainter old) => old.records != records;
}
