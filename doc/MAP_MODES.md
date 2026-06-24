# Ride map modes

All modes render in the **same** `RideMapView` / `RideMapPlatformView`. Update the `mode` prop when the trip stage changes — the widget syncs the native map automatically. Do not swap platform views per step.

| `RideMapMode` | Wire value | Camera / markers |
|---------------|------------|------------------|
| `findingDriver` | `findingDriver` | User location, wide zoom |
| `meetAtPickup` | `meetAtPickup` | Pickup + user markers, driver approach |
| `driverWaitingAtPickup` | `driverWaitingAtPickup` | Pickup emphasis |
| `headingToDestination` | `headingToDestination` | Route polyline, car animation, destination |
| `driverReachedAtPickup` | `driverReachedAtPickup` | Arrival at pickup |
| `idle` | `idle` | Safe default |

## Controller methods by flow

| Flow | Methods |
|------|---------|
| Home | `showNearbyDrivers`, `recenter` |
| Finding driver | `RideMapView(mode: RideMapMode.findingDriver)`, `setTripLocations` |
| Driver en route | `updateDriverLocation`, `setRoutePolyline`, `driverEtaUpdates` |
| Trip end | `clearRoute` |

`RideMapController.setTripStage` is available for out-of-band updates but is **not required** when you rebuild `RideMapView` with a new `mode`.
