import 'package:flutter/material.dart';
import 'package:hovr_ride_map/hovr_ride_map.dart';

void main() {
  runApp(const HovrRideMapExampleApp());
}

class HovrRideMapExampleApp extends StatefulWidget {
  const HovrRideMapExampleApp({super.key});

  @override
  State<HovrRideMapExampleApp> createState() => _HovrRideMapExampleAppState();
}

class _HovrRideMapExampleAppState extends State<HovrRideMapExampleApp> {
  var _mode = RideMapMode.findingDriver;
  var _showHomeMap = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('hovr_ride_map example'),
          actions: [
            IconButton(
              tooltip: 'Recenter',
              onPressed: RideMapController.shared.recenter,
              icon: const Icon(Icons.my_location),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Home map'),
                    selected: _showHomeMap,
                    onSelected: (selected) =>
                        setState(() => _showHomeMap = selected),
                  ),
                  ChoiceChip(
                    label: const Text('Ride map'),
                    selected: !_showHomeMap,
                    onSelected: (selected) =>
                        setState(() => _showHomeMap = !selected),
                  ),
                  if (!_showHomeMap)
                    DropdownButton<RideMapMode>(
                      value: _mode,
                      onChanged: (mode) {
                        if (mode != null) setState(() => _mode = mode);
                      },
                      items: RideMapMode.values
                          .map(
                            (mode) => DropdownMenuItem(
                              value: mode,
                              child: Text(mode.wireValue),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _showHomeMap
                  ? const HomeMapView()
                  : RideMapView(mode: _mode),
            ),
          ],
        ),
      ),
    );
  }
}
