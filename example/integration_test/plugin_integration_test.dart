import 'package:flutter_test/flutter_test.dart';
import 'package:hovr_ride_map/hovr_ride_map.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('RideMapMode wire values are stable', (WidgetTester tester) async {
    for (final mode in RideMapMode.values) {
      expect(RideMapMode.fromWireValue(mode.wireValue), mode);
    }
  });

  testWidgets('RideMapController shared instance is available', (WidgetTester tester) async {
    expect(RideMapController.shared, isNotNull);
    await RideMapController.shared.recenter();
  });
}
