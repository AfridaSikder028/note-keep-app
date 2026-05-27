import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class DrawingScreen extends StatefulWidget {
  const DrawingScreen({super.key});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final List<_Stroke> _strokes = [];
  final List<_Stroke> _undoneStrokes = [];
  _Stroke? _currentStroke;
  bool _isSaving = false;

  Color _selectedColor = Colors.black;
  double _strokeWidth = 4.0;
  String _selectedTool = 'pen';

  final GlobalKey _repaintKey = GlobalKey();
  final GlobalKey _canvasKey = GlobalKey();

  final ScrollController _colorScrollCtrl = ScrollController();
  bool _colorDragging = false;
  double _colorDragStartX = 0;
  double _colorScrollStart = 0;
  bool _colorScrollReady = false;

  static const List<Map<String, dynamic>> _tools = [
    {'id': 'pen',         'label': 'Pen',         'icon': Icons.edit},
    {'id': 'pencil',      'label': 'Pencil',      'icon': Icons.draw},
    {'id': 'marker',      'label': 'Marker',      'icon': Icons.brush},
    {'id': 'highlighter', 'label': 'Highlighter', 'icon': Icons.highlight},
    {'id': 'eraser',      'label': 'Eraser',      'icon': Icons.auto_fix_high},
  ];

  static const List<Color> _colors = [
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.pink,
    Colors.brown,
    Colors.grey,
    Colors.cyan,
    Color(0xFF795548),
    Color(0xFF607D8B),
    Color(0xFFE91E63),
    Color(0xFF00BCD4),
    Color(0xFF8BC34A),
    Color(0xFFFF5722),
  ];

  static const List<double> _widths = [2, 4, 7, 12, 20];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _colorScrollReady = true);
    });
  }

  @override
  void dispose() {
    _colorScrollCtrl.dispose();
    super.dispose();
  }

  Color get _effectiveColor {
    // FIX: eraser uses white color (not BlendMode.clear) so saved PNG shows white
    if (_selectedTool == 'eraser') return Colors.white;
    if (_selectedTool == 'highlighter') return _selectedColor.withOpacity(0.30);
    if (_selectedTool == 'pencil') return _selectedColor.withOpacity(0.65);
    return _selectedColor;
  }

  double get _effectiveWidth {
    if (_selectedTool == 'highlighter') return _strokeWidth * 5;
    if (_selectedTool == 'eraser') return _strokeWidth * 5;
    if (_selectedTool == 'marker') return _strokeWidth * 2.5;
    return _strokeWidth;
  }

  Offset _toLocal(Offset globalPos) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return globalPos;
    return box.globalToLocal(globalPos);
  }

  void _onPanStart(DragStartDetails d) {
    setState(() {
      _currentStroke = _Stroke(
        color: _effectiveColor,
        width: _effectiveWidth,
        tool: _selectedTool,
        points: [_toLocal(d.globalPosition)],
      );
      _undoneStrokes.clear();
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() => _currentStroke?.points.add(_toLocal(d.globalPosition)));
  }

  void _onPanEnd(DragEndDetails d) {
    if (_currentStroke != null && _currentStroke!.points.isNotEmpty) {
      setState(() {
        _strokes.add(_currentStroke!);
        _currentStroke = null;
      });
    }
  }

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() => _undoneStrokes.add(_strokes.removeLast()));
    }
  }

  void _redo() {
    if (_undoneStrokes.isNotEmpty) {
      setState(() => _strokes.add(_undoneStrokes.removeLast()));
    }
  }

  void _clear() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('Clear canvas', style: TextStyle(color: Colors.white)),
        content: const Text('This will erase everything.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _strokes.clear();
                _undoneStrokes.clear();
              });
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDrawing() async {
    if (_strokes.isEmpty) {
      Navigator.pop(context, null);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        Navigator.pop(context, null);
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        Navigator.pop(context, null);
        return;
      }
      final base64Str = base64Encode(byteData.buffer.asUint8List());
      if (mounted) Navigator.pop(context, base64Str);
    } catch (e) {
      if (mounted) Navigator.pop(context, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context, null),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.undo,
                color: _strokes.isNotEmpty ? Colors.black87 : Colors.black26),
            onPressed: _strokes.isNotEmpty ? _undo : null,
          ),
          IconButton(
            icon: Icon(Icons.redo,
                color: _undoneStrokes.isNotEmpty
                    ? Colors.black87
                    : Colors.black26),
            onPressed: _undoneStrokes.isNotEmpty ? _redo : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.black87),
            onPressed: _clear,
          ),
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.check, color: Colors.black87),
                  onPressed: _saveDrawing,
                ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RepaintBoundary(
              key: _repaintKey,
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Container(
                  key: _canvasKey,
                  // White background ensures eraser shows white when saved
                  color: Colors.white,
                  child: CustomPaint(
                    painter: _DrawingPainter(
                        strokes: _strokes, currentStroke: _currentStroke),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
          _buildToolsPanel(),
        ],
      ),
    );
  }

  Widget _buildToolsPanel() {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: Color(0xFFE0E0E0)),

          // Tool selector
          SizedBox(
            height: 76,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: _tools.length,
              itemBuilder: (_, i) {
                final tool = _tools[i];
                final isActive = _selectedTool == tool['id'];
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedTool = tool['id']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 60,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.black87 : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color:
                              isActive ? Colors.black87 : Colors.black12),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2))
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(tool['icon'] as IconData,
                            color: isActive
                                ? Colors.white
                                : Colors.black54,
                            size: 22),
                        const SizedBox(height: 3),
                        Text(tool['label'] as String,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: isActive
                                    ? Colors.white
                                    : Colors.black54)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Stroke width
          SizedBox(
            height: 44,
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Text('Size',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                        fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _widths.length,
                    itemBuilder: (_, i) {
                      final w = _widths[i];
                      final isActive = _strokeWidth == w;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _strokeWidth = w),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 150),
                            width: (w * 2.2).clamp(6, 36),
                            height: (w * 2.2).clamp(6, 36),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? _selectedColor
                                  : Colors.black26,
                              shape: BoxShape.circle,
                              border: isActive
                                  ? Border.all(
                                      color: Colors.blue.shade300,
                                      width: 2.5)
                                  : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Color palette with drag scrollbar
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        if (!_colorScrollReady ||
                            !_colorScrollCtrl.hasClients) return;
                        final maxScroll =
                            _colorScrollCtrl.position.maxScrollExtent;
                        if (maxScroll <= 0) return;
                        final ratio = details.localPosition.dx /
                            constraints.maxWidth;
                        _colorScrollCtrl.jumpTo(
                            (ratio * maxScroll).clamp(0.0, maxScroll));
                      },
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: !_colorScrollReady
                            ? Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: 0.4,
                                  child: Container(
                                    decoration: BoxDecoration(
                                        color: Colors.black38,
                                        borderRadius:
                                            BorderRadius.circular(7)),
                                  ),
                                ),
                              )
                            : AnimatedBuilder(
                                animation: _colorScrollCtrl,
                                builder: (_, __) {
                                  if (!_colorScrollCtrl.hasClients) {
                                    return Container(
                                        decoration: BoxDecoration(
                                            color: Colors.black38,
                                            borderRadius:
                                                BorderRadius.circular(
                                                    7)));
                                  }
                                  final maxScroll = _colorScrollCtrl
                                      .position.maxScrollExtent;
                                  if (maxScroll <= 0) {
                                    return Container(
                                        decoration: BoxDecoration(
                                            color: Colors.black38,
                                            borderRadius:
                                                BorderRadius.circular(
                                                    7)));
                                  }
                                  final thumbFraction =
                                      (constraints.maxWidth /
                                              (maxScroll +
                                                  constraints.maxWidth))
                                          .clamp(0.1, 1.0);
                                  final thumbLeft =
                                      (_colorScrollCtrl.offset /
                                              maxScroll) *
                                          constraints.maxWidth *
                                          (1 - thumbFraction);
                                  return Stack(
                                    children: [
                                      Positioned(
                                        left: thumbLeft,
                                        top: 2,
                                        bottom: 2,
                                        width: constraints.maxWidth *
                                            thumbFraction,
                                        child: Container(
                                          decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      7)),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                    );
                  },
                ),
              ),

              SizedBox(
                height: 56,
                child: Listener(
                  onPointerDown: (e) {
                    _colorDragging = true;
                    _colorDragStartX = e.position.dx;
                    _colorScrollStart = _colorScrollCtrl.offset;
                  },
                  onPointerMove: (e) {
                    if (!_colorDragging) return;
                    final delta = _colorDragStartX - e.position.dx;
                    final newOffset = (_colorScrollStart + delta).clamp(
                        0.0, _colorScrollCtrl.position.maxScrollExtent);
                    _colorScrollCtrl.jumpTo(newOffset);
                  },
                  onPointerUp: (_) => _colorDragging = false,
                  onPointerCancel: (_) => _colorDragging = false,
                  child: ListView.builder(
                    controller: _colorScrollCtrl,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: _colors.length,
                    itemBuilder: (_, i) {
                      final color = _colors[i];
                      final isActive = _selectedColor == color &&
                          _selectedTool != 'eraser';
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedColor = color;
                          if (_selectedTool == 'eraser') {
                            _selectedTool = 'pen';
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isActive
                                ? Border.all(
                                    color: Colors.blue.shade400,
                                    width: 3)
                                : Border.all(
                                    color: Colors.black12, width: 1),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                        color: Colors.blue.withOpacity(0.3),
                                        blurRadius: 6)
                                  ]
                                : [],
                          ),
                          child: isActive
                              ? Icon(Icons.check,
                                  size: 16,
                                  color: color == Colors.white ||
                                          color == Colors.yellow
                                      ? Colors.black
                                      : Colors.white)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _Stroke {
  final Color color;
  final double width;
  final String tool;
  final List<Offset> points;

  _Stroke(
      {required this.color,
      required this.width,
      required this.tool,
      required this.points});
}

class _DrawingPainter extends CustomPainter {
  final List<_Stroke> strokes;
  final _Stroke? currentStroke;

  _DrawingPainter({required this.strokes, this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    // FIX: Draw white background first so eraser (white paint) is visible
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    final all = [
      ...strokes,
      if (currentStroke != null) currentStroke!
    ];

    for (final stroke in all) {
      if (stroke.points.length < 2) {
        final paint = Paint()
          ..color = stroke.color
          ..strokeWidth = stroke.width
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
            stroke.points.first, stroke.width / 2, paint);
        continue;
      }

      final paint = Paint()
        ..color = stroke.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      switch (stroke.tool) {
        case 'pencil':
          paint
            ..strokeWidth = stroke.width
            ..maskFilter =
                const MaskFilter.blur(BlurStyle.normal, 0.5);
          break;
        case 'marker':
          paint
            ..strokeWidth = stroke.width
            ..strokeCap = StrokeCap.square;
          break;
        case 'highlighter':
          paint
            ..strokeWidth = stroke.width
            ..strokeCap = StrokeCap.square
            ..blendMode = BlendMode.multiply;
          break;
        case 'eraser':
          // FIX: White color + srcOver instead of BlendMode.clear
          // BlendMode.clear makes transparent pixels → black in PNG
          // White paint on white background = proper erasing
          paint
            ..color = Colors.white
            ..strokeWidth = stroke.width
            ..blendMode = BlendMode.srcOver;
          break;
        default:
          paint.strokeWidth = stroke.width;
      }

      final path = Path()
        ..moveTo(stroke.points[0].dx, stroke.points[0].dy);

      for (int i = 1; i < stroke.points.length; i++) {
        if (i < stroke.points.length - 1) {
          final mid = Offset(
            (stroke.points[i].dx + stroke.points[i + 1].dx) / 2,
            (stroke.points[i].dy + stroke.points[i + 1].dy) / 2,
          );
          path.quadraticBezierTo(stroke.points[i].dx,
              stroke.points[i].dy, mid.dx, mid.dy);
        } else {
          path.lineTo(
              stroke.points[i].dx, stroke.points[i].dy);
        }
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_DrawingPainter old) => true;
}