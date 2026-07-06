import 'package:flutter/widgets.dart';
import 'package:hovr_ride_map/src/channels/ride_map_channels.dart';
import 'package:hovr_ride_map/src/widgets/platform_map_view.dart';

/// Home tab map with nearby drivers and user location.
class HomeMapView extends StatelessWidget {
  const HomeMapView({
    super.key,
    this.mapKey,
    this.initialLatitude,
    this.initialLongitude,
  });

  final Key? mapKey;
  final double? initialLatitude;
  final double? initialLongitude;

  @override
  Widget build(BuildContext context) {
    final creationParams = <String, Object?>{};
    if (initialLatitude != null && initialLongitude != null) {
      creationParams['initialLatitude'] = initialLatitude;
      creationParams['initialLongitude'] = initialLongitude;
    }

    return PlatformMapView(
      key: mapKey,
      viewType: RideMapChannels.homeViewType,
      creationParams: creationParams,
    );
  }
}
