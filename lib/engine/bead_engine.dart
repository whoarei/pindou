import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/bead_color.dart';
import '../models/crop_spec.dart';
import '../models/pattern.dart';
import 'color_math.dart';

class BeadEngineInput {
  const BeadEngineInput({
    required this.bytes,
    required this.targetWidth,
    required this.targetHeight,
    required this.palette,
    required this.maximumColors,
    required this.dither,
    required this.crop,
  });

  final Uint8List bytes;
  final int targetWidth;
  final int targetHeight;
  final BeadPalette palette;
  final int maximumColors;
  final bool dither;
  final CropSpec crop;
}

Pattern generatePattern(BeadEngineInput input) {
  var source = img.decodeImage(input.bytes);
  if (source == null) {
    throw const FormatException('无法解码图片，请选择有效的 JPG 或 PNG 文件。');
  }
  source = img.bakeOrientation(source);

  final turns = input.crop.quarterTurns % 4;
  if (turns != 0) {
    source = img.copyRotate(source, angle: turns * 90);
  }

  final cropX = (input.crop.left * source.width).round().clamp(
    0,
    source.width - 1,
  );
  final cropY = (input.crop.top * source.height).round().clamp(
    0,
    source.height - 1,
  );
  final cropWidth = (input.crop.width * source.width).round().clamp(
    1,
    source.width - cropX,
  );
  final cropHeight = (input.crop.height * source.height).round().clamp(
    1,
    source.height - cropY,
  );
  source = img.copyCrop(
    source,
    x: cropX,
    y: cropY,
    width: cropWidth,
    height: cropHeight,
  );

  final sampled = img.copyResize(
    source,
    width: input.targetWidth,
    height: input.targetHeight,
    interpolation: img.Interpolation.average,
  );

  final pixelCount = input.targetWidth * input.targetHeight;
  final reds = List<double>.filled(pixelCount, 0);
  final greens = List<double>.filled(pixelCount, 0);
  final blues = List<double>.filled(pixelCount, 0);
  var pixelIndex = 0;
  for (final pixel in sampled) {
    final alpha = pixel.a.toDouble() / pixel.maxChannelValue;
    reds[pixelIndex] = pixel.r.toDouble() * alpha + 255 * (1 - alpha);
    greens[pixelIndex] = pixel.g.toDouble() * alpha + 255 * (1 - alpha);
    blues[pixelIndex] = pixel.b.toDouble() * alpha + 255 * (1 - alpha);
    pixelIndex++;
  }

  final allLabs = input.palette.colors
      .map((color) => rgbToLab(color.red, color.green, color.blue))
      .toList(growable: false);
  final roughCounts = List<int>.filled(input.palette.colors.length, 0);
  for (var i = 0; i < pixelCount; i++) {
    final sourceLab = rgbToLab(reds[i], greens[i], blues[i]);
    roughCounts[_nearestColor(sourceLab, allLabs)]++;
  }

  final ranked = List<int>.generate(input.palette.colors.length, (i) => i)
    ..sort((a, b) => roughCounts[b].compareTo(roughCounts[a]));
  final colorLimit = input.maximumColors.clamp(1, ranked.length);
  final selectedOriginalIndices = ranked
      .take(colorLimit)
      .toList(growable: false);
  final colors = selectedOriginalIndices
      .map((index) => input.palette.colors[index])
      .toList(growable: false);
  final labs = selectedOriginalIndices
      .map((index) => allLabs[index])
      .toList(growable: false);

  final indices = List<int>.filled(pixelCount, 0);
  final counts = List<int>.filled(colors.length, 0);
  if (input.dither) {
    _matchWithDithering(
      width: input.targetWidth,
      height: input.targetHeight,
      reds: reds,
      greens: greens,
      blues: blues,
      colors: colors,
      labs: labs,
      output: indices,
      counts: counts,
    );
  } else {
    for (var i = 0; i < pixelCount; i++) {
      final nearest = _nearestColor(
        rgbToLab(reds[i], greens[i], blues[i]),
        labs,
      );
      indices[i] = nearest;
      counts[nearest]++;
    }
  }

  return Pattern(
    width: input.targetWidth,
    height: input.targetHeight,
    colorIndices: indices,
    colors: colors,
    counts: counts,
  );
}

int _nearestColor(LabColor source, List<LabColor> candidates) {
  var nearest = 0;
  var nearestDistance = double.infinity;
  for (var i = 0; i < candidates.length; i++) {
    final distance = labDistanceSquared(source, candidates[i]);
    if (distance < nearestDistance) {
      nearestDistance = distance;
      nearest = i;
    }
  }
  return nearest;
}

void _matchWithDithering({
  required int width,
  required int height,
  required List<double> reds,
  required List<double> greens,
  required List<double> blues,
  required List<BeadColor> colors,
  required List<LabColor> labs,
  required List<int> output,
  required List<int> counts,
}) {
  final redErrors = List<double>.filled(width * height, 0);
  final greenErrors = List<double>.filled(width * height, 0);
  final blueErrors = List<double>.filled(width * height, 0);

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final index = y * width + x;
      final red = (reds[index] + redErrors[index]).clamp(0.0, 255.0);
      final green = (greens[index] + greenErrors[index]).clamp(0.0, 255.0);
      final blue = (blues[index] + blueErrors[index]).clamp(0.0, 255.0);
      final nearest = _nearestColor(rgbToLab(red, green, blue), labs);
      final match = colors[nearest];
      output[index] = nearest;
      counts[nearest]++;

      final errorRed = red - match.red;
      final errorGreen = green - match.green;
      final errorBlue = blue - match.blue;

      void distribute(int target, double factor) {
        redErrors[target] += errorRed * factor;
        greenErrors[target] += errorGreen * factor;
        blueErrors[target] += errorBlue * factor;
      }

      if (x + 1 < width) distribute(index + 1, 7 / 16);
      if (y + 1 < height) {
        if (x > 0) distribute(index + width - 1, 3 / 16);
        distribute(index + width, 5 / 16);
        if (x + 1 < width) distribute(index + width + 1, 1 / 16);
      }
    }
  }
}

Uint8List renderPatternJpeg(
  Pattern pattern, {
  required bool showGrid,
  required bool showColorCodes,
}) {
  final longestSide = math.max(pattern.width, pattern.height);
  final regularCellSize = (3600 / longestSide).floor().clamp(4, 48);
  final longestCode = pattern.colors.fold<int>(
    1,
    (length, color) => math.max(length, color.code.length),
  );
  final codeCellSize = (longestCode * 4 + 2).clamp(18, 30);
  final cellSize = showColorCodes
      ? math.max(regularCellSize, codeCellSize)
      : regularCellSize;
  const outerBorder = 2;
  final output = img.Image(
    width: pattern.width * cellSize + outerBorder * 2,
    height: pattern.height * cellSize + outerBorder * 2,
    numChannels: 3,
  );
  img.fill(output, color: img.ColorRgb8(255, 255, 255));

  for (var y = 0; y < pattern.height; y++) {
    for (var x = 0; x < pattern.width; x++) {
      final color = pattern.colors[pattern.colorIndices[y * pattern.width + x]];
      final startX = outerBorder + x * cellSize;
      final startY = outerBorder + y * cellSize;
      final endX = startX + cellSize - 1;
      final endY = startY + cellSize - 1;
      img.fillRect(
        output,
        x1: startX,
        y1: startY,
        x2: endX,
        y2: endY,
        color: img.ColorRgb8(color.red, color.green, color.blue),
      );
      if (showGrid) {
        final gridColor = img.ColorRgb8(75, 78, 82);
        img.drawLine(
          output,
          x1: startX,
          y1: startY,
          x2: endX,
          y2: startY,
          color: gridColor,
        );
        img.drawLine(
          output,
          x1: startX,
          y1: startY,
          x2: startX,
          y2: endY,
          color: gridColor,
        );
      }
      if (showColorCodes) {
        _drawTinyCode(
          output,
          code: color.code,
          startX: startX,
          startY: startY,
          cellSize: cellSize,
          foreground: _codeForeground(color),
        );
      }
    }
  }
  if (showGrid) {
    img.drawRect(
      output,
      x1: outerBorder,
      y1: outerBorder,
      x2: output.width - outerBorder - 1,
      y2: output.height - outerBorder - 1,
      color: img.ColorRgb8(45, 48, 52),
      thickness: outerBorder,
    );
  }
  return img.JpegEncoder(quality: 94).encode(output);
}

img.ColorRgb8 _codeForeground(BeadColor color) {
  final luminance =
      color.red * 0.299 + color.green * 0.587 + color.blue * 0.114;
  return luminance >= 150
      ? img.ColorRgb8(24, 26, 28)
      : img.ColorRgb8(250, 250, 248);
}

void _drawTinyCode(
  img.Image image, {
  required String code,
  required int startX,
  required int startY,
  required int cellSize,
  required img.ColorRgb8 foreground,
}) {
  final glyphs = <List<int>>[
    for (final unit in code.toUpperCase().codeUnits)
      _tinyGlyphs[unit] ?? _unknownTinyGlyph,
  ];
  if (glyphs.isEmpty) return;
  final unitsWide = glyphs.length * 4 - 1;
  final scale = math.max(
    1,
    math.min((cellSize - 2) ~/ unitsWide, (cellSize - 2) ~/ 5),
  );
  final pixelWidth = unitsWide * scale;
  final pixelHeight = 5 * scale;
  final originX = startX + (cellSize - pixelWidth) ~/ 2;
  final originY = startY + (cellSize - pixelHeight) ~/ 2;

  for (var glyphIndex = 0; glyphIndex < glyphs.length; glyphIndex++) {
    final glyph = glyphs[glyphIndex];
    for (var row = 0; row < glyph.length; row++) {
      for (var column = 0; column < 3; column++) {
        if (glyph[row] & (1 << (2 - column)) == 0) continue;
        final x = originX + (glyphIndex * 4 + column) * scale;
        final y = originY + row * scale;
        img.fillRect(
          image,
          x1: x,
          y1: y,
          x2: x + scale - 1,
          y2: y + scale - 1,
          color: foreground,
        );
      }
    }
  }
}

const _unknownTinyGlyph = <int>[0x7, 0x1, 0x2, 0x0, 0x2];

const _tinyGlyphs = <int, List<int>>{
  0x30: <int>[0x7, 0x5, 0x5, 0x5, 0x7],
  0x31: <int>[0x2, 0x6, 0x2, 0x2, 0x7],
  0x32: <int>[0x7, 0x1, 0x7, 0x4, 0x7],
  0x33: <int>[0x7, 0x1, 0x7, 0x1, 0x7],
  0x34: <int>[0x5, 0x5, 0x7, 0x1, 0x1],
  0x35: <int>[0x7, 0x4, 0x7, 0x1, 0x7],
  0x36: <int>[0x7, 0x4, 0x7, 0x5, 0x7],
  0x37: <int>[0x7, 0x1, 0x1, 0x2, 0x2],
  0x38: <int>[0x7, 0x5, 0x7, 0x5, 0x7],
  0x39: <int>[0x7, 0x5, 0x7, 0x1, 0x7],
  0x41: <int>[0x2, 0x5, 0x7, 0x5, 0x5],
  0x42: <int>[0x6, 0x5, 0x6, 0x5, 0x6],
  0x43: <int>[0x3, 0x4, 0x4, 0x4, 0x3],
  0x44: <int>[0x6, 0x5, 0x5, 0x5, 0x6],
  0x45: <int>[0x7, 0x4, 0x6, 0x4, 0x7],
  0x46: <int>[0x7, 0x4, 0x6, 0x4, 0x4],
  0x47: <int>[0x3, 0x4, 0x5, 0x5, 0x3],
  0x48: <int>[0x5, 0x5, 0x7, 0x5, 0x5],
  0x49: <int>[0x7, 0x2, 0x2, 0x2, 0x7],
  0x4a: <int>[0x1, 0x1, 0x1, 0x5, 0x2],
  0x4b: <int>[0x5, 0x5, 0x6, 0x5, 0x5],
  0x4c: <int>[0x4, 0x4, 0x4, 0x4, 0x7],
  0x4d: <int>[0x5, 0x7, 0x7, 0x5, 0x5],
  0x4e: <int>[0x5, 0x7, 0x7, 0x7, 0x5],
  0x4f: <int>[0x2, 0x5, 0x5, 0x5, 0x2],
  0x50: <int>[0x6, 0x5, 0x6, 0x4, 0x4],
  0x51: <int>[0x2, 0x5, 0x5, 0x7, 0x3],
  0x52: <int>[0x6, 0x5, 0x6, 0x5, 0x5],
  0x53: <int>[0x3, 0x4, 0x2, 0x1, 0x6],
  0x54: <int>[0x7, 0x2, 0x2, 0x2, 0x2],
  0x55: <int>[0x5, 0x5, 0x5, 0x5, 0x7],
  0x56: <int>[0x5, 0x5, 0x5, 0x5, 0x2],
  0x57: <int>[0x5, 0x5, 0x7, 0x7, 0x5],
  0x58: <int>[0x5, 0x5, 0x2, 0x5, 0x5],
  0x59: <int>[0x5, 0x5, 0x2, 0x2, 0x2],
  0x5a: <int>[0x7, 0x1, 0x2, 0x4, 0x7],
  0x2d: <int>[0x0, 0x0, 0x7, 0x0, 0x0],
};
