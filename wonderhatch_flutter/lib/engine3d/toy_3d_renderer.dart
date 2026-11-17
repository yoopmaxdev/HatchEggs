import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/toy_customization.dart';
import '../models/toy_series.dart';

class Vec3 {
  final double x;
  final double y;
  final double z;

  const Vec3(this.x, this.y, this.z);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  double get length => math.sqrt(x * x + y * y + z * z);

  Vec3 normalized() {
    final l = length;
    if (l < 1e-6) return const Vec3(0, 0, 1);
    return Vec3(x / l, y / l, z / l);
  }

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;

  Vec3 cross(Vec3 o) => Vec3(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  Vec3 rotateY(double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return Vec3(x * c + z * s, y, -x * s + z * c);
  }

  Vec3 rotateX(double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return Vec3(x, y * c - z * s, y * s + z * c);
  }
}

class _Projected {
  final Offset offset;
  final double scale;
  final double z;

  const _Projected(this.offset, this.scale, this.z);
}

_Projected _project(Vec3 world, double rotY, double rotX, Size size, double zoom) {
  final r = world.rotateY(rotY).rotateX(rotX);
  const cameraDist = 5.2;
  final zDepth = cameraDist - r.z;
  final safeZ = zDepth < 0.8 ? 0.8 : zDepth;
  final fov = math.min(size.width, size.height) * 0.88 * zoom;
  final scale = fov / safeZ;
  final sx = size.width * 0.5 + r.x * scale;
  final sy = size.height * 0.54 - r.y * scale;
  return _Projected(Offset(sx, sy), scale, r.z);
}

abstract class _RenderItem {
  double depth(double rotY, double rotX);
  void paint(Canvas canvas, double rotY, double rotX, Size size, double zoom);
}

class _SphereItem extends _RenderItem {
  final Vec3 center;
  final double radius;
  final Color color;
  final double shininess = 0.85;
  final double scaleX;
  final double scaleY;

  _SphereItem({
    required this.center,
    required this.radius,
    required this.color,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
  });

  @override
  double depth(double rotY, double rotX) =>
      center.rotateY(rotY).rotateX(rotX).z;

  @override
  void paint(Canvas canvas, double rotY, double rotX, Size size, double zoom) {
    final p = _project(center, rotY, rotX, size, zoom);
    final rx = radius * p.scale * scaleX;
    final ry = radius * p.scale * scaleY;
    if (rx <= 0.5 || ry <= 0.5) return;

    final rect = Rect.fromCenter(center: p.offset, width: rx * 2, height: ry * 2);
    final hsl = HSLColor.fromColor(color);
    final highlight = hsl
        .withLightness((hsl.lightness + 0.28).clamp(0.0, 0.98))
        .withSaturation((hsl.saturation * 0.85).clamp(0.0, 1.0))
        .toColor();
    final mid = color;
    final shadow = hsl
        .withLightness((hsl.lightness - 0.24).clamp(0.04, 1.0))
        .toColor();

    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.36, -0.42),
        radius: 1.05,
        colors: [highlight, mid, shadow],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);

    canvas.drawOval(rect, paint);

    if (shininess > 0.2) {
      final specRect = Rect.fromCenter(
        center: p.offset + Offset(-rx * 0.34, -ry * 0.36),
        width: rx * 0.42,
        height: ry * 0.26,
      );
      canvas.save();
      canvas.translate(specRect.center.dx, specRect.center.dy);
      canvas.rotate(-0.45);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: specRect.width,
          height: specRect.height,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.48 * shininess),
      );
      canvas.restore();
    }
  }
}

class _CapsuleItem extends _RenderItem {
  final Vec3 a;
  final Vec3 b;
  final double radius;
  final Color color;

  _CapsuleItem({
    required this.a,
    required this.b,
    required this.radius,
    required this.color,
  });

  @override
  double depth(double rotY, double rotX) {
    final mid = (a + b) * 0.5;
    return mid.rotateY(rotY).rotateX(rotX).z;
  }

  @override
  void paint(Canvas canvas, double rotY, double rotX, Size size, double zoom) {
    final pa = _project(a, rotY, rotX, size, zoom);
    final pb = _project(b, rotY, rotX, size, zoom);
    final avgScale = (pa.scale + pb.scale) * 0.5;
    final strokeW = radius * 2 * avgScale;
    if (strokeW <= 0.5) return;

    final hsl = HSLColor.fromColor(color);
    final light = hsl
        .withLightness((hsl.lightness + 0.18).clamp(0.0, 0.96))
        .toColor();
    final dark = hsl
        .withLightness((hsl.lightness - 0.22).clamp(0.04, 1.0))
        .toColor();

    final bounds = Rect.fromPoints(pa.offset, pb.offset).inflate(strokeW * 0.6);
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeW
      ..style = PaintingStyle.stroke
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [light, color, dark],
      ).createShader(bounds);

    canvas.drawLine(pa.offset, pb.offset, paint);
  }
}

class _ConeItem extends _RenderItem {
  final Vec3 base;
  final Vec3 tip;
  final double baseRadius;
  final Color color;

  _ConeItem({
    required this.base,
    required this.tip,
    required this.baseRadius,
    required this.color,
  });

  @override
  double depth(double rotY, double rotX) {
    final mid = Vec3(
      (base.x + tip.x) * 0.5,
      (base.y + tip.y) * 0.5,
      (base.z + tip.z) * 0.5,
    );
    return mid.rotateY(rotY).rotateX(rotX).z;
  }

  @override
  void paint(Canvas canvas, double rotY, double rotX, Size size, double zoom) {
    final pb = _project(base, rotY, rotX, size, zoom);
    final pt = _project(tip, rotY, rotX, size, zoom);
    final r = baseRadius * pb.scale;
    if (r <= 0.5) return;

    final dir = pt.offset - pb.offset;
    final len = dir.distance;
    final perp = len < 1e-3
        ? const Offset(1, 0)
        : Offset(-dir.dy / len, dir.dx / len);

    final left = pb.offset + perp * r;
    final right = pb.offset - perp * r;

    final path = Path()
      ..moveTo(pt.offset.dx, pt.offset.dy)
      ..lineTo(left.dx, left.dy)
      ..quadraticBezierTo(
        pb.offset.dx,
        pb.offset.dy + r * 0.35,
        right.dx,
        right.dy,
      )
      ..close();

    final hsl = HSLColor.fromColor(color);
    final light = hsl
        .withLightness((hsl.lightness + 0.2).clamp(0.0, 0.96))
        .toColor();
    final dark = hsl
        .withLightness((hsl.lightness - 0.22).clamp(0.04, 1.0))
        .toColor();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [light, color, dark],
      ).createShader(path.getBounds());

    canvas.drawPath(path, paint);
  }
}

class _BoxItem extends _RenderItem {
  final Vec3 center;
  final Vec3 half;
  final Color color;

  _BoxItem({
    required this.center,
    required this.half,
    required this.color,
  });

  @override
  double depth(double rotY, double rotX) =>
      center.rotateY(rotY).rotateX(rotX).z;

  @override
  void paint(Canvas canvas, double rotY, double rotX, Size size, double zoom) {
    final verts = [
      Vec3(center.x - half.x, center.y - half.y, center.z - half.z),
      Vec3(center.x + half.x, center.y - half.y, center.z - half.z),
      Vec3(center.x + half.x, center.y + half.y, center.z - half.z),
      Vec3(center.x - half.x, center.y + half.y, center.z - half.z),
      Vec3(center.x - half.x, center.y - half.y, center.z + half.z),
      Vec3(center.x + half.x, center.y - half.y, center.z + half.z),
      Vec3(center.x + half.x, center.y + half.y, center.z + half.z),
      Vec3(center.x - half.x, center.y + half.y, center.z + half.z),
    ];

    final rotVerts = verts.map((v) => v.rotateY(rotY).rotateX(rotX)).toList();
    final proj = verts.map((v) => _project(v, rotY, rotX, size, zoom)).toList();

    const faces = [
      [0, 1, 2, 3], // back
      [4, 5, 6, 7], // front
      [0, 4, 7, 3], // left
      [1, 5, 6, 2], // right
      [3, 2, 6, 7], // top
      [0, 1, 5, 4], // bottom
    ];

    final lightDir = const Vec3(-0.4, 0.7, 0.6).normalized();
    final hsl = HSLColor.fromColor(color);

    final sortedFaces = <({List<int> idx, double z, double shade})>[];
    for (final f in faces) {
      final v0 = rotVerts[f[0]];
      final v1 = rotVerts[f[1]];
      final v2 = rotVerts[f[2]];
      final normal = (v1 - v0).cross(v2 - v0).normalized();
      final z = (rotVerts[f[0]].z +
              rotVerts[f[1]].z +
              rotVerts[f[2]].z +
              rotVerts[f[3]].z) *
          0.25;
      final shade = normal.dot(lightDir).abs().clamp(0.15, 1.0);
      sortedFaces.add((idx: f, z: z, shade: shade));
    }
    sortedFaces.sort((a, b) => a.z.compareTo(b.z));

    for (final f in sortedFaces) {
      final path = Path()
        ..moveTo(proj[f.idx[0]].offset.dx, proj[f.idx[0]].offset.dy)
        ..lineTo(proj[f.idx[1]].offset.dx, proj[f.idx[1]].offset.dy)
        ..lineTo(proj[f.idx[2]].offset.dx, proj[f.idx[2]].offset.dy)
        ..lineTo(proj[f.idx[3]].offset.dx, proj[f.idx[3]].offset.dy)
        ..close();

      final faceColor = hsl
          .withLightness(
            (hsl.lightness * (0.55 + f.shade * 0.6)).clamp(0.08, 0.94),
          )
          .toColor();
      canvas.drawPath(path, Paint()..color = faceColor);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.black.withValues(alpha: 0.08),
      );
    }
  }
}

class _TorusItem extends _RenderItem {
  final Vec3 center;
  final double radius;
  final double thickness;
  final Color color;

  _TorusItem({
    required this.center,
    required this.radius,
    required this.thickness,
    required this.color,
  });

  @override
  double depth(double rotY, double rotX) =>
      center.rotateY(rotY).rotateX(rotX).z;

  @override
  void paint(Canvas canvas, double rotY, double rotX, Size size, double zoom) {
    final p = _project(center, rotY, rotX, size, zoom);
    final rx = radius * p.scale;
    final tilt = math.cos(rotX).abs().clamp(0.25, 1.0);
    final ry = radius * p.scale * 0.36 * tilt + 2.0;
    final rect = Rect.fromCenter(center: p.offset, width: rx * 2, height: ry * 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (thickness * p.scale).clamp(2.0, 24.0)
      ..color = color;
    canvas.drawOval(rect, paint);
  }
}

class _FaceItem extends _RenderItem {
  final Vec3 anchor;
  final double headRadius;
  final FaceStyle style;

  _FaceItem({
    required this.anchor,
    required this.headRadius,
    required this.style,
  });

  @override
  double depth(double rotY, double rotX) =>
      anchor.rotateY(rotY).rotateX(rotX).z + 0.05;

  @override
  void paint(Canvas canvas, double rotY, double rotX, Size size, double zoom) {
    final rNormal = const Vec3(0, 0, 1).rotateY(rotY).rotateX(rotX);
    if (rNormal.z < 0.05) return; // Facing away

    final p = _project(anchor, rotY, rotX, size, zoom);
    final unit = headRadius * p.scale;
    final eyeSpacing = unit * 0.34;
    final leftEye = p.offset + Offset(-eyeSpacing, -unit * 0.08);
    final rightEye = p.offset + Offset(eyeSpacing, -unit * 0.08);
    final mouthPos = p.offset + Offset(0, unit * 0.16);

    final darkPaint = Paint()
      ..color = const Color(0xFF1F2430)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = const Color(0xFF1F2430)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (unit * 0.09).clamp(1.5, 5.0)
      ..strokeCap = StrokeCap.round;

    switch (style) {
      case FaceStyle.happy:
        _drawGlossyEye(canvas, leftEye, unit * 0.14, darkPaint);
        _drawGlossyEye(canvas, rightEye, unit * 0.14, darkPaint);
        _drawSmile(canvas, mouthPos, unit * 0.18, linePaint);
      case FaceStyle.wink:
        _drawGlossyEye(canvas, leftEye, unit * 0.14, darkPaint);
        canvas.drawArc(
          Rect.fromCenter(
            center: rightEye + Offset(0, unit * 0.03),
            width: unit * 0.24,
            height: unit * 0.18,
          ),
          math.pi,
          math.pi,
          false,
          linePaint,
        );
        _drawSmile(canvas, mouthPos, unit * 0.18, linePaint);
      case FaceStyle.starry:
        _drawStarEye(canvas, leftEye, unit * 0.16);
        _drawStarEye(canvas, rightEye, unit * 0.16);
        _drawSmile(canvas, mouthPos, unit * 0.18, linePaint);
      case FaceStyle.cool:
        final glassW = unit * 0.36;
        final glassH = unit * 0.22;
        final glassPaint = Paint()..color = const Color(0xFF1A1D29);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: leftEye, width: glassW, height: glassH),
            Radius.circular(unit * 0.06),
          ),
          glassPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: rightEye, width: glassW, height: glassH),
            Radius.circular(unit * 0.06),
          ),
          glassPaint,
        );
        canvas.drawLine(
          leftEye + Offset(glassW * 0.45, -glassH * 0.15),
          rightEye + Offset(-glassW * 0.45, -glassH * 0.15),
          linePaint,
        );
        _drawSmile(canvas, mouthPos, unit * 0.16, linePaint);
      case FaceStyle.shy:
        _drawGlossyEye(canvas, leftEye, unit * 0.12, darkPaint);
        _drawGlossyEye(canvas, rightEye, unit * 0.12, darkPaint);
        final blushPaint = Paint()
          ..color = const Color(0xFFFF758F).withValues(alpha: 0.55);
        canvas.drawOval(
          Rect.fromCenter(
            center: leftEye + Offset(-unit * 0.08, unit * 0.18),
            width: unit * 0.22,
            height: unit * 0.12,
          ),
          blushPaint,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: rightEye + Offset(unit * 0.08, unit * 0.18),
            width: unit * 0.22,
            height: unit * 0.12,
          ),
          blushPaint,
        );
        canvas.drawCircle(mouthPos, unit * 0.05, darkPaint);
      case FaceStyle.sleepy:
        canvas.drawArc(
          Rect.fromCenter(
            center: leftEye,
            width: unit * 0.24,
            height: unit * 0.14,
          ),
          0,
          math.pi,
          false,
          linePaint,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: rightEye,
            width: unit * 0.24,
            height: unit * 0.14,
          ),
          0,
          math.pi,
          false,
          linePaint,
        );
        canvas.drawCircle(mouthPos, unit * 0.06, darkPaint);
    }
  }

  void _drawGlossyEye(Canvas canvas, Offset center, double r, Paint fill) {
    canvas.drawCircle(center, r, fill);
    canvas.drawCircle(
      center + Offset(-r * 0.3, -r * 0.3),
      r * 0.34,
      Paint()..color = Colors.white,
    );
  }

  void _drawSmile(Canvas canvas, Offset center, double w, Paint stroke) {
    canvas.drawArc(
      Rect.fromCenter(center: center, width: w, height: w * 0.65),
      0.15,
      math.pi - 0.3,
      false,
      stroke,
    );
  }

  void _drawStarEye(Canvas canvas, Offset center, double r) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final rad = i.isEven ? r : r * 0.42;
      final pt = center + Offset(math.cos(angle) * rad, math.sin(angle) * rad);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFC300));
  }
}

class Toy3DPainter extends CustomPainter {
  final ToyDefinition toy;
  final ToyCustomization customization;
  final double rotY;
  final double rotX;
  final double zoom;

  const Toy3DPainter({
    required this.toy,
    required this.customization,
    this.rotY = 0.35,
    this.rotX = -0.18,
    this.zoom = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Soft ground shadow
    final shadowRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.84),
      width: size.width * 0.46 * zoom,
      height: size.height * 0.1 * zoom,
    );
    canvas.drawOval(
      shadowRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black.withValues(alpha: 0.22),
            Colors.black.withValues(alpha: 0.0),
          ],
        ).createShader(shadowRect),
    );

    final items = _buildToyPrimitives();
    items.sort(
      (a, b) => a.depth(rotY, rotX).compareTo(b.depth(rotY, rotX)),
    );

    for (final item in items) {
      item.paint(canvas, rotY, rotX, size, zoom);
    }
  }

  List<_RenderItem> _buildToyPrimitives() {
    final bodyColor = customization.bodyColorOverride ?? toy.defaultColor;
    final accentColor = customization.accentColorOverride ?? toy.accentColor;
    final shoeColor = _shoeColorFor(customization.shoeStyle, accentColor);
    final items = <_RenderItem>[];

    // Shoes / Feet
    final footRadius = switch (customization.shoeStyle) {
      ShoeStyle.boots => 0.24,
      ShoeStyle.cloud => 0.26,
      _ => 0.20,
    };
    items.add(_SphereItem(
      center: const Vec3(-0.34, -0.82, 0.12),
      radius: footRadius,
      color: shoeColor,
      scaleX: 1.15,
      scaleY: 0.78,
    ));
    items.add(_SphereItem(
      center: const Vec3(0.34, -0.82, 0.12),
      radius: footRadius,
      color: shoeColor,
      scaleX: 1.15,
      scaleY: 0.78,
    ));
    if (customization.shoeStyle == ShoeStyle.roller) {
      items.add(_SphereItem(
        center: const Vec3(-0.34, -0.99, 0.12),
        radius: 0.09,
        color: const Color(0xFF2B2D42),
      ));
      items.add(_SphereItem(
        center: const Vec3(0.34, -0.99, 0.12),
        radius: 0.09,
        color: const Color(0xFF2B2D42),
      ));
    } else if (customization.shoeStyle == ShoeStyle.star) {
      items.add(_SphereItem(
        center: const Vec3(-0.34, -0.80, 0.30),
        radius: 0.08,
        color: const Color(0xFFFFD166),
      ));
      items.add(_SphereItem(
        center: const Vec3(0.34, -0.80, 0.30),
        radius: 0.08,
        color: const Color(0xFFFFD166),
      ));
    }

    // Body + Series-specific silhouette
    switch (toy.seriesId) {
      case ToySeriesId.cosmicBots:
        items.add(_BoxItem(
          center: const Vec3(0, -0.32, 0),
          half: const Vec3(0.46, 0.42, 0.36),
          color: bodyColor,
        ));
        items.add(_BoxItem(
          center: const Vec3(0, 0.42, 0),
          half: const Vec3(0.54, 0.44, 0.44),
          color: bodyColor,
        ));
        // Antenna
        items.add(_CapsuleItem(
          a: const Vec3(0, 0.86, 0),
          b: const Vec3(0, 1.15, 0),
          radius: 0.04,
          color: accentColor,
        ));
        items.add(_SphereItem(
          center: const Vec3(0, 1.22, 0),
          radius: 0.12,
          color: accentColor,
        ));
        // Chest core
        items.add(_SphereItem(
          center: const Vec3(0, -0.28, 0.38),
          radius: 0.15,
          color: accentColor,
        ));
      case ToySeriesId.woodland:
        items.add(_SphereItem(
          center: const Vec3(0, -0.30, 0),
          radius: 0.52,
          color: bodyColor,
          scaleY: 0.92,
        ));
        items.add(_SphereItem(
          center: const Vec3(0, 0.40, 0),
          radius: 0.54,
          color: bodyColor,
        ));
        // Leaf ears / cap
        items.add(_ConeItem(
          base: const Vec3(-0.36, 0.80, 0),
          tip: const Vec3(-0.56, 1.18, 0),
          baseRadius: 0.18,
          color: accentColor,
        ));
        items.add(_ConeItem(
          base: const Vec3(0.36, 0.80, 0),
          tip: const Vec3(0.56, 1.18, 0),
          baseRadius: 0.18,
          color: accentColor,
        ));
      case ToySeriesId.pocketDragons:
        items.add(_SphereItem(
          center: const Vec3(0, -0.30, 0),
          radius: 0.50,
          color: bodyColor,
        ));
        items.add(_SphereItem(
          center: const Vec3(0, -0.30, 0.24),
          radius: 0.34,
          color: accentColor,
        ));
        items.add(_SphereItem(
          center: const Vec3(0, 0.40, 0),
          radius: 0.52,
          color: bodyColor,
        ));
        // Horns + wings
        items.add(_ConeItem(
          base: const Vec3(-0.26, 0.82, -0.05),
          tip: const Vec3(-0.42, 1.20, -0.15),
          baseRadius: 0.12,
          color: accentColor,
        ));
        items.add(_ConeItem(
          base: const Vec3(0.26, 0.82, -0.05),
          tip: const Vec3(0.42, 1.20, -0.15),
          baseRadius: 0.12,
          color: accentColor,
        ));
        items.add(_ConeItem(
          base: const Vec3(-0.44, -0.15, -0.32),
          tip: const Vec3(-0.96, 0.25, -0.52),
          baseRadius: 0.20,
          color: accentColor,
        ));
        items.add(_ConeItem(
          base: const Vec3(0.44, -0.15, -0.32),
          tip: const Vec3(0.96, 0.25, -0.52),
          baseRadius: 0.20,
          color: accentColor,
        ));
      case ToySeriesId.bloomBuddies:
        items.add(_SphereItem(
          center: const Vec3(0, -0.34, 0),
          radius: 0.46,
          color: const Color(0xFF52B788),
          scaleY: 1.05,
        ));
        items.add(_SphereItem(
          center: const Vec3(0, 0.40, 0),
          radius: 0.50,
          color: bodyColor,
        ));
        // Flower petals around head
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3 + toy.variantIndex * 0.2;
          items.add(_SphereItem(
            center: Vec3(
              math.cos(a) * 0.56,
              0.40 + math.sin(a) * 0.56,
              -0.12,
            ),
            radius: 0.22,
            color: accentColor,
          ));
        }
      case ToySeriesId.oceanPals:
        items.add(_SphereItem(
          center: const Vec3(0, -0.26, 0),
          radius: 0.52,
          color: bodyColor,
          scaleY: 0.9,
        ));
        items.add(_SphereItem(
          center: const Vec3(0, 0.36, 0),
          radius: 0.54,
          color: bodyColor,
        ));
        // Side fins + top fin
        items.add(_ConeItem(
          base: const Vec3(-0.48, -0.24, 0),
          tip: const Vec3(-0.90, -0.45, -0.10),
          baseRadius: 0.16,
          color: accentColor,
        ));
        items.add(_ConeItem(
          base: const Vec3(0.48, -0.24, 0),
          tip: const Vec3(0.90, -0.45, -0.10),
          baseRadius: 0.16,
          color: accentColor,
        ));
        items.add(_ConeItem(
          base: const Vec3(0, 0.84, -0.05),
          tip: const Vec3(0, 1.24, -0.25),
          baseRadius: 0.15,
          color: accentColor,
        ));
      case ToySeriesId.sweetSprites:
        items.add(_SphereItem(
          center: const Vec3(0, -0.28, 0),
          radius: 0.54,
          color: bodyColor,
          scaleY: 0.88,
        ));
        items.add(_SphereItem(
          center: const Vec3(0, 0.38, 0),
          radius: 0.52,
          color: bodyColor,
        ));
        // Frosting swirl / cherry on top
        items.add(_SphereItem(
          center: const Vec3(0, 0.86, 0),
          radius: 0.32,
          color: accentColor,
          scaleY: 0.55,
        ));
        items.add(_SphereItem(
          center: const Vec3(0, 1.06, 0),
          radius: 0.13,
          color: const Color(0xFFFF4D6D),
        ));
      case ToySeriesId.moonMages:
        items.add(_ConeItem(
          base: const Vec3(0, -0.72, 0),
          tip: const Vec3(0, 0.25, 0),
          baseRadius: 0.52,
          color: bodyColor,
        ));
        items.add(_SphereItem(
          center: const Vec3(0, 0.40, 0),
          radius: 0.48,
          color: const Color(0xFFFFE8D6),
        ));
        // Wizard hat
        items.add(_TorusItem(
          center: const Vec3(0, 0.78, 0),
          radius: 0.56,
          thickness: 0.09,
          color: bodyColor,
        ));
        items.add(_ConeItem(
          base: const Vec3(0, 0.78, 0),
          tip: const Vec3(0.12, 1.48, -0.08),
          baseRadius: 0.40,
          color: bodyColor,
        ));
        items.add(_SphereItem(
          center: const Vec3(0.12, 1.48, -0.08),
          radius: 0.10,
          color: accentColor,
        ));
      case ToySeriesId.snowyFriends:
        items.add(_SphereItem(
          center: const Vec3(0, -0.32, 0),
          radius: 0.56,
          color: bodyColor,
        ));
        items.add(_SphereItem(
          center: const Vec3(0, 0.42, 0),
          radius: 0.48,
          color: bodyColor,
        ));
        // Cozy scarf + earmuffs
        items.add(_TorusItem(
          center: const Vec3(0, 0.04, 0),
          radius: 0.44,
          thickness: 0.12,
          color: accentColor,
        ));
        items.add(_SphereItem(
          center: const Vec3(-0.52, 0.44, 0),
          radius: 0.16,
          color: accentColor,
        ));
        items.add(_SphereItem(
          center: const Vec3(0.52, 0.44, 0),
          radius: 0.16,
          color: accentColor,
        ));
      case ToySeriesId.tinyKnights:
        items.add(_BoxItem(
          center: const Vec3(0, -0.32, 0),
          half: const Vec3(0.45, 0.42, 0.34),
          color: bodyColor,
        ));
        items.add(_SphereItem(
          center: const Vec3(0, 0.40, 0),
          radius: 0.52,
          color: bodyColor,
        ));
        // Plume + shield
        items.add(_ConeItem(
          base: const Vec3(0, 0.88, 0),
          tip: const Vec3(0, 1.32, -0.18),
          baseRadius: 0.18,
          color: accentColor,
        ));
        items.add(_BoxItem(
          center: const Vec3(-0.62, -0.26, 0.18),
          half: const Vec3(0.08, 0.28, 0.22),
          color: accentColor,
        ));
      case ToySeriesId.partyPets:
        items.add(_SphereItem(
          center: const Vec3(0, -0.30, 0),
          radius: 0.50,
          color: bodyColor,
        ));
        items.add(_SphereItem(
          center: const Vec3(0, 0.40, 0),
          radius: 0.52,
          color: bodyColor,
        ));
        // Bouncy ears + bowtie
        items.add(_CapsuleItem(
          a: const Vec3(-0.34, 0.78, 0),
          b: const Vec3(-0.56, 1.18, 0),
          radius: 0.13,
          color: accentColor,
        ));
        items.add(_CapsuleItem(
          a: const Vec3(0.34, 0.78, 0),
          b: const Vec3(0.56, 1.18, 0),
          radius: 0.13,
          color: accentColor,
        ));
        items.add(_SphereItem(
          center: const Vec3(0, 0.02, 0.44),
          radius: 0.11,
          color: accentColor,
        ));
    }

    // Arms
    items.add(_CapsuleItem(
      a: const Vec3(-0.46, -0.14, 0),
      b: Vec3(-0.72, -0.44 + (toy.variantIndex % 2) * 0.15, 0.12),
      radius: 0.13,
      color: bodyColor,
    ));
    items.add(_CapsuleItem(
      a: const Vec3(0.46, -0.14, 0),
      b: Vec3(0.72, -0.44 + ((toy.variantIndex + 1) % 2) * 0.15, 0.12),
      radius: 0.13,
      color: bodyColor,
    ));

    // Customization Accessories
    switch (customization.accessoryStyle) {
      case AccessoryStyle.none:
        break;
      case AccessoryStyle.crown:
        items.add(_TorusItem(
          center: const Vec3(0, 0.92, 0),
          radius: 0.28,
          thickness: 0.08,
          color: const Color(0xFFFFD166),
        ));
        items.add(_ConeItem(
          base: const Vec3(-0.18, 0.95, 0),
          tip: const Vec3(-0.22, 1.24, 0),
          baseRadius: 0.08,
          color: const Color(0xFFFFD166),
        ));
        items.add(_ConeItem(
          base: const Vec3(0, 0.95, 0.14),
          tip: const Vec3(0, 1.30, 0.14),
          baseRadius: 0.09,
          color: const Color(0xFFFFD166),
        ));
        items.add(_ConeItem(
          base: const Vec3(0.18, 0.95, 0),
          tip: const Vec3(0.22, 1.24, 0),
          baseRadius: 0.08,
          color: const Color(0xFFFFD166),
        ));
      case AccessoryStyle.bow:
        items.add(_SphereItem(
          center: const Vec3(-0.18, 0.90, 0.22),
          radius: 0.14,
          color: const Color(0xFFFF4D6D),
          scaleX: 1.3,
        ));
        items.add(_SphereItem(
          center: const Vec3(0.18, 0.90, 0.22),
          radius: 0.14,
          color: const Color(0xFFFF4D6D),
          scaleX: 1.3,
        ));
        items.add(_SphereItem(
          center: const Vec3(0, 0.90, 0.25),
          radius: 0.08,
          color: const Color(0xFFFF85A1),
        ));
      case AccessoryStyle.halo:
        items.add(_TorusItem(
          center: const Vec3(0, 1.22, 0),
          radius: 0.42,
          thickness: 0.07,
          color: const Color(0xFFFFE66D),
        ));
      case AccessoryStyle.cap:
        items.add(_SphereItem(
          center: const Vec3(0, 0.78, 0),
          radius: 0.42,
          color: const Color(0xFFEF476F),
          scaleY: 0.55,
        ));
        items.add(_BoxItem(
          center: const Vec3(0, 0.74, 0.42),
          half: const Vec3(0.28, 0.05, 0.20),
          color: const Color(0xFFEF476F),
        ));
      case AccessoryStyle.headband:
        items.add(_TorusItem(
          center: const Vec3(0, 0.76, 0),
          radius: 0.46,
          thickness: 0.07,
          color: const Color(0xFF06D6A0),
        ));
    }

    // Face anchored on front of head
    items.add(_FaceItem(
      anchor: const Vec3(0, 0.42, 0.52),
      headRadius: 0.50,
      style: customization.faceStyle,
    ));

    return items;
  }

  Color _shoeColorFor(ShoeStyle style, Color accent) {
    return switch (style) {
      ShoeStyle.classic => accent,
      ShoeStyle.sneakers => const Color(0xFFEF476F),
      ShoeStyle.boots => const Color(0xFF6B4226),
      ShoeStyle.roller => const Color(0xFF118AB2),
      ShoeStyle.cloud => const Color(0xFFF8F9FA),
      ShoeStyle.star => const Color(0xFFFFB703),
    };
  }

  @override
  bool shouldRepaint(covariant Toy3DPainter oldDelegate) {
    return oldDelegate.rotY != rotY ||
        oldDelegate.rotX != rotX ||
        oldDelegate.zoom != zoom ||
        oldDelegate.toy.id != toy.id ||
        oldDelegate.customization.bodyColorOverride !=
            customization.bodyColorOverride ||
        oldDelegate.customization.accentColorOverride !=
            customization.accentColorOverride ||
        oldDelegate.customization.faceStyle != customization.faceStyle ||
        oldDelegate.customization.accessoryStyle !=
            customization.accessoryStyle ||
        oldDelegate.customization.shoeStyle != customization.shoeStyle;
  }
}

class FoilCapsulePainter extends CustomPainter {
  final double peelProgress; // 0.0 (sealed) -> 1.0 (peeled open)
  final Color primaryColor;
  final Color secondaryColor;
  final double wobble;

  const FoilCapsulePainter({
    required this.peelProgress,
    required this.primaryColor,
    required this.secondaryColor,
    this.wobble = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.52);
    final radius = math.min(size.width, size.height) * 0.34;

    // Ground shadow
    final shadowRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + radius * 1.25),
      width: radius * 1.5,
      height: radius * 0.3,
    );
    canvas.drawOval(
      shadowRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black.withValues(alpha: 0.24),
            Colors.black.withValues(alpha: 0.0),
          ],
        ).createShader(shadowRect),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.sin(wobble * math.pi * 2) * 0.06 * (1 - peelProgress * 0.5));

    final eggRect = Rect.fromCenter(
      center: Offset.zero,
      width: radius * 1.85,
      height: radius * 2.25,
    );

    // Inner glowing core visible as foil peels
    final innerPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.3),
        colors: [
          Colors.white,
          secondaryColor,
          primaryColor,
        ],
      ).createShader(eggRect);
    canvas.drawOval(eggRect, innerPaint);

    // Metallic foil wrapper layers that peel away
    final foilRemaining = (1.0 - peelProgress).clamp(0.0, 1.0);
    if (foilRemaining > 0.02) {
      canvas.save();
      final clipTop = -eggRect.height * 0.5 + eggRect.height * peelProgress * 0.92;
      canvas.clipRect(
        Rect.fromLTRB(
          -eggRect.width,
          clipTop,
          eggRect.width,
          eggRect.height,
        ),
      );

      final foilPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF8F9FA),
            primaryColor.withValues(alpha: 0.92),
            const Color(0xFFE9ECEF),
            secondaryColor.withValues(alpha: 0.92),
          ],
          stops: const [0.0, 0.35, 0.65, 1.0],
        ).createShader(eggRect);
      canvas.drawOval(eggRect, foilPaint);

      // Foil crinkle stripes
      final stripePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;
      for (var i = -2; i <= 2; i++) {
        canvas.drawLine(
          Offset(-radius * 0.85, i * radius * 0.32),
          Offset(radius * 0.85, i * radius * 0.32 - 12),
          stripePaint,
        );
      }

      // Curled peel lip at the tear line
      if (peelProgress > 0.04) {
        final curlRect = Rect.fromCenter(
          center: Offset(0, clipTop + 6),
          width: radius * 1.65 * (1 - peelProgress * 0.3),
          height: 16,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(curlRect, const Radius.circular(8)),
          Paint()
            ..color = const Color(0xFFFFF3B0).withValues(alpha: 0.95),
        );
      }
      canvas.restore();
    }

    // Specular capsule highlight
    final specRect = Rect.fromCenter(
      center: Offset(-radius * 0.35, -radius * 0.42),
      width: radius * 0.45,
      height: radius * 0.72,
    );
    canvas.save();
    canvas.translate(specRect.center.dx, specRect.center.dy);
    canvas.rotate(-0.35);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: specRect.width,
        height: specRect.height,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.38),
    );
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FoilCapsulePainter oldDelegate) {
    return oldDelegate.peelProgress != peelProgress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.wobble != wobble;
  }
}
