import 'package:flutter/material.dart';

/// Brand colours for routes and markers drawn natively on the ride maps,
/// taken from the host app's theme so light, dark and festive themes carry
/// through. Native code keeps HOVR's greens until these arrive.
@immutable
class RideMapColors {
  const RideMapColors({
    required this.accent,
    required this.accentStrong,
    required this.accentContainer,
    required this.onAccent,
    required this.surface,
    required this.onSurface,
  });

  /// The app theme's [scheme] as route and marker colours.
  factory RideMapColors.fromScheme(ColorScheme scheme) => RideMapColors(
    accent: scheme.primary,
    accentStrong: scheme.primary,
    accentContainer: scheme.primaryContainer,
    onAccent: scheme.onPrimary,
    surface: scheme.surface,
    onSurface: scheme.onSurface,
  );

  /// Route line, marker rings and dots.
  final Color accent;

  /// ETA bubble and tag pill backgrounds.
  final Color accentStrong;

  /// Inner ring of the start/destination icon.
  final Color accentContainer;

  /// Text and icons on [accent] / [accentStrong].
  final Color onAccent;

  /// Address tag and stop marker backgrounds.
  final Color surface;

  /// Text and icons on [surface].
  final Color onSurface;

  /// ARGB ints by token name, as the native side reads them.
  Map<String, int> toMap() => {
    'accent': accent.toARGB32(),
    'accentStrong': accentStrong.toARGB32(),
    'accentContainer': accentContainer.toARGB32(),
    'onAccent': onAccent.toARGB32(),
    'surface': surface.toARGB32(),
    'onSurface': onSurface.toARGB32(),
  };

  @override
  bool operator ==(Object other) =>
      other is RideMapColors &&
      other.accent == accent &&
      other.accentStrong == accentStrong &&
      other.accentContainer == accentContainer &&
      other.onAccent == onAccent &&
      other.surface == surface &&
      other.onSurface == onSurface;

  @override
  int get hashCode => Object.hash(
    accent,
    accentStrong,
    accentContainer,
    onAccent,
    surface,
    onSurface,
  );
}
