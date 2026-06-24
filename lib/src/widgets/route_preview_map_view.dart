import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:hovr_ride_map/src/channels/ride_map_channels.dart';
import 'package:hovr_ride_map/src/models/route_preview_config.dart';
import 'package:hovr_ride_map/src/widgets/platform_map_view.dart';

/// Pickup → dropoff route preview during choose-a-ride.
class RoutePreviewMapView extends StatelessWidget {
  const RoutePreviewMapView({
    super.key,
    required this.config,
    this.viewKey,
  });

  final RoutePreviewConfig config;
  final Key? viewKey;

  @override
  Widget build(BuildContext context) {
    return PlatformMapView(
      key: viewKey ?? const ValueKey(RideMapChannels.routePreviewViewType),
      viewType: RideMapChannels.routePreviewViewType,
      creationParams: config.toCreationParams(),
      hitTestBehavior: PlatformViewHitTestBehavior.translucent,
    );
  }
}
