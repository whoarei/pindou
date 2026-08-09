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
}

class _PresetEditorController extends EditorController {
  _PresetEditorController(EditorState initial)
    : super(const PaletteService(), autosaveEnabled: false) {
    state = initial;
  }
}
