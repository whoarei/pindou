import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/bead_color.dart';
import '../../models/pattern.dart';
import 'crop_editor_dialog.dart';
import 'editor_controller.dart';
import 'editor_state.dart';
import 'pattern_painter.dart';

class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorProvider);
    final controller = ref.read(editorProvider.notifier);
    ref.listen<String?>(editorProvider.select((value) => value.errorMessage), (
      previous,
      next,
    ) {
      if (next == null || next == previous) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(next),
            action: SnackBarAction(
              label: '知道了',
              onPressed: controller.clearError,
            ),
          ),
        );
    });
    ref.listen<String?>(editorProvider.select((value) => value.noticeMessage), (
      previous,
      next,
    ) {
      if (next == null || next == previous) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded),
                const SizedBox(width: 10),
                Expanded(child: Text(next)),
              ],
            ),
          ),
        );
      controller.clearNotice();
    });

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 20,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  Icons.grid_view_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '拼豆工坊',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  'BEAD PATTERN STUDIO',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.3,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<_ProjectAction>(
            tooltip: '工程文件',
            icon: const Icon(Icons.folder_copy_outlined),
            onSelected: (action) {
              switch (action) {
                case _ProjectAction.open:
                  controller.openProject();
                case _ProjectAction.save:
                  controller.saveProject();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _ProjectAction.open,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.folder_open_rounded),
                  title: Text('打开工程'),
                  subtitle: Text('恢复 .pindou 文件'),
                ),
              ),
              PopupMenuItem(
                value: _ProjectAction.save,
                enabled: state.sourceBytes != null || state.pattern != null,
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.save_outlined),
                  title: Text('保存工程'),
                  subtitle: Text('保存当前编辑状态'),
                ),
              ),
            ],
          ),
          if (state.pattern != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.tonalIcon(
                onPressed: state.isExporting
                    ? null
                    : () => _export(context, controller),
                icon: state.isExporting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(
                  MediaQuery.sizeOf(context).width < 620 ? '导出' : '导出 JPG',
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 920) {
              final statisticsPlacement = constraints.maxHeight >= 720
                  ? _WideStatisticsPlacement.bottom
                  : constraints.maxWidth >= 1050
                  ? _WideStatisticsPlacement.side
                  : _WideStatisticsPlacement.compactBottom;
              return _DesktopEditor(
                state: state,
                controller: controller,
                statisticsPlacement: statisticsPlacement,
              );
            }
            return _MobileEditor(state: state, controller: controller);
          },
        ),
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    EditorController controller,
  ) async {
    final path = await controller.exportJpeg();
    if (!context.mounted || path == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded),
            const SizedBox(width: 10),
            Expanded(child: Text('已导出到 $path')),
          ],
        ),
      ),
    );
  }
}

class _DesktopEditor extends StatefulWidget {
  const _DesktopEditor({
    required this.state,
    required this.controller,
    required this.statisticsPlacement,
  });

  final EditorState state;
  final EditorController controller;
  final _WideStatisticsPlacement statisticsPlacement;

  @override
  State<_DesktopEditor> createState() => _DesktopEditorState();
}

class _DesktopEditorState extends State<_DesktopEditor> {
  bool _showControls = true;
  bool _showStatistics = true;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final controller = widget.controller;
    final statisticsPlacement = widget.statisticsPlacement;
    final usesCompactControls =
        statisticsPlacement != _WideStatisticsPlacement.bottom;
    final usesSideStatistics =
        statisticsPlacement == _WideStatisticsPlacement.side;
    final showControls = !usesSideStatistics || _showControls;
    final showStatistics =
        state.pattern != null && usesSideStatistics && _showStatistics;
    final panelControls = usesSideStatistics
        ? _PanelVisibilityControls(
            showControls: _showControls,
            showStatistics: _showStatistics,
            canToggleStatistics: state.pattern != null,
            onToggleControls: () {
              setState(() => _showControls = !_showControls);
            },
            onToggleStatistics: () {
              setState(() => _showStatistics = !_showStatistics);
            },
          )
        : null;

    return Row(
      key: ValueKey('wide-editor-${statisticsPlacement.name}'),
      children: [
        if (showControls)
          SizedBox(
            key: const ValueKey('control-panel'),
            width: usesCompactControls ? 350 : 374,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 24),
              child: Column(
                children: [
                  _SourceCard(state: state, controller: controller),
                  const SizedBox(height: 14),
                  _ParametersCard(state: state, controller: controller),
                ],
              ),
            ),
          ),
        if (showControls)
          VerticalDivider(
            width: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: showStatistics
                ? Row(
                    children: [
                      Expanded(
                        child: _WorkspaceCard(
                          key: const ValueKey('workspace-panel'),
                          state: state,
                          controller: controller,
                          panelControls: panelControls,
                        ),
                      ),
                      const SizedBox(width: 14),
                      SizedBox(
                        key: const ValueKey('statistics-panel'),
                        width: 300,
                        child: _StatisticsCard(
                          pattern: state.pattern!,
                          layout: _StatisticsLayout.vertical,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(
                        child: _WorkspaceCard(
                          key: const ValueKey('workspace-panel'),
                          state: state,
                          controller: controller,
                          panelControls: panelControls,
                        ),
                      ),
                      if (state.pattern != null && !usesSideStatistics) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          height:
                              statisticsPlacement ==
                                  _WideStatisticsPlacement.compactBottom
                              ? 156
                              : 220,
                          child: _StatisticsCard(
                            pattern: state.pattern!,
                            layout: _StatisticsLayout.horizontal,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _MobileEditor extends StatelessWidget {
  const _MobileEditor({required this.state, required this.controller});

  final EditorState state;
  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
          sliver: SliverList.list(
            children: [
              _SourceCard(state: state, controller: controller),
              const SizedBox(height: 12),
              _ParametersCard(state: state, controller: controller),
              const SizedBox(height: 12),
              SizedBox(
                height: 470,
                child: _WorkspaceCard(state: state, controller: controller),
              ),
              if (state.pattern != null) ...[
                const SizedBox(height: 12),
                _StatisticsCard(
                  pattern: state.pattern!,
                  layout: _StatisticsLayout.wrap,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.state, required this.controller});

  final EditorState state;
  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final bytes = state.sourceBytes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              index: '01',
              title: '导入图片',
              icon: Icons.add_photo_alternate_outlined,
            ),
            const SizedBox(height: 14),
            if (bytes == null)
              InkWell(
                onTap: controller.pickImage,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.34),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 38,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '选择一张图片',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '支持 JPG、PNG',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: SizedBox(
                      width: 82,
                      height: 82,
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.sourceName ?? '已选择图片',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${state.sourceWidth} × ${state.sourceHeight} px',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            _SmallAction(
                              icon: Icons.crop_rounded,
                              label: '裁剪 / 旋转',
                              onPressed: () => _editCrop(context),
                            ),
                            _SmallAction(
                              icon: Icons.swap_horiz_rounded,
                              label: '更换',
                              onPressed: controller.pickImage,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCrop(BuildContext context) async {
    final crop = await showCropEditor(
      context: context,
      bytes: state.sourceBytes!,
      imageWidth: state.sourceWidth!,
      imageHeight: state.sourceHeight!,
      initialCrop: state.crop,
    );
    if (crop != null) controller.applyCrop(crop);
  }
}

class _ParametersCard extends StatelessWidget {
  const _ParametersCard({required this.state, required this.controller});

  final EditorState state;
  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final palette = state.selectedPalette;
    final paletteSize = palette?.colors.length ?? 32;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              index: '02',
              title: '拼豆参数',
              icon: Icons.tune_rounded,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: _FieldLabel(label: '宽度', hint: '拼豆数量'),
                ),
                _ValueBadge(value: '${state.patternWidth} 颗'),
              ],
            ),
            Slider(
              value: state.patternWidth.toDouble().clamp(8, 200),
              min: 8,
              max: 200,
              divisions: 192,
              label: '${state.patternWidth}',
              onChanged: (value) => controller.setPatternWidth(value.round()),
            ),
            Row(
              children: [
                const Expanded(
                  child: _FieldLabel(label: '高度', hint: '拼豆数量'),
                ),
                _ValueBadge(value: '${state.patternHeight} 颗'),
              ],
            ),
            Slider(
              value: state.patternHeight.toDouble().clamp(8, 200),
              min: 8,
              max: 200,
              divisions: 192,
              label: '${state.patternHeight}',
              onChanged: (value) => controller.setPatternHeight(value.round()),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () =>
                  controller.setAspectRatioLocked(!state.lockAspectRatio),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      state.lockAspectRatio
                          ? Icons.link_rounded
                          : Icons.link_off_rounded,
                      size: 19,
                      color: state.lockAspectRatio
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '保持裁剪比例',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    Switch.adaptive(
                      value: state.lockAspectRatio,
                      onChanged: controller.setAspectRatioLocked,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const _FieldLabel(label: '品牌色库', hint: '选择实际使用的拼豆品牌'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue:
                  state.palettes.any(
                    (item) => item.brand == state.selectedBrand,
                  )
                  ? state.selectedBrand
                  : null,
              hint: Text(state.isLoadingPalettes ? '正在加载色库…' : '选择色库'),
              items: [
                for (final item in state.palettes)
                  DropdownMenuItem(
                    value: item.brand,
                    child: Row(
                      children: [
                        const Icon(Icons.palette_outlined, size: 18),
                        const SizedBox(width: 9),
                        Text('${item.brand} · ${item.colors.length} 色'),
                      ],
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) controller.setBrand(value);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: _FieldLabel(label: '最大颜色数', hint: '减少备料种类'),
                ),
                _ValueBadge(value: '${state.maximumColors} 色'),
              ],
            ),
            Slider(
              value: state.maximumColors.toDouble().clamp(
                2.0,
                math.max(2, paletteSize).toDouble(),
              ),
              min: 2,
              max: math.max(2, paletteSize).toDouble(),
              divisions: math.max(1, paletteSize - 2),
              label: '${state.maximumColors}',
              onChanged: palette == null
                  ? null
                  : (value) => controller.setMaximumColors(value.round()),
            ),
            _ToggleRow(
              icon: Icons.grain_rounded,
              title: '误差扩散抖动',
              subtitle: '增强渐变层次，可能产生颗粒感',
              value: state.dither,
              onChanged: controller.setDither,
            ),
            const SizedBox(height: 4),
            _ToggleRow(
              icon: Icons.grid_on_rounded,
              title: '显示网格',
              subtitle: '预览与导出的 JPG 包含分格线',
              value: state.showGrid,
              onChanged: controller.setShowGrid,
            ),
            const SizedBox(height: 4),
            _ToggleRow(
              icon: Icons.numbers_rounded,
              title: '显示色号',
              subtitle: '预览与导出的 JPG 包含每颗拼豆色号',
              value: state.showColorCodes,
              onChanged: controller.setShowColorCodes,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: state.canGenerate ? controller.generate : null,
                icon: state.isProcessing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(state.isProcessing ? '正在转换…' : '生成拼豆图'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    required this.state,
    required this.controller,
    this.panelControls,
    super.key,
  });

  final EditorState state;
  final EditorController controller;
  final Widget? panelControls;

  @override
  Widget build(BuildContext context) {
    final pattern = state.pattern;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                return Row(
                  children: [
                    const _SectionTitle(
                      index: '03',
                      title: '图案预览',
                      icon: Icons.grid_4x4_rounded,
                    ),
                    const Spacer(),
                    if (panelControls != null) ...[
                      panelControls!,
                      const SizedBox(width: 5),
                    ],
                    if (pattern != null) ...[
                      IconButton(
                        key: const ValueKey('toggle-color-codes'),
                        tooltip: state.showColorCodes ? '隐藏色号图层' : '显示色号图层',
                        isSelected: state.showColorCodes,
                        onPressed: () =>
                            controller.setShowColorCodes(!state.showColorCodes),
                        icon: const Icon(Icons.numbers_outlined),
                        selectedIcon: const Icon(Icons.numbers_rounded),
                      ),
                      IconButton(
                        key: const ValueKey('toggle-color-editing'),
                        tooltip: state.isColorEditing ? '结束色号编辑' : '编辑色号',
                        isSelected: state.isColorEditing,
                        onPressed: () =>
                            controller.setColorEditing(!state.isColorEditing),
                        icon: const Icon(Icons.colorize_outlined),
                        selectedIcon: const Icon(Icons.colorize_rounded),
                      ),
                      if (!compact) ...[
                        const SizedBox(width: 5),
                        _StatusPill(
                          icon: Icons.apps_rounded,
                          label: '${pattern.width} × ${pattern.height}',
                        ),
                        if (panelControls == null) ...[
                          const SizedBox(width: 7),
                          _StatusPill(
                            icon: Icons.circle,
                            label: '${pattern.colors.length} 色',
                          ),
                        ],
                      ],
                    ],
                  ],
                );
              },
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Expanded(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              // Keep semantics nodes in a single tree. AnimatedSwitcher
              // reparents the outgoing and incoming subtrees; with Windows
              // UI Automation active this can crash Flutter 3.44's native
              // AccessibilityBridge during an image-load rebuild.
              child: _body(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (state.isProcessing) {
      return const _ProcessingView(key: ValueKey('processing'));
    }
    if (state.pattern != null) {
      return _PatternView(
        key: const ValueKey('pattern'),
        state: state,
        controller: controller,
      );
    }
    if (state.sourceBytes != null) {
      return _ReadyView(
        key: const ValueKey('ready'),
        state: state,
        onGenerate: state.canGenerate ? controller.generate : null,
      );
    }
    return const _EmptyView(key: ValueKey('empty'));
  }
}

class _PatternView extends StatefulWidget {
  const _PatternView({
    required this.state,
    required this.controller,
    super.key,
  });

  final EditorState state;
  final EditorController controller;

  @override
  State<_PatternView> createState() => _PatternViewState();
}

class _PatternViewState extends State<_PatternView>
    with SingleTickerProviderStateMixin {
  static const _minimumScale = 0.75;
  static const _maximumScale = 12.0;
  static const _zoomStep = 1.25;

  late final TransformationController _transformationController;
  late final AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;
  double _viewScale = 1;
  Size _viewportSize = Size.zero;
  Rect _patternRect = Rect.zero;
  final Set<int> _activePointers = <int>{};
  final Set<int> _brushStroke = <int>{};
  int? _brushPointer;
  int? _lastBrushCell;
  bool _suppressBrushUntilPointersUp = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController()
      ..addListener(_handleTransformation);
    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(_handleZoomAnimation);
  }

  void _handleTransformation() {
    final nextScale = _transformationController.value.getMaxScaleOnAxis();
    if ((nextScale - _viewScale).abs() < 0.02 || !mounted) return;
    setState(() => _viewScale = nextScale);
  }

  void _handleZoomAnimation() {
    final animation = _zoomAnimation;
    if (animation == null) return;
    _transformationController.value = animation.value;
  }

  void _stopZoomAnimation() {
    if (!_zoomAnimationController.isAnimating) return;
    _zoomAnimationController.stop();
    _zoomAnimation = null;
  }

  void _zoomBy(double factor) {
    if (_viewportSize.isEmpty) return;
    _stopZoomAnimation();
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor)
        .clamp(_minimumScale, _maximumScale)
        .toDouble();
    if ((targetScale - currentScale).abs() < 0.0001) return;

    final viewportCenter = _viewportSize.center(Offset.zero);
    final sceneCenter = _transformationController.toScene(viewportCenter);
    final targetMatrix = Matrix4.identity()
      ..translateByDouble(
        viewportCenter.dx - sceneCenter.dx * targetScale,
        viewportCenter.dy - sceneCenter.dy * targetScale,
        0,
        1,
      )
      ..scaleByDouble(targetScale, targetScale, targetScale, 1);
    _zoomAnimation =
        Matrix4Tween(
          begin: _transformationController.value.clone(),
          end: targetMatrix,
        ).animate(
          CurvedAnimation(
            parent: _zoomAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _zoomAnimationController.forward(from: 0);
  }

  @override
  void dispose() {
    _transformationController
      ..removeListener(_handleTransformation)
      ..dispose();
    _zoomAnimationController
      ..removeListener(_handleZoomAnimation)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PatternView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.editTool == EditorTool.brush &&
        widget.state.editTool != EditorTool.brush) {
      _brushStroke.clear();
      _brushPointer = null;
      _lastBrushCell = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final pattern = state.pattern!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _EditorToolbar(
              tool: state.editTool,
              selectedCount: state.selectedCells.length,
              brushColor: state.selectedBrushColor,
              canUndo: state.canUndo,
              canRedo: state.canRedo,
              onToolChanged: _setEditorTool,
              onSelectMatching: widget.controller.selectMatchingColor,
              onClear: widget.controller.clearSelectedCells,
              onReplace: _showSelectionColorPicker,
              onSelectBrushColor: _showBrushColorPicker,
              onUndo: widget.controller.undoPatternEdit,
              onRedo: widget.controller.redoPatternEdit,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _viewportSize = constraints.biggest;
                      final aspect = pattern.width / pattern.height;
                      var width = constraints.maxWidth;
                      var height = width / aspect;
                      if (height > constraints.maxHeight) {
                        height = constraints.maxHeight;
                        width = height * aspect;
                      }
                      _patternRect = Rect.fromLTWH(
                        (constraints.maxWidth - width) / 2,
                        (constraints.maxHeight - height) / 2,
                        width,
                        height,
                      );
                      return Listener(
                        key: const ValueKey('pattern-interaction-surface'),
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: _handlePointerDown,
                        onPointerMove: _handlePointerMove,
                        onPointerUp: _handlePointerUp,
                        onPointerCancel: _handlePointerCancel,
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          minScale: _minimumScale,
                          maxScale: _maximumScale,
                          boundaryMargin: const EdgeInsets.all(80),
                          panEnabled:
                              state.editTool != EditorTool.brush ||
                              _activePointers.length >= 2,
                          scaleEnabled: true,
                          onInteractionStart: (_) => _stopZoomAnimation(),
                          child: Center(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 18,
                                    offset: const Offset(0, 7),
                                  ),
                                ],
                              ),
                              child: SizedBox(
                                width: width,
                                height: height,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapUp: state.editTool == EditorTool.select
                                      ? (details) => _toggleCell(
                                          details.localPosition,
                                          Size(width, height),
                                          pattern,
                                        )
                                      : null,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CustomPaint(
                                        painter: PatternPainter(
                                          pattern: pattern,
                                          showGrid: state.showGrid,
                                          showColorCodes: state.showColorCodes,
                                          selectedCells: state.selectedCells,
                                          viewScale: _viewScale,
                                          selectionColor: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                      IgnorePointer(
                                        child: CustomPaint(
                                          painter: BrushStrokePainter(
                                            pattern: pattern,
                                            cells: Set<int>.unmodifiable(
                                              _brushStroke,
                                            ),
                                            color:
                                                state
                                                    .selectedBrushColor
                                                    ?.color ??
                                                Colors.transparent,
                                            viewScale: _viewScale,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: _buildZoomControls(context),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pinch_rounded, size: 15),
                        SizedBox(width: 5),
                        Text('缩放查看', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildZoomControls(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canZoomIn = _viewScale < _maximumScale - 0.001;
    final canZoomOut = _viewScale > _minimumScale + 0.001;
    return Material(
      color: colorScheme.surface.withValues(alpha: 0.94),
      elevation: 5,
      shadowColor: Colors.black.withValues(alpha: 0.26),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const ValueKey('zoom-in-button'),
            tooltip: '放大图案',
            onPressed: canZoomIn ? () => _zoomBy(_zoomStep) : null,
            icon: const Icon(Icons.add_rounded),
          ),
          Container(
            key: const ValueKey('zoom-level-label'),
            constraints: const BoxConstraints(minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
            alignment: Alignment.center,
            child: Text(
              '${(_viewScale * 100).round()}%',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('zoom-out-button'),
            tooltip: '缩小图案',
            onPressed: canZoomOut ? () => _zoomBy(1 / _zoomStep) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
        ],
      ),
    );
  }

  void _toggleCell(Offset position, Size size, Pattern pattern) {
    final x = (position.dx / size.width * pattern.width).floor();
    final y = (position.dy / size.height * pattern.height).floor();
    if (x < 0 || x >= pattern.width || y < 0 || y >= pattern.height) return;
    widget.controller.toggleSelectedCell(y * pattern.width + x);
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    if (widget.state.editTool == EditorTool.brush) {
      _stopZoomAnimation();
      if (_activePointers.length == 1 && !_suppressBrushUntilPointersUp) {
        _brushPointer = event.pointer;
        _addBrushPosition(event.localPosition);
      } else if (_activePointers.length >= 2) {
        _commitBrushStroke();
        _brushPointer = null;
        _lastBrushCell = null;
        _suppressBrushUntilPointersUp = true;
      }
    }
    if (mounted) setState(() {});
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (widget.state.editTool != EditorTool.brush ||
        event.pointer != _brushPointer ||
        _activePointers.length != 1 ||
        _suppressBrushUntilPointersUp) {
      return;
    }
    _addBrushPosition(event.localPosition);
  }

  void _handlePointerUp(PointerUpEvent event) => _finishPointer(event.pointer);

  void _handlePointerCancel(PointerCancelEvent event) =>
      _finishPointer(event.pointer);

  void _finishPointer(int pointer) {
    if (pointer == _brushPointer) _commitBrushStroke();
    _activePointers.remove(pointer);
    if (_activePointers.isEmpty) _suppressBrushUntilPointersUp = false;
    if (pointer == _brushPointer) {
      _brushPointer = null;
      _lastBrushCell = null;
    }
    if (mounted) setState(() {});
  }

  void _addBrushPosition(Offset viewportPosition) {
    final scenePosition = _transformationController.toScene(viewportPosition);
    final cell = _cellAtScenePosition(scenePosition);
    if (cell == null) {
      _lastBrushCell = null;
      return;
    }
    final previous = _lastBrushCell;
    if (previous == null) {
      _brushStroke.add(cell);
    } else if (previous != cell) {
      _brushStroke.addAll(_cellsOnLine(previous, cell, widget.state.pattern!));
    }
    _lastBrushCell = cell;
    if (mounted) setState(() {});
  }

  int? _cellAtScenePosition(Offset position) {
    final pattern = widget.state.pattern!;
    if (!_patternRect.contains(position)) return null;
    final x =
        ((position.dx - _patternRect.left) / _patternRect.width * pattern.width)
            .floor();
    final y =
        ((position.dy - _patternRect.top) /
                _patternRect.height *
                pattern.height)
            .floor();
    if (x < 0 || x >= pattern.width || y < 0 || y >= pattern.height) {
      return null;
    }
    return y * pattern.width + x;
  }

  Iterable<int> _cellsOnLine(int from, int to, Pattern pattern) sync* {
    var x0 = from % pattern.width;
    var y0 = from ~/ pattern.width;
    final x1 = to % pattern.width;
    final y1 = to ~/ pattern.width;
    final dx = (x1 - x0).abs();
    final sx = x0 < x1 ? 1 : -1;
    final dy = -(y1 - y0).abs();
    final sy = y0 < y1 ? 1 : -1;
    var error = dx + dy;
    while (true) {
      yield y0 * pattern.width + x0;
      if (x0 == x1 && y0 == y1) break;
      final twiceError = 2 * error;
      if (twiceError >= dy) {
        error += dy;
        x0 += sx;
      }
      if (twiceError <= dx) {
        error += dx;
        y0 += sy;
      }
    }
  }

  void _commitBrushStroke() {
    if (_brushStroke.isEmpty) return;
    final cells = Set<int>.of(_brushStroke);
    _brushStroke.clear();
    widget.controller.paintCells(cells);
  }

  void _setEditorTool(EditorTool tool) {
    if (widget.state.editTool == EditorTool.brush && tool != EditorTool.brush) {
      _commitBrushStroke();
    }
    widget.controller.setEditorTool(tool);
  }

  Future<void> _showSelectionColorPicker() async {
    if (widget.state.selectedCells.isEmpty) return;
    final palette = widget.state.selectedPalette;
    final pattern = widget.state.pattern;
    if (palette == null || pattern == null) return;
    final currentColorCodes = <String>{
      for (final cell in widget.state.selectedCells)
        pattern.colors[pattern.colorIndices[cell]].code,
    };
    final selected = await showDialog<BeadColor>(
      context: context,
      builder: (context) => _ColorPickerDialog(
        palette: palette,
        currentColorCodes: currentColorCodes,
        helperText: '对比全部颜色，点击目标色号后立即替换',
        currentDescription: '当前选区的 ${currentColorCodes.length} 个色号',
        currentMarkerLabel: '当前选区颜色',
      ),
    );
    if (selected != null) widget.controller.replaceSelectedColor(selected);
  }

  Future<void> _showBrushColorPicker() async {
    final palette = widget.state.selectedPalette;
    final brushColor = widget.state.selectedBrushColor;
    if (palette == null || brushColor == null) return;
    final selected = await showDialog<BeadColor>(
      context: context,
      builder: (context) => _ColorPickerDialog(
        palette: palette,
        currentColorCodes: {brushColor.code},
        helperText: '对比全部颜色，点击一个色号作为画笔颜色',
        currentDescription: '当前画笔色号 ${brushColor.code}',
        currentMarkerLabel: '当前画笔颜色',
      ),
    );
    if (selected != null) widget.controller.setBrushColor(selected);
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.tool,
    required this.selectedCount,
    required this.brushColor,
    required this.canUndo,
    required this.canRedo,
    required this.onToolChanged,
    required this.onSelectMatching,
    required this.onClear,
    required this.onReplace,
    required this.onSelectBrushColor,
    required this.onUndo,
    required this.onRedo,
  });

  final EditorTool tool;
  final int selectedCount;
  final BeadColor? brushColor;
  final bool canUndo;
  final bool canRedo;
  final ValueChanged<EditorTool> onToolChanged;
  final VoidCallback onSelectMatching;
  final VoidCallback onClear;
  final VoidCallback onReplace;
  final VoidCallback onSelectBrushColor;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.24),
      borderRadius: BorderRadius.circular(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                key: const ValueKey('pan-tool'),
                tooltip: '手掌：拖动和缩放图案',
                isSelected: tool == EditorTool.pan,
                onPressed: () => onToolChanged(EditorTool.pan),
                icon: const Icon(Icons.pan_tool_outlined),
                selectedIcon: const Icon(Icons.pan_tool_rounded),
              ),
              IconButton(
                key: const ValueKey('selection-tool'),
                tooltip: '选择：点击一个或多个色块',
                isSelected: tool == EditorTool.select,
                onPressed: () => onToolChanged(EditorTool.select),
                icon: const Icon(Icons.select_all_outlined),
                selectedIcon: const Icon(Icons.select_all_rounded),
              ),
              IconButton(
                key: const ValueKey('brush-tool'),
                tooltip: '画笔：点击或滑动修改色块',
                isSelected: tool == EditorTool.brush,
                onPressed: () => onToolChanged(EditorTool.brush),
                icon: const Icon(Icons.brush_outlined),
                selectedIcon: const Icon(Icons.brush_rounded),
              ),
              const SizedBox(width: 2),
              if (tool == EditorTool.select) ...[
                Text(
                  selectedCount == 0 ? '点击色块进行多选' : '已选 $selectedCount 个色块',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (selectedCount > 0) ...[
                  TextButton.icon(
                    key: const ValueKey('select-matching-color'),
                    onPressed: onSelectMatching,
                    icon: const Icon(Icons.select_all_rounded, size: 18),
                    label: const Text('选择同色'),
                  ),
                  FilledButton.tonalIcon(
                    key: const ValueKey('replace-selected-color'),
                    onPressed: onReplace,
                    icon: const Icon(Icons.palette_outlined, size: 18),
                    label: const Text('更改色号'),
                  ),
                  IconButton(
                    tooltip: '清除选择',
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ] else if (tool == EditorTool.brush && brushColor != null) ...[
                TextButton.icon(
                  key: const ValueKey('select-brush-color'),
                  onPressed: onSelectBrushColor,
                  icon: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: brushColor!.color,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                  label: Text('画笔 ${brushColor!.code}'),
                ),
                const Text('单指绘制 · 双指缩放'),
              ],
              const SizedBox(width: 2),
              IconButton(
                key: const ValueKey('undo-pattern-edit'),
                tooltip: '撤销',
                onPressed: canUndo ? onUndo : null,
                icon: const Icon(Icons.undo_rounded),
              ),
              IconButton(
                key: const ValueKey('redo-pattern-edit'),
                tooltip: '重做',
                onPressed: canRedo ? onRedo : null,
                icon: const Icon(Icons.redo_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorPickerDialog extends StatelessWidget {
  const _ColorPickerDialog({
    required this.palette,
    required this.currentColorCodes,
    required this.helperText,
    required this.currentDescription,
    required this.currentMarkerLabel,
  });

  final BeadPalette palette;
  final Set<String> currentColorCodes;
  final String helperText;
  final String currentDescription;
  final String currentMarkerLabel;

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('选择 ${palette.brand} 色号'),
          const SizedBox(height: 4),
          Text(
            helperText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      content: SizedBox(
        width: math.min(760, mediaSize.width - 48),
        height: math.min(600, mediaSize.height * 0.68),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const informationHeight = 36.0;
            const gridGap = 7.0;
            final geometry = _calculateColorGridGeometry(
              size: Size(
                constraints.maxWidth,
                math.max(1, constraints.maxHeight - informationHeight),
              ),
              itemCount: palette.colors.length,
              gap: gridGap,
            );
            return Column(
              children: [
                SizedBox(
                  height: informationHeight,
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          '特殊边框：$currentDescription',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${geometry.rows} 行 × ${geometry.columns} 列',
                        key: const ValueKey('palette-grid-dimensions'),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: geometry.width,
                      height: geometry.height,
                      child: GridView.builder(
                        key: const ValueKey('palette-color-grid'),
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: palette.colors.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: geometry.columns,
                          crossAxisSpacing: gridGap,
                          mainAxisSpacing: gridGap,
                        ),
                        itemBuilder: (context, index) {
                          final color = palette.colors[index];
                          return _PaletteColorCell(
                            color: color,
                            isCurrent: currentColorCodes.contains(color.code),
                            currentMarkerLabel: currentMarkerLabel,
                            onTap: () => Navigator.of(context).pop(color),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

class _PaletteColorCell extends StatelessWidget {
  const _PaletteColorCell({
    required this.color,
    required this.isCurrent,
    required this.currentMarkerLabel,
    required this.onTap,
  });

  final BeadColor color;
  final bool isCurrent;
  final String currentMarkerLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = color.color.computeLuminance() > 0.43
        ? const Color(0xff17191b)
        : Colors.white;
    return Semantics(
      button: true,
      selected: isCurrent,
      label:
          '${color.code} ${color.name}${isCurrent ? '，$currentMarkerLabel' : ''}',
      child: Tooltip(
        message:
            '${color.code} · ${color.name}${isCurrent ? '（$currentMarkerLabel）' : ''}',
        child: AnimatedContainer(
          key: ValueKey('palette-color-${color.code}'),
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.all(isCurrent ? 4 : 1),
          decoration: BoxDecoration(
            color: isCurrent ? colorScheme.primary : colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.42),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: color.color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isCurrent
                    ? Colors.white.withValues(alpha: 0.92)
                    : Colors.black.withValues(alpha: 0.18),
                width: isCurrent ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          color.code,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(
                                color: foreground == Colors.white
                                    ? Colors.black.withValues(alpha: 0.45)
                                    : Colors.white.withValues(alpha: 0.42),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isCurrent)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        key: ValueKey('current-color-marker-${color.code}'),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: colorScheme.onPrimary),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorGridGeometry {
  const _ColorGridGeometry({
    required this.rows,
    required this.columns,
    required this.cellExtent,
    required this.gap,
  });

  final int rows;
  final int columns;
  final double cellExtent;
  final double gap;

  double get width => columns * cellExtent + (columns - 1) * gap;
  double get height => rows * cellExtent + (rows - 1) * gap;
}

_ColorGridGeometry _calculateColorGridGeometry({
  required Size size,
  required int itemCount,
  required double gap,
}) {
  assert(itemCount > 0);
  var bestColumns = 1;
  var bestRows = itemCount;
  var bestExtent = 0.0;
  var bestRatioDifference = double.infinity;
  final availableRatio = size.width / math.max(1, size.height);

  for (var columns = 1; columns <= itemCount; columns++) {
    final rows = (itemCount + columns - 1) ~/ columns;
    final widthWithoutGaps = size.width - (columns - 1) * gap;
    final heightWithoutGaps = size.height - (rows - 1) * gap;
    if (widthWithoutGaps <= 0 || heightWithoutGaps <= 0) continue;
    final extent = math.min(
      112.0,
      math.min(widthWithoutGaps / columns, heightWithoutGaps / rows),
    );
    final gridRatio = columns / rows;
    final ratioDifference = (gridRatio - availableRatio).abs();
    final isLarger = extent > bestExtent + 0.01;
    final isBetterTie =
        (extent - bestExtent).abs() <= 0.01 &&
        ratioDifference < bestRatioDifference;
    if (isLarger || isBetterTie) {
      bestColumns = columns;
      bestRows = rows;
      bestExtent = extent;
      bestRatioDifference = ratioDifference;
    }
  }

  return _ColorGridGeometry(
    rows: bestRows,
    columns: bestColumns,
    cellExtent: bestExtent,
    gap: gap,
  );
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.state, required this.onGenerate, super.key});

  final EditorState state;
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                state.sourceBytes!,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '图片已就绪',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            '设置左侧参数，然后生成 ${state.patternWidth} × ${state.patternHeight} 拼豆图',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onGenerate,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('开始生成'),
          ),
        ],
      ),
    );
  }
}

class _ProcessingView extends StatelessWidget {
  const _ProcessingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 58,
            child: CircularProgressIndicator(
              strokeWidth: 5,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '正在匹配品牌色库',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            '图像处理在后台进行，请稍候',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.image_search_rounded,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '这里会显示你的拼豆图',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              '先导入一张 JPG 或 PNG 图片，再选择尺寸和品牌色库。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _WideStatisticsPlacement { bottom, compactBottom, side }

enum _ProjectAction { open, save }

enum _StatisticsLayout { horizontal, vertical, wrap }

class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({required this.pattern, required this.layout});

  final Pattern pattern;
  final _StatisticsLayout layout;

  @override
  Widget build(BuildContext context) {
    final usages = pattern.usages;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: layout == _StatisticsLayout.wrap
              ? MainAxisSize.min
              : MainAxisSize.max,
          children: [
            Row(
              children: [
                const _SectionTitle(
                  index: '04',
                  title: '颜色用量',
                  icon: Icons.format_list_numbered_rounded,
                ),
                const Spacer(),
                Text(
                  '${pattern.totalBeads} 颗 · ${usages.length} 色',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (layout == _StatisticsLayout.horizontal)
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: usages.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 9),
                  itemBuilder: (context, index) => SizedBox(
                    width: 175,
                    child: _ColorTile(usage: usages[index]),
                  ),
                ),
              )
            else if (layout == _StatisticsLayout.vertical)
              Expanded(
                child: ListView.separated(
                  itemCount: usages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (context, index) => SizedBox(
                    height: 66,
                    child: _ColorTile(usage: usages[index]),
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final tileWidth = constraints.maxWidth >= 520
                      ? (constraints.maxWidth - 18) / 3
                      : (constraints.maxWidth - 9) / 2;
                  return Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      for (final usage in usages)
                        SizedBox(
                          width: tileWidth,
                          child: _ColorTile(usage: usage),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ColorTile extends StatelessWidget {
  const _ColorTile({required this.usage});

  final ColorUsage usage;

  @override
  Widget build(BuildContext context) {
    final color = usage.color;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black.withValues(alpha: 0.18)),
                boxShadow: [
                  BoxShadow(
                    color: color.color.withValues(alpha: 0.28),
                    blurRadius: 7,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    color.code,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    color.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${usage.count}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.index,
    required this.title,
    required this.icon,
  });

  final String index;
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          index,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          icon,
          size: 19,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 7),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.hint});

  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(
          hint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ValueBadge extends StatelessWidget {
  const _ValueBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 19,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _PanelVisibilityControls extends StatelessWidget {
  const _PanelVisibilityControls({
    required this.showControls,
    required this.showStatistics,
    required this.canToggleStatistics,
    required this.onToggleControls,
    required this.onToggleStatistics,
  });

  final bool showControls;
  final bool showStatistics;
  final bool canToggleStatistics;
  final VoidCallback onToggleControls;
  final VoidCallback onToggleStatistics;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PanelVisibilityButton(
          key: const ValueKey('toggle-control-panel'),
          icon: Icons.tune_rounded,
          isVisible: showControls,
          tooltip: showControls ? '隐藏参数栏' : '显示参数栏',
          onPressed: onToggleControls,
        ),
        if (canToggleStatistics) ...[
          const SizedBox(width: 4),
          _PanelVisibilityButton(
            key: const ValueKey('toggle-statistics-panel'),
            icon: Icons.format_list_numbered_rounded,
            isVisible: showStatistics,
            tooltip: showStatistics ? '隐藏颜色用量栏' : '显示颜色用量栏',
            onPressed: onToggleStatistics,
          ),
        ],
      ],
    );
  }
}

class _PanelVisibilityButton extends StatelessWidget {
  const _PanelVisibilityButton({
    required this.icon,
    required this.isVisible,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final bool isVisible;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: isVisible
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        foregroundColor: isVisible
            ? scheme.onPrimaryContainer
            : scheme.onSurfaceVariant,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      icon: Icon(icon, size: 18),
    );
  }
}
