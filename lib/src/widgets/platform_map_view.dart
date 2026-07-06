import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Shared platform map view wrapper for Android and iOS.
class PlatformMapView extends StatelessWidget {
  const PlatformMapView({
    super.key,
    required this.viewType,
    this.creationParams = const <String, Object?>{},
    this.hitTestBehavior = PlatformViewHitTestBehavior.opaque,
    this.onPlatformViewCreated,
  });

  final String viewType;
  final Map<String, Object?> creationParams;
  final PlatformViewHitTestBehavior hitTestBehavior;
  final ValueChanged<int>? onPlatformViewCreated;

  Set<Factory<OneSequenceGestureRecognizer>> get _gestureRecognizers => {
    Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
  };

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return UiKitView(
        viewType: viewType,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        gestureRecognizers: _gestureRecognizers,
        hitTestBehavior: hitTestBehavior,
        onPlatformViewCreated: onPlatformViewCreated,
      );
    }
    return AndroidView(
      viewType: viewType,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
      gestureRecognizers: _gestureRecognizers,
      hitTestBehavior: hitTestBehavior,
      onPlatformViewCreated: onPlatformViewCreated,
    );
  }
}
