import 'package:pindou_studio/app.dart';
import 'package:pindou_studio/features/editor/editor_controller.dart';
import 'package:pindou_studio/features/editor/editor_state.dart';
import 'package:pindou_studio/features/editor/pattern_painter.dart';
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
    expect(find.byKey(const ValueKey('new-blank-pattern')), findsOneWidget);
    expect(find.text('生成拼豆图'), findsOneWidget);
  });

  testWidgets('creates a blank pattern without importing an image', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const white = BeadColor(
      code: 'P01',
      name: 'White',
      red: 245,
      green: 245,
      blue: 240,
    );
    const blue = BeadColor(
      code: 'P02',
      name: 'Blue',
      red: 30,
      green: 55,
      blue: 220,
    );
    final controller = _PresetEditorController(
      const EditorState(
        palettes: [
          BeadPalette(brand: 'Test', colors: [white, blue]),
        ],
        selectedBrand: 'Test',
        patternWidth: 12,
        patternHeight: 8,
        lockAspectRatio: false,
        brushColorCode: 'P02',
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
    expect(find.text('新建 12 × 8 空白图案'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('new-blank-pattern')));
    await tester.pumpAndSettle();

    final pattern = controller.state.pattern!;
    expect(controller.state.sourceBytes, isNull);
    expect(pattern.width, 12);
    expect(pattern.height, 8);
    expect(pattern.colors, [white]);
    expect(pattern.counts, [96]);
    expect(pattern.colorIndices, everyElement(0));
    expect(controller.state.editTool, EditorTool.pan);
    expect(controller.state.canUndo, isFalse);
    expect(find.byKey(const ValueKey('brush-tool')), findsOneWidget);
    expect(find.text('96 颗 · 1 色'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    expect(find.byKey(const ValueKey('control-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('statistics-panel')), findsOneWidget);
    expect(find.text('颜色用量'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final initialWorkspaceWidth = tester
        .getSize(find.byKey(const ValueKey('workspace-panel')))
        .width;

    await tester.tap(find.byKey(const ValueKey('toggle-control-panel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('control-panel')), findsNothing);
    expect(find.byKey(const ValueKey('statistics-panel')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('toggle-statistics-panel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('statistics-panel')), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('workspace-panel'))).width,
      greaterThan(initialWorkspaceWidth),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('selects cells and replaces them from the brand palette', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const red = BeadColor(
      code: 'P01',
      name: 'Red',
      red: 225,
      green: 35,
      blue: 45,
    );
    const blue = BeadColor(
      code: 'P02',
      name: 'Blue',
      red: 30,
      green: 55,
      blue: 220,
    );
    const green = BeadColor(
      code: 'P03',
      name: 'Green',
      red: 35,
      green: 205,
      blue: 85,
    );
    final paletteColors = <BeadColor>[
      red,
      blue,
      green,
      for (var index = 4; index <= 32; index++)
        BeadColor(
          code: 'P${index.toString().padLeft(2, '0')}',
          name: 'Color $index',
          red: (index * 47) % 256,
          green: (index * 83) % 256,
          blue: (index * 131) % 256,
        ),
    ];
    final controller = _PresetEditorController(
      EditorState(
        palettes: [BeadPalette(brand: 'Test', colors: paletteColors)],
        selectedBrand: 'Test',
        pattern: const Pattern(
          width: 2,
          height: 2,
          colorIndices: [0, 1, 0, 1],
          colors: [red, blue],
          counts: [2, 2],
        ),
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

    final viewerFinder = find.byType(InteractiveViewer);
    final viewer = tester.widget<InteractiveViewer>(viewerFinder);
    final viewportCenter = tester.getSize(viewerFinder).center(Offset.zero);
    final sceneCenterBefore = viewer.transformationController!.toScene(
      viewportCenter,
    );
    expect(find.text('100%'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('zoom-in-button')));
    await tester.pumpAndSettle();
    expect(find.text('125%'), findsOneWidget);
    final sceneCenterAfterZoomIn = viewer.transformationController!.toScene(
      viewportCenter,
    );
    expect(sceneCenterAfterZoomIn.dx, closeTo(sceneCenterBefore.dx, 0.001));
    expect(sceneCenterAfterZoomIn.dy, closeTo(sceneCenterBefore.dy, 0.001));
    await tester.tap(find.byKey(const ValueKey('zoom-out-button')));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('toggle-color-codes')));
    await tester.pump();
    expect(controller.state.showColorCodes, isFalse);

    await tester.tap(find.byKey(const ValueKey('toggle-color-editing')));
    await tester.pump();
    expect(controller.state.isColorEditing, isTrue);

    controller.toggleSelectedCell(0);
    controller.toggleSelectedCell(1);
    await tester.pump();
    expect(find.text('已选 2 个色块'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('replace-selected-color')));
    await tester.pumpAndSettle();
    expect(find.text('选择 Test 色号'), findsOneWidget);
    expect(find.text('特殊边框：当前选区的 2 个色号'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('current-color-marker-P01')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('current-color-marker-P02')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('current-color-marker-P03')),
      findsNothing,
    );

    final colorGrid = tester.widget<GridView>(
      find.byKey(const ValueKey('palette-color-grid')),
    );
    final gridDelegate =
        colorGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    final desktopColumns = gridDelegate.crossAxisCount;
    expect(desktopColumns, greaterThan(1));
    expect(colorGrid.physics, isA<NeverScrollableScrollPhysics>());
    expect(
      find.byKey(const ValueKey('palette-grid-dimensions')),
      findsOneWidget,
    );

    tester.view.physicalSize = const Size(500, 800);
    await tester.pumpAndSettle();
    final narrowGrid = tester.widget<GridView>(
      find.byKey(const ValueKey('palette-color-grid')),
    );
    final narrowDelegate =
        narrowGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(narrowDelegate.crossAxisCount, lessThan(desktopColumns));
    expect(find.byKey(const ValueKey('palette-color-P32')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('palette-color-P03')));
    await tester.pumpAndSettle();

    expect(controller.state.pattern!.counts, [1, 1, 2]);
    expect(controller.state.pattern!.colors, [red, blue, green]);
    expect(controller.state.pattern!.colorIndices, [2, 2, 0, 1]);
    expect(controller.state.selectedCells, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paints a continuous stroke and supports undo and redo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const red = BeadColor(
      code: 'P01',
      name: 'Red',
      red: 225,
      green: 35,
      blue: 45,
    );
    const blue = BeadColor(
      code: 'P02',
      name: 'Blue',
      red: 30,
      green: 55,
      blue: 220,
    );
    final controller = _PresetEditorController(
      const EditorState(
        palettes: [
          BeadPalette(brand: 'Test', colors: [red, blue]),
        ],
        selectedBrand: 'Test',
        brushColorCode: 'P02',
        pattern: Pattern(
          width: 4,
          height: 4,
          colorIndices: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
          colors: [red],
          counts: [16],
        ),
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
    await tester.tap(find.byKey(const ValueKey('brush-tool')));
    await tester.pump();

    final patternPaint = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is PatternPainter,
    );
    final rect = tester.getRect(patternPaint);
    final gesture = await tester.startGesture(
      Offset(rect.left + rect.width / 8, rect.top + rect.height / 8),
    );
    await gesture.moveTo(
      Offset(rect.right - rect.width / 8, rect.bottom - rect.height / 8),
    );
    await gesture.up();
    await tester.pump();

    String colorCodeAt(int cell) {
      final pattern = controller.state.pattern!;
      return pattern.colors[pattern.colorIndices[cell]].code;
    }

    expect([0, 5, 10, 15].map(colorCodeAt), everyElement('P02'));
    expect(controller.state.canUndo, isTrue);
    expect(controller.state.canRedo, isFalse);

    await tester.tap(find.byKey(const ValueKey('undo-pattern-edit')));
    await tester.pump();
    expect(List.generate(16, colorCodeAt), everyElement('P01'));
    expect(controller.state.canRedo, isTrue);

    await tester.tap(find.byKey(const ValueKey('redo-pattern-edit')));
    await tester.pump();
    expect([0, 5, 10, 15].map(colorCodeAt), everyElement('P02'));

    await tester.tap(find.byKey(const ValueKey('undo-pattern-edit')));
    await tester.pump();
    final firstPointer = await tester.startGesture(
      Offset(rect.left + rect.width / 8, rect.top + rect.height / 8),
      pointer: 7,
    );
    final secondPointer = await tester.startGesture(
      Offset(rect.right - rect.width / 8, rect.bottom - rect.height / 8),
      pointer: 8,
    );
    await firstPointer.moveTo(rect.center);
    await secondPointer.moveTo(Offset(rect.center.dx, rect.bottom));
    await firstPointer.up();
    await secondPointer.up();
    await tester.pump();
    expect(colorCodeAt(0), 'P02');
    expect(
      List.generate(16, colorCodeAt).where((code) => code == 'P02'),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });
}

class _PresetEditorController extends EditorController {
  _PresetEditorController(EditorState initial)
    : super(const PaletteService(), autosaveEnabled: false) {
    state = initial;
  }
}
