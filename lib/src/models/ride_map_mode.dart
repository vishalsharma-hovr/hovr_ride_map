/// Trip-stage map modes rendered by the unified native [RideMapView].
enum RideMapMode {
  findingDriver,
  meetAtPickup,
  driverWaitingAtPickup,
  headingToDestination,
  driverReachedAtPickup,
  idle;

  String get wireValue => switch (this) {
    RideMapMode.findingDriver => 'findingDriver',
    RideMapMode.meetAtPickup => 'meetAtPickup',
    RideMapMode.driverWaitingAtPickup => 'driverWaitingAtPickup',
    RideMapMode.headingToDestination => 'headingToDestination',
    RideMapMode.driverReachedAtPickup => 'driverReachedAtPickup',
    RideMapMode.idle => 'idle',
  };

  static RideMapMode? fromWireValue(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final mode in RideMapMode.values) {
      if (mode.wireValue == value) return mode;
    }
    return null;
  }
}
