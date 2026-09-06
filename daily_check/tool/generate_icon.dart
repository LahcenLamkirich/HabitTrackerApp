// Generates the app icon source images from the "Mindful Habit Track"
// brand tokens (coral disc + checkmark on cream). Run with:
//   dart run tool/generate_icon.dart
// Then regenerate platform icons with:
//   dart run flutter_launcher_icons

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _canvas = 0xFFF9F7F4; // cream
const _primary = 0xFFE85D30; // burnt coral
const _white = 0xFFFFFFFF;

img.Color _rgb(int hex) => img.ColorRgba8(
      (hex >> 16) & 0xFF,
      (hex >> 8) & 0xFF,
      hex & 0xFF,
      255,
    );

void _drawCheckmark(
  img.Image image, {
  required double cx,
  required double cy,
  required double radius,
  required img.Color color,
  required double thickness,
}) {
  // Checkmark polyline points, relative to a unit circle of [radius].
  final points = <math.Point<double>>[
    math.Point(-0.5, 0.05),
    math.Point(-0.15, 0.4),
    math.Point(0.55, -0.35),
  ];

  for (var i = 0; i < points.length - 1; i++) {
    final p1 = points[i];
    final p2 = points[i + 1];
    img.drawLine(
      image,
      x1: (cx + p1.x * radius).round(),
      y1: (cy + p1.y * radius).round(),
      x2: (cx + p2.x * radius).round(),
      y2: (cy + p2.y * radius).round(),
      color: color,
      thickness: thickness,
    );
  }
}

img.Image _baseIcon(int size) {
  final image = img.Image(width: size, height: size, numChannels: 4);
  img.fill(image, color: _rgb(_canvas));

  final center = size / 2;
  final discRadius = size * 0.36;

  img.fillCircle(
    image,
    x: center.round(),
    y: center.round(),
    radius: discRadius.round(),
    color: _rgb(_primary),
  );

  _drawCheckmark(
    image,
    cx: center,
    cy: center,
    radius: discRadius,
    color: _rgb(_white),
    thickness: size * 0.075,
  );

  return image;
}

img.Image _foregroundIcon(int size) {
  final image = img.Image(width: size, height: size, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));

  final center = size / 2;
  // Keep content inside the adaptive-icon safe zone (~66% of canvas).
  final discRadius = size * 0.27;

  img.fillCircle(
    image,
    x: center.round(),
    y: center.round(),
    radius: discRadius.round(),
    color: _rgb(_primary),
  );

  _drawCheckmark(
    image,
    cx: center,
    cy: center,
    radius: discRadius,
    color: _rgb(_white),
    thickness: size * 0.056,
  );

  return image;
}

void main() {
  const size = 1024;

  final iconDir = Directory('assets/icon')..createSync(recursive: true);

  File('${iconDir.path}/icon.png')
      .writeAsBytesSync(img.encodePng(_baseIcon(size)));
  File('${iconDir.path}/icon_foreground.png')
      .writeAsBytesSync(img.encodePng(_foregroundIcon(size)));

  stdout.writeln('Wrote ${iconDir.path}/icon.png and icon_foreground.png');
}
