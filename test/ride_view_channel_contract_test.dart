import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Native files allowed to own `ride-view-channel`: the hubs that dispatch to
/// the active map. Any other owner replaces the hub's handler, and clearing it
/// on dispose leaves Dart with `MissingPluginException`.
const _hubFiles = {'RideViewChannelHub.swift', 'RideViewChannelHub.kt'};

/// `MethodChannel("ride-view-channel"` or `FlutterMethodChannel(name: "ride-view-channel"`, across lines.
final _createsChannel = RegExp(r'MethodChannel\(\s*(name:\s*)?"ride-view-channel"');

void main() {
  test('only the hub creates ride-view-channel on iOS and Android', () {
    final offenders = [
      for (final dir in ['ios', 'android/src/main'])
        for (final file in Directory(dir).listSync(recursive: true).whereType<File>())
          if ((file.path.endsWith('.swift') || file.path.endsWith('.kt')) &&
              !_hubFiles.contains(file.uri.pathSegments.last) &&
              _createsChannel.hasMatch(file.readAsStringSync()))
            file.path,
    ];

    expect(offenders, isEmpty, reason: 'register with RideViewChannelHub.push/pop instead');
  });
}
