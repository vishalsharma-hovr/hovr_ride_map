import 'package:flutter_test/flutter_test.dart';
import 'package:hovr_ride_map_example/main.dart';

void main() {
  testWidgets('Example app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const HovrRideMapExampleApp());
    expect(find.text('hovr_ride_map example'), findsOneWidget);
    expect(find.text('Home map'), findsOneWidget);
    expect(find.text('Ride map'), findsOneWidget);
  });
}
