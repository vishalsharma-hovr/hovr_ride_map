import 'package:flutter/widgets.dart';
import 'package:hovr_ride_map/src/channels/ride_map_channels.dart';
import 'package:hovr_ride_map/src/models/ride_map_mode.dart';
import 'package:hovr_ride_map/src/widgets/platform_map_view.dart';

/// Unified in-trip map for all ride stages.
class RideMapView extends StatelessWidget {
  const RideMapView({
    super.key,
    required this.mode,
    this.viewKey,
  });

  final RideMapMode mode;
  final Key? viewKey;

  @override
  Widget build(BuildContext context) {
    return PlatformMapView(
      key: viewKey ?? ValueKey(mode.wireValue),
      viewType: RideMapChannels.rideViewType,
      creationParams: {'mode': mode.wireValue},
    );
  }
}
