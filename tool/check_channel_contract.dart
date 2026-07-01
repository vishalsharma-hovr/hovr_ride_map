// Verifies Dart and Kotlin channel name constants stay aligned.
import 'dart:io';

void main() {
  final root = Directory.current;
  if (!File('${root.path}/pubspec.yaml').existsSync()) {
    stderr.writeln('Run from packages/hovr_ride_map');
    exit(1);
  }

  final dart = File('lib/src/channels/ride_map_channels.dart').readAsStringSync();
  final kotlinHub = File(
    'android/src/main/kotlin/com/hovr/hovr_ride_map/RideViewChannelHub.kt',
  ).readAsStringSync();
  final kotlinPlugin = File(
    'android/src/main/kotlin/com/hovr/hovr_ride_map/HovrRideMapPlugin.kt',
  ).readAsStringSync();
  final kotlinSources = '$kotlinHub$kotlinPlugin';

  const pairs = <(String, String)>[
    ('ride-view-channel', 'rideView'),
    ('show-drivers-location-on-map', 'showDrivers'),
    ('routes-on-map-view', 'routesOnMap'),
    ('com.hovr/global_channel', 'globalChannel'),
    ('home-view-google-map', 'homeViewType'),
    ('hovr-ride-map-view', 'rideViewType'),
    ('meet-at-pickup-spot-view', 'legacyRideViewType'),
    ('google-map-view', 'legacyGoogleMapViewType'),
  ];

  var failed = false;
  for (final (wire, dartName) in pairs) {
    if (!dart.contains("'$wire'")) {
      stderr.writeln('Missing in Dart ($dartName): $wire');
      failed = true;
    }
    if (!kotlinSources.contains('"$wire"') && !kotlinSources.contains("'$wire'")) {
      stderr.writeln('Missing in Kotlin: $wire');
      failed = true;
    }
  }

  if (failed) {
    exit(1);
  }
  stdout.writeln('Channel contract OK (${pairs.length} names).');
}
