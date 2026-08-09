import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pindou_studio/features/editor/editor_controller.dart';
import 'package:pindou_studio/services/palette_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('autosaves an edit and restores it in a new controller', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pindou-autosave-test-',
    );
    addTearDown(() => directory.delete(recursive: true));

    final source = img.Image(width: 3, height: 2)
      ..setPixelRgb(0, 0, 220, 30, 40)
      ..setPixelRgb(1, 0, 30, 210, 80)
      ..setPixelRgb(2, 0, 30, 60, 220);
    final sourceBytes = Uint8List.fromList(img.encodePng(source));

    final first = EditorController(
      const PaletteService(),
      autosaveDirectoryPath: directory.path,
    );
    await first.initialize();
    await first.loadImage(sourceBytes, 'autosave.png');
    first.setShowColorCodes(false);
    await first.flushAutosave();
    first.dispose();

    final autosave = File(
      '${directory.path}${Platform.pathSeparator}autosave.pindou',
    );
    expect(await autosave.exists(), isTrue);

    final restored = EditorController(
      const PaletteService(),
      autosaveDirectoryPath: directory.path,
    );
    await restored.initialize();
    addTearDown(restored.dispose);

    expect(restored.state.sourceName, 'autosave.png');
    expect(restored.state.sourceWidth, 3);
    expect(restored.state.sourceHeight, 2);
    expect(restored.state.sourceBytes, sourceBytes);
    expect(restored.state.showColorCodes, isFalse);
    expect(restored.state.noticeMessage, '已自动恢复上次编辑');
  });
}
