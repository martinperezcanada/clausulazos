import 'dart:math' as math;
import 'dart:ui';

import 'package:clausulazos/widgets/gavel_logo.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tracks the canvas transform `GavelPainter` sets up (translate/rotate/scale) and records every rounded
/// rect it draws already mapped to design space, so the gavel's geometry can be checked without pixels.
class _RecordingCanvas implements Canvas {
  final List<String> calls = [];
  final List<Rect> rects = [];

  /// Transform in effect for each drawn rrect, to map any local point of it to design space.
  final List<Offset Function(Offset)> mappers = [];
  final List<double> rotations = [];

  // Current affine transform (without the initial design-space scale): x' = a*x + b*y + tx, y' = c*x + d*y + ty.
  double _a = 1, _b = 0, _c = 0, _d = 1, _tx = 0, _ty = 0;
  final List<List<double>> _stack = [];

  Offset _map(Offset p) =>
      Offset(_a * p.dx + _b * p.dy + _tx, _c * p.dx + _d * p.dy + _ty);

  @override
  void scale(double sx, [double? sy]) => calls.add('scale');

  @override
  void save() => _stack.add([_a, _b, _c, _d, _tx, _ty]);

  @override
  void restore() {
    final s = _stack.removeLast();
    _a = s[0];
    _b = s[1];
    _c = s[2];
    _d = s[3];
    _tx = s[4];
    _ty = s[5];
  }

  @override
  void translate(double dx, double dy) {
    _tx += _a * dx + _b * dy;
    _ty += _c * dx + _d * dy;
  }

  @override
  void rotate(double radians) {
    rotations.add(radians);
    final cos = math.cos(radians), sin = math.sin(radians);
    final a = _a * cos + _b * sin, b = -_a * sin + _b * cos;
    final c = _c * cos + _d * sin, d = -_c * sin + _d * cos;
    _a = a;
    _b = b;
    _c = c;
    _d = d;
  }

  @override
  void drawRRect(RRect rrect, Paint paint) {
    final m = [_a, _b, _c, _d, _tx, _ty];
    mappers.add((p) => Offset(
        m[0] * p.dx + m[1] * p.dy + m[4], m[2] * p.dx + m[3] * p.dy + m[5]));
    final corners = [
      _map(rrect.outerRect.topLeft),
      _map(rrect.outerRect.bottomRight),
    ];
    rects.add(Rect.fromPoints(corners[0], corners[1]));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Paints the striking pose at `angle` and returns (canvas, block, handle, head) in design units.
(_RecordingCanvas, Rect, Rect, Rect) _paint(double angle) {
  final canvas = _RecordingCanvas();
  GavelPainter(striking: true, angle: angle, ring: 0)
      .paint(canvas, const Size(128, 128));
  expect(canvas.rects, hasLength(3));
  return (canvas, canvas.rects[0], canvas.rects[1], canvas.rects[2]);
}

void _expectRect(Rect actual, Rect expected) {
  expect(actual.left, closeTo(expected.left, 1e-9));
  expect(actual.top, closeTo(expected.top, 1e-9));
  expect(actual.right, closeTo(expected.right, 1e-9));
  expect(actual.bottom, closeTo(expected.bottom, 1e-9));
}

void main() {
  test('the upright logo (login) is drawn exactly as before', () {
    final canvas = _RecordingCanvas();
    GavelPainter(ring: 0).paint(canvas, const Size(128, 128));

    expect(canvas.rotations, isEmpty);
    // Handle 9 x 54 hanging from (64, 18), head 54 x 28 centred 60 below it, resting on the block.
    _expectRect(canvas.rects[1], const Rect.fromLTWH(59.5, 18, 9, 54));
    _expectRect(canvas.rects[2],
        Rect.fromCenter(center: const Offset(64, 78), width: 54, height: 28));
  });

  const grip = Offset(115, 65);
  // Points of the gavel in its own drawing frame (the upright logo's frame).
  const gripLocal = Offset(0, 5);
  const headCentreLocal = Offset(0, 60);
  const headTopLocal = Offset(0, 46);

  test('struck: slim upright head on the block, handle to the right', () {
    final (_, block, handle, head) = _paint(0);

    // The original head (54 x 28) held sideways: 28 wide, 54 tall, its face on the block.
    _expectRect(head,
        Rect.fromCenter(center: const Offset(60, 65), width: 28, height: 54));
    expect(head.bottom, closeTo(block.top, 1e-9));
    expect(head.left, greaterThan(block.left));
    expect(head.right, lessThan(block.right));

    // The original 54 x 9 handle, horizontal, out of the middle of the head towards the hand.
    _expectRect(handle, const Rect.fromLTRB(66, 60.5, 120, 69.5));
    expect(handle.center.dy, closeTo(head.center.dy, 1e-9));
  });

  test('head and handle always share one transform: a single rigid piece', () {
    for (final angle in [0.0, 0.2, 0.55, 0.68]) {
      final (canvas, _, _, _) = _paint(angle);
      final handleMap = canvas.mappers[1];
      final headMap = canvas.mappers[2];
      for (final p in const [
        Offset.zero,
        Offset(10, 20),
        Offset(-14, 74),
        Offset(27, 46),
      ]) {
        expect(headMap(p).dx, closeTo(handleMap(p).dx, 1e-9));
        expect(headMap(p).dy, closeTo(handleMap(p).dy, 1e-9));
      }
    }
  });

  test('the strike turns the whole gavel around the fixed grip', () {
    final (struck, _, _, _) = _paint(0);
    final (raised, _, _, _) = _paint(0.55);
    final (cocked, _, _, _) = _paint(0.68);

    Offset at(_RecordingCanvas c, Offset local) => c.mappers[2](local);
    final radius = (at(struck, headCentreLocal) - grip).distance;

    for (final c in [struck, raised, cocked]) {
      // The hand doesn't move, and head and handle keep their distance to it.
      expect(at(c, gripLocal).dx, closeTo(grip.dx, 1e-9));
      expect(at(c, gripLocal).dy, closeTo(grip.dy, 1e-9));
      expect((at(c, headCentreLocal) - grip).distance, closeTo(radius, 1e-9));
    }

    // Raised, the head is up along its arc; cocked, higher still.
    expect(at(raised, headCentreLocal).dy,
        lessThan(at(struck, headCentreLocal).dy - 20));
    expect(at(cocked, headCentreLocal).dy,
        lessThan(at(raised, headCentreLocal).dy));

    // The head turns by exactly the strike angle: its axis (head centre -> handle root) turns with it.
    for (final (c, angle) in [(raised, 0.55), (cocked, 0.68)]) {
      final axis = at(c, headTopLocal) - at(c, headCentreLocal);
      final struckAxis = at(struck, headTopLocal) - at(struck, headCentreLocal);
      final turned = axis.direction - struckAxis.direction;
      expect(turned, closeTo(angle, 1e-9));
    }
  });
}
