/// Trip-stage map modes rendered by the unified native [RideMapView].
enum RideMapMode {
  findingDriver,
  meetAtPickup,
  driverWaitingAtPickup,
  headingToDestination,
  driverReachedAtPickup,
  idle;

  /// Name sent to native code in `creationParams['mode']` and `trip-stage`.
  String get wireValue => switch (this) {
    RideMapMode.findingDriver => 'findingDriver',
    RideMapMode.meetAtPickup => 'meetAtPickup',
    RideMapMode.driverWaitingAtPickup => 'driverWaitingAtPickup',
    RideMapMode.headingToDestination => 'headingToDestination',
    RideMapMode.driverReachedAtPickup => 'driverReachedAtPickup',
    RideMapMode.idle => 'idle',
  };

  /// The mode for [value], or null when it is empty or unknown.
  static RideMapMode? fromWireValue(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final mode in RideMapMode.values) {
      if (mode.wireValue == value) return mode;
    }
    return null;
  }
}
