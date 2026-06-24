import 'package:flutter/widgets.dart';
import 'package:hovr_ride_map/src/channels/ride_map_channels.dart';
import 'package:hovr_ride_map/src/widgets/platform_map_view.dart';

/// Home tab map with nearby drivers and user location.
class HomeMapView extends StatelessWidget {
  const HomeMapView({super.key, this.mapKey});

  final Key? mapKey;

  @override
  Widget build(BuildContext context) {
    return PlatformMapView(
      key: mapKey,
      viewType: RideMapChannels.homeViewType,
    );
  }
}
