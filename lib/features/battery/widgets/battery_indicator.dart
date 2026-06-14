import 'package:flutter/material.dart';

class BatteryIndicator extends StatelessWidget {
  final int level;
  const BatteryIndicator({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.battery_full_outlined, size: 18),
        const SizedBox(width: 4),
        Text(
          level < 0 ? '--' : '$level%',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}
