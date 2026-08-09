import 'dart:typed_data';

import 'package:pindou_studio/engine/bead_engine.dart';
import 'package:pindou_studio/engine/color_math.dart';
import 'package:pindou_studio/models/bead_color.dart';
import 'package:pindou_studio/models/crop_spec.dart';
import 'package:pindou_studio/models/pattern.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  const palette = BeadPalette(
    brand: 'Test',
    colors: [
      BeadColor(code: 'R', name: 'Red', red: 230, green: 20, blue: 30),
      BeadColor(code: 'B', name: 'Blue', red: 20, green: 50, blue: 220),
      BeadColor(code: 'W', name: 'White', red: 250, green: 250, blue: 250),
    ],
  );

  test('generates a bounded-color pattern and matching statistics', () {
    final source = img.Image(width: 4, height: 2);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        if (x < 2) {
          source.setPixelRgb(x, y, 240, 10, 20);
        } else {
          source.setPixelRgb(x, y, 10, 40, 235);
        }
      }
    }
    final pattern = generatePattern(
      BeadEngineInput(
        bytes: Uint8List.fromList(img.encodePng(source)),
        targetWidth: 4,
        targetHeight: 2,
        palette: palette,
        maximumColors: 2,
        dither: false,
        crop: CropSpec.full,
      ),
    );

    expect(pattern.width, 4);
    expect(pattern.height, 2);
    expect(pattern.colors, hasLength(2));
    expect(pattern.counts.fold(0, (sum, count) => sum + count), 8);
    expect(pattern.totalBeads, 8);
  });

  test('renders decodable JPEG layers for grid and color codes', () {
    final source = img.Image(width: 2, height: 2)
      ..setPixelRgb(0, 0, 230, 20, 30)
      ..setPixelRgb(1, 0, 20, 50, 220)
      ..setPixelRgb(0, 1, 20, 50, 220)
      ..setPixelRgb(1, 1, 230, 20, 30);
    final pattern = generatePattern(
      BeadEngineInput(
        bytes: Uint8List.fromList(img.encodePng(source)),
        targetWidth: 2,
        targetHeight: 2,
        palette: palette,
        maximumColors: 2,
        dither: true,
        crop: const CropSpec(quarterTurns: 1),
      ),
    );

    final jpeg = renderPatternJpeg(
      pattern,
      showGrid: true,
      showColorCodes: false,
    );
    final decoded = img.decodeJpg(jpeg);
    expect(decoded, isNotNull);
    expect(decoded!.width, greaterThan(10));
    expect(decoded.height, greaterThan(10));

    final jpegWithCodes = renderPatternJpeg(
      pattern,
      showGrid: true,
      showColorCodes: true,
    );
    expect(img.decodeJpg(jpegWithCodes), isNotNull);
    expect(jpegWithCodes, isNot(equals(jpeg)));
  });

  test('replaces selected cells and rebuilds color counts', () {
    const red = BeadColor(
      code: 'R',
      name: 'Red',
      red: 230,
      green: 20,
      blue: 30,
    );
    const blue = BeadColor(
      code: 'B',
      name: 'Blue',
      red: 20,
      green: 50,
      blue: 220,
    );
    const pattern = Pattern(
      width: 2,
      height: 2,
      colorIndices: [0, 0, 1, 1],
      colors: [red, blue],
      counts: [2, 2],
    );

    final replaced = pattern.replaceCells(const [0, 1], blue);

    expect(replaced.colors, [blue]);
    expect(replaced.colorIndices, [0, 0, 0, 0]);
    expect(replaced.counts, [4]);
  });

  test('LAB conversion keeps nearby colors closer', () {
    final white = rgbToLab(255, 255, 255);
    final nearWhite = rgbToLab(245, 245, 240);
    final black = rgbToLab(0, 0, 0);
    expect(
      labDistanceSquared(white, nearWhite),
      lessThan(labDistanceSquared(white, black)),
    );
  });
}
