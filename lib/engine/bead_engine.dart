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

Uint8List renderPatternJpeg(Pattern pattern, {required bool showGrid}) {
  final longestSide = math.max(pattern.width, pattern.height);
  final cellSize = (3600 / longestSide).floor().clamp(4, 48);
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
