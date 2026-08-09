import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pindou_studio/features/editor/editor_state.dart';
import 'package:pindou_studio/models/bead_color.dart';
import 'package:pindou_studio/models/crop_spec.dart';
import 'package:pindou_studio/models/pattern.dart';
import 'package:pindou_studio/services/project_codec.dart';

void main() {
  const red = BeadColor(
    code: 'P01',
    name: 'Red',
    red: 220,
    green: 30,
    blue: 40,
  );
  const blue = BeadColor(
    code: 'P02',
    name: 'Blue',
    red: 25,
    green: 55,
    blue: 215,
  );
  const palette = BeadPalette(brand: 'Test', colors: [red, blue]);

  test('round-trips the complete editable project state', () {
    final original = EditorState(
      palettes: const [palette],
      selectedBrand: 'Test',
      sourceBytes: Uint8List.fromList([1, 2, 3, 4]),
      sourceName: 'sample.png',
      sourceWidth: 640,
      sourceHeight: 480,
      crop: const CropSpec(
        left: 0.1,
        top: 0.2,
        width: 0.75,
        height: 0.65,
        quarterTurns: 1,
      ),
      patternWidth: 32,
      patternHeight: 24,
      lockAspectRatio: false,
      maximumColors: 2,
      dither: true,
      showGrid: false,
      showColorCodes: true,
      editTool: EditorTool.brush,
      brushColorCode: 'P02',
      selectedCells: const {1, 2},
      pattern: const Pattern(
        width: 2,
        height: 2,
        colorIndices: [0, 1, 1, 0],
        colors: [red, blue],
        counts: [2, 2],
      ),
      isLoadingPalettes: false,
    );

    final restored = ProjectCodec.decode(
      ProjectCodec.encode(original),
      palettes: const [palette],
    );

    expect(restored.sourceBytes, original.sourceBytes);
    expect(restored.sourceName, 'sample.png');
    expect(restored.sourceWidth, 640);
    expect(restored.sourceHeight, 480);
    expect(restored.crop.left, 0.1);
    expect(restored.crop.quarterTurns, 1);
    expect(restored.patternWidth, 32);
    expect(restored.patternHeight, 24);
    expect(restored.lockAspectRatio, isFalse);
    expect(restored.dither, isTrue);
    expect(restored.showGrid, isFalse);
    expect(restored.showColorCodes, isTrue);
    expect(restored.isColorEditing, isTrue);
    expect(restored.editTool, EditorTool.brush);
    expect(restored.brushColorCode, 'P02');
    expect(restored.selectedCells, isEmpty);
    expect(restored.pattern!.colorIndices, [0, 1, 1, 0]);
    expect(restored.pattern!.counts, [2, 2]);
    expect(restored.pattern!.colors, [red, blue]);
  });

  test('rejects files that are not Pindou Studio projects', () {
    expect(
      () => ProjectCodec.decode(
        Uint8List.fromList('{"format":"other"}'.codeUnits),
        palettes: const [palette],
      ),
      throwsFormatException,
    );
  });
}
