# Contributing

## Setup

```bash
cd packages/hovr_ride_map
flutter pub get
```

## Before opening a PR

1. Format: `dart format lib test example/lib`
2. Analyze: `dart analyze --fatal-warnings lib test example/lib`
3. Contract: `dart run tool/check_channel_contract.dart`
4. Test: `flutter test`
5. Android: `cd android && ./gradlew :hovr_ride_map:testDebugUnitTest`

## Code quality standards

| Practice | Enforcement |
|----------|-------------|
| Simple control flow | Early return in channel handlers; mode strategies, not nested switches |
| Bounded loops | Cap animation batches and marker counts |
| Limit allocation | Reuse marker icon caches on native |
| Small functions | Split large platform views into focused helpers |
| Assertions | Unit tests for geometry; validate channel args |
| Smallest scope | Per-view state; `RideViewChannelHub` push/pop |
| Check returns | `FlutterError` / `result.error` on invalid args |
| Zero warnings | `dart analyze --fatal-warnings` must pass |

## Channel changes

Update Dart (`lib/src/channels/ride_map_channels.dart`), Kotlin (`HovrRideMapPlugin.kt`, `RideViewChannelHub.kt`), Swift (`HovrRideMapPlugin.swift`, `RideViewChannelHub.swift`), and document in `doc/CHANNEL_CONTRACT.md`.

## Publishing to GitHub

```bash
./tool/publish_to_github.sh v1.0.0
```

Requires `brew install gh && gh auth login`.
