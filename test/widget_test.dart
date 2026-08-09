import 'package:pindou_studio/app.dart';
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
}
