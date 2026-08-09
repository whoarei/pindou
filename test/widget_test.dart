import 'package:pindou_studio/app.dart';
import 'package:pindou_studio/features/editor/editor_controller.dart';
import 'package:pindou_studio/features/editor/editor_state.dart';
import 'package:pindou_studio/models/bead_color.dart';
import 'package:pindou_studio/models/pattern.dart';
import 'package:pindou_studio/services/palette_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('editor renders the import workflow', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: BeadPatternApp()));
    await tester.pumpAndSettle();

    expect(find.text('拼豆工坊'), findsOneWidget);
    expect(find.text('导入图片'), findsOneWidget);
    expect(find.text('拼豆参数'), findsOneWidget);
    expect(find.text('选择一张图片'), findsOneWidget);
    expect(find.text('生成拼豆图'), findsOneWidget);
  });

  testWidgets('uses side statistics on an 8-inch landscape tablet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const color = BeadColor(
      code: 'P18',
      name: 'Black',
      red: 32,
      green: 35,
      blue: 38,
    );
    const pattern = Pattern(
      width: 2,
      height: 2,
      colorIndices: [0, 0, 0, 0],
      colors: [color],
      counts: [4],
    );
    final controller = _PresetEditorController(
      const EditorState(
        palettes: [
          BeadPalette(brand: 'Test', colors: [color]),
        ],
        selectedBrand: 'Test',
        pattern: pattern,
        isLoadingPalettes: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [editorProvider.overrideWith((ref) => controller)],
        child: const BeadPatternApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('wide-editor-side')), findsOneWidget);
    expect(find.text('颜色用量'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _PresetEditorController extends EditorController {
  _PresetEditorController(EditorState initial) : super(const PaletteService()) {
    state = initial;
  }
}
