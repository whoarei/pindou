import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/crop_spec.dart';

Future<CropSpec?> showCropEditor({
  required BuildContext context,
  required Uint8List bytes,
  required int imageWidth,
  required int imageHeight,
  required CropSpec initialCrop,
}) {
  return showDialog<CropSpec>(
    context: context,
    barrierDismissible: false,
    builder: (context) => CropEditorDialog(
      bytes: bytes,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      initialCrop: initialCrop,
    ),
  );
}

class CropEditorDialog extends StatefulWidget {
  const CropEditorDialog({
    required this.bytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.initialCrop,
    super.key,
  });

  final Uint8List bytes;
  final int imageWidth;
  final int imageHeight;
  final CropSpec initialCrop;

  @override
  State<CropEditorDialog> createState() => _CropEditorDialogState();
}

class _CropEditorDialogState extends State<CropEditorDialog> {
  late CropSpec _crop = widget.initialCrop;
  _CropRatio _ratio = _CropRatio.free;

  double get _sourceAspect {
    final rotated = _crop.quarterTurns.isOdd;
    return rotated
        ? widget.imageHeight / widget.imageWidth
        : widget.imageWidth / widget.imageHeight;
  }

  double? get _targetAspect => switch (_ratio) {
    _CropRatio.free => null,
    _CropRatio.original => _sourceAspect,
    _CropRatio.square => 1,
    _CropRatio.landscape => 4 / 3,
    _CropRatio.portrait => 3 / 4,
  };

  void _rotate(int delta) {
    setState(() {
      _crop = CropSpec(quarterTurns: (_crop.quarterTurns + delta) % 4);
      _applyRatio();
    });
  }

  void _selectRatio(_CropRatio value) {
    setState(() {
      _ratio = value;
      _applyRatio();
    });
  }

  void _applyRatio() {
    final target = _targetAspect;
    if (target == null) return;
    final normalizedRatio = target / _sourceAspect;
    var width = _crop.width;
    var height = width / normalizedRatio;
    if (height > 1) {
      height = 1;
      width = height * normalizedRatio;
    }
    width = width.clamp(0.08, 1.0);
    height = height.clamp(0.08, 1.0);
    _crop = CropSpec(
      left: ((1 - width) / 2).clamp(0, 1 - width),
      top: ((1 - height) / 2).clamp(0, 1 - height),
      width: width,
      height: height,
      quarterTurns: _crop.quarterTurns,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: EdgeInsets.all(size.width < 600 ? 8 : 28),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 740),
        child: SizedBox(
          width: 900,
          height: size.height - (size.width < 600 ? 16 : 56),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 10),
                child: Row(
                  children: [
                    Icon(Icons.crop_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Text(
                      '裁剪与旋转',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: const Color(0xff171b1a),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _CropCanvas(
                      bytes: widget.bytes,
                      sourceAspect: _sourceAspect,
                      crop: _crop,
                      targetAspect: _targetAspect,
                      onChanged: (value) => setState(() => _crop = value),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final ratio in _CropRatio.values)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(ratio.label),
                                selected: _ratio == ratio,
                                onSelected: (_) => _selectRatio(ratio),
                              ),
                            ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: '向左旋转',
                            onPressed: () => _rotate(-1),
                            icon: const Icon(Icons.rotate_left_rounded),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: '向右旋转',
                            onPressed: () => _rotate(1),
                            icon: const Icon(Icons.rotate_right_rounded),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _crop = CropSpec.full;
                            _ratio = _CropRatio.free;
                          }),
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('重置'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => Navigator.pop(context, _crop),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('应用'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _CropRatio { free, original, square, landscape, portrait }

extension on _CropRatio {
  String get label => switch (this) {
    _CropRatio.free => '自由',
    _CropRatio.original => '原图',
    _CropRatio.square => '1 : 1',
    _CropRatio.landscape => '4 : 3',
    _CropRatio.portrait => '3 : 4',
  };
}

enum _DragMode { none, move, topLeft, topRight, bottomLeft, bottomRight }

class _CropCanvas extends StatefulWidget {
  const _CropCanvas({
    required this.bytes,
    required this.sourceAspect,
    required this.crop,
    required this.targetAspect,
    required this.onChanged,
  });

  final Uint8List bytes;
  final double sourceAspect;
  final CropSpec crop;
  final double? targetAspect;
  final ValueChanged<CropSpec> onChanged;

  @override
  State<_CropCanvas> createState() => _CropCanvasState();
}

class _CropCanvasState extends State<_CropCanvas> {
  _DragMode _dragMode = _DragMode.none;
  Offset _lastPoint = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var width = constraints.maxWidth;
        var height = width / widget.sourceAspect;
        if (height > constraints.maxHeight) {
          height = constraints.maxHeight;
          width = height * widget.sourceAspect;
        }
        final imageRect = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
          width: width,
          height: height,
        );
        final oddTurns = widget.crop.quarterTurns.isOdd;
        return Stack(
          children: [
            Positioned.fromRect(
              rect: imageRect,
              child: ClipRect(
                child: RotatedBox(
                  quarterTurns: widget.crop.quarterTurns,
                  child: SizedBox(
                    width: oddTurns ? imageRect.height : imageRect.width,
                    height: oddTurns ? imageRect.width : imageRect.height,
                    child: Image.memory(
                      widget.bytes,
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: imageRect,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  _lastPoint = details.localPosition;
                  _dragMode = _hitTest(
                    details.localPosition,
                    Size(width, height),
                  );
                },
                onPanUpdate: (details) {
                  _updateCrop(
                    details.localPosition,
                    _lastPoint,
                    Size(width, height),
                  );
                  _lastPoint = details.localPosition;
                },
                onPanEnd: (_) => _dragMode = _DragMode.none,
                child: CustomPaint(painter: _CropOverlayPainter(widget.crop)),
              ),
            ),
          ],
        );
      },
    );
  }

  _DragMode _hitTest(Offset point, Size size) {
    final cropRect = _rectForCrop(widget.crop, size);
    const radius = 30.0;
    if ((point - cropRect.topLeft).distance <= radius) return _DragMode.topLeft;
    if ((point - cropRect.topRight).distance <= radius) {
      return _DragMode.topRight;
    }
    if ((point - cropRect.bottomLeft).distance <= radius) {
      return _DragMode.bottomLeft;
    }
    if ((point - cropRect.bottomRight).distance <= radius) {
      return _DragMode.bottomRight;
    }
    if (cropRect.contains(point)) return _DragMode.move;
    return _DragMode.none;
  }

  void _updateCrop(Offset point, Offset previous, Size size) {
    if (_dragMode == _DragMode.none) return;
    final current = widget.crop;
    if (_dragMode == _DragMode.move) {
      final dx = (point.dx - previous.dx) / size.width;
      final dy = (point.dy - previous.dy) / size.height;
      widget.onChanged(
        current.copyWith(
          left: (current.left + dx).clamp(0, 1 - current.width),
          top: (current.top + dy).clamp(0, 1 - current.height),
        ),
      );
      return;
    }

    final normalizedPoint = Offset(
      (point.dx / size.width).clamp(0, 1),
      (point.dy / size.height).clamp(0, 1),
    );
    final isLeft =
        _dragMode == _DragMode.topLeft || _dragMode == _DragMode.bottomLeft;
    final isTop =
        _dragMode == _DragMode.topLeft || _dragMode == _DragMode.topRight;
    final anchor = Offset(
      isLeft ? current.left + current.width : current.left,
      isTop ? current.top + current.height : current.top,
    );
    var width = (normalizedPoint.dx - anchor.dx).abs().clamp(0.06, 1.0);
    var height = (normalizedPoint.dy - anchor.dy).abs().clamp(0.06, 1.0);
    final target = widget.targetAspect;
    if (target != null) {
      final normalizedRatio = target * size.height / size.width;
      if (width / height > normalizedRatio) {
        height = width / normalizedRatio;
      } else {
        width = height * normalizedRatio;
      }
    }
    final maxWidth = isLeft ? anchor.dx : 1 - anchor.dx;
    final maxHeight = isTop ? anchor.dy : 1 - anchor.dy;
    final scale = [
      1.0,
      maxWidth / width,
      maxHeight / height,
    ].reduce((value, item) => value < item ? value : item);
    width *= scale;
    height *= scale;
    widget.onChanged(
      CropSpec(
        left: isLeft ? anchor.dx - width : anchor.dx,
        top: isTop ? anchor.dy - height : anchor.dy,
        width: width,
        height: height,
        quarterTurns: current.quarterTurns,
      ),
    );
  }

  Rect _rectForCrop(CropSpec crop, Size size) => Rect.fromLTWH(
    crop.left * size.width,
    crop.top * size.height,
    crop.width * size.width,
    crop.height * size.height,
  );
}

class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter(this.crop);

  final CropSpec crop;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      crop.left * size.width,
      crop.top * size.height,
      crop.width * size.width,
      crop.height * size.height,
    );
    final dim = Paint()..color = Colors.black.withValues(alpha: 0.58);
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRect(rect),
      dim,
    );
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRect(rect, border);
    final guides = Paint()
      ..color = Colors.white.withValues(alpha: 0.58)
      ..strokeWidth = 0.8;
    for (final part in const [1 / 3, 2 / 3]) {
      canvas.drawLine(
        Offset(rect.left + rect.width * part, rect.top),
        Offset(rect.left + rect.width * part, rect.bottom),
        guides,
      );
      canvas.drawLine(
        Offset(rect.left, rect.top + rect.height * part),
        Offset(rect.right, rect.top + rect.height * part),
        guides,
      );
    }
    final handles = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      canvas.drawCircle(corner, 7, handles);
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) =>
      oldDelegate.crop != crop;
}
