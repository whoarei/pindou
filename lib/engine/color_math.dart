import 'dart:math' as math;

class LabColor {
  const LabColor(this.l, this.a, this.b);

  final double l;
  final double a;
  final double b;
}

LabColor rgbToLab(num red, num green, num blue) {
  double linearize(double channel) {
    final value = channel / 255;
    return value > 0.04045
        ? math.pow((value + 0.055) / 1.055, 2.4).toDouble()
        : value / 12.92;
  }

  final r = linearize(red.toDouble());
  final g = linearize(green.toDouble());
  final b = linearize(blue.toDouble());

  var x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047;
  var y = (r * 0.2126 + g * 0.7152 + b * 0.0722);
  var z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883;

  double transform(double value) => value > 0.008856
      ? math.pow(value, 1 / 3).toDouble()
      : 7.787 * value + 16 / 116;

  x = transform(x);
  y = transform(y);
  z = transform(z);

  return LabColor(116 * y - 16, 500 * (x - y), 200 * (y - z));
}

double labDistanceSquared(LabColor first, LabColor second) {
  final dl = first.l - second.l;
  final da = first.a - second.a;
  final db = first.b - second.b;
  return dl * dl + da * da + db * db;
}
