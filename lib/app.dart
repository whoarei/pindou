import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/editor/editor_screen.dart';

class BeadPatternApp extends StatelessWidget {
  const BeadPatternApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '拼豆工坊',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const EditorScreen(),
    );
  }
}
