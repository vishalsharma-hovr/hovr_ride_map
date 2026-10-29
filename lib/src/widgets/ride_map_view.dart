import 'package:flutter/widgets.dart';
import 'package:hovr_ride_map/src/channels/ride_map_channels.dart';
import 'package:hovr_ride_map/src/controller/ride_map_controller.dart';
import 'package:hovr_ride_map/src/models/ride_map_mode.dart';
import 'package:hovr_ride_map/src/widgets/platform_map_view.dart';

/// Unified in-trip map for all ride stages.
///
/// Pass an updated [mode] when the trip stage changes — the widget syncs the
/// native map via the method channel only when [mode] actually changes. The
/// platform view stays mounted; it is not recreated on parent rebuilds.
class RideMapView extends StatefulWidget {
  const RideMapView({super.key, required this.mode, this.viewKey});

  /// Current trip stage; changes are pushed to the native map.
  final RideMapMode mode;

  /// Optional key for the platform view. Defaults to a stable in-package key
  /// so the native map is not torn down when the host rebuilds.
  final Key? viewKey;

  static const _defaultPlatformViewKey = ValueKey<String>(
    'hovr-ride-map-platform-view',
  );

  @override
  State<RideMapView> createState() => _RideMapViewState();
}

class _RideMapViewState extends State<RideMapView> {
  late final Map<String, Object?> _creationParams;
  RideMapMode? _syncedMode;

  @override
  void initState() {
    super.initState();
    // Frozen at first mount — never pass a new map instance from [build].
    _creationParams = {'mode': widget.mode.wireValue};
    _syncedMode = widget.mode;
  }

  @override
  void didUpdateWidget(RideMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _syncModeToNative();
    }
  }

  void _onPlatformViewCreated(int _) {
    // Native already read [_creationParams] on create; only catch up if mode
    // changed before the view finished mounting.
    if (_syncedMode != widget.mode) {
      _syncModeToNative();
    }
  }

  Future<void> _syncModeToNative() async {
    if (!mounted || _syncedMode == widget.mode) return;
    final targetMode = widget.mode;
    await RideMapController.shared.setTripStage(targetMode);
    if (!mounted || widget.mode != targetMode) return;
    _syncedMode = targetMode;
  }

  @override
  Widget build(BuildContext context) {
    return PlatformMapView(
      key: widget.viewKey ?? RideMapView._defaultPlatformViewKey,
      viewType: RideMapChannels.rideViewType,
      creationParams: _creationParams,
      onPlatformViewCreated: _onPlatformViewCreated,
    );
  }
}
