import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class NoteToolbar extends StatefulWidget {
  final QuillController controller;
  final FocusNode editorFocusNode;
  final ValueChanged<bool>? onBoldChanged;
  final ValueChanged<bool>? onItalicChanged;
  final ValueChanged<bool>? onUnderlineChanged;
  final ValueChanged<Color?>? onColorChanged;
  final ValueChanged<Color?>? onHighlightChanged;
  final bool isChecklistMode;

  const NoteToolbar({
    super.key,
    required this.controller,
    required this.editorFocusNode,
    this.onBoldChanged,
    this.onItalicChanged,
    this.onUnderlineChanged,
    this.onColorChanged,
    this.onHighlightChanged,
    this.isChecklistMode = false,
  });

  @override
  State<NoteToolbar> createState() => _NoteToolbarState();
}

bool _isBoldActive = false;
bool _isItalicActive = false;
bool _isUnderlineActive = false;

class _NoteToolbarState extends State<NoteToolbar> {
  static const List<Map<String, dynamic>> _textColors = [
    {'color': Color(0xFFFF3B30), 'label': 'Red'},
    {'color': Color(0xFFFF9500), 'label': 'Orange'},
    {'color': Color(0xFFFFCC00), 'label': 'Yellow'},
    {'color': Color(0xFF34C759), 'label': 'Green'},
    {'color': Color(0xFF007AFF), 'label': 'Blue'},
    {'color': Color(0xFF5856D6), 'label': 'Purple'},
    {'color': Color(0xFFFF2D55), 'label': 'Pink'},
    {'color': Color(0xFFFFFFFF), 'label': 'White'},
    {'color': Color(0xFF8E8E93), 'label': 'Gray'},
    {'color': Color(0xFF000000), 'label': 'Black'},
  ];

  static const List<Map<String, dynamic>> _highlightColors = [
    {'color': Color(0xFFFFFF00), 'label': 'Yellow'},
    {'color': Color(0xFF90EE90), 'label': 'Green'},
    {'color': Color(0xFFFFB6C1), 'label': 'Pink'},
    {'color': Color(0xFFADD8E6), 'label': 'Blue'},
    {'color': Color(0xFFFFA500), 'label': 'Orange'},
    {'color': Color(0xFFFF6347), 'label': 'Red'},
    {'color': Color(0xFFDA70D6), 'label': 'Purple'},
    {'color': Color(0xFF40E0D0), 'label': 'Teal'},
  ];

  static const Map<int, String> _headingSize = {
    1: 'huge',
    2: 'huge',
    3: 'large',
    4: 'large',
    5: 'small',
  };

  Color? _activeHighlight;
  Color? _activeTextColor;
  TextSelection? _savedSelection;
  bool _isTrackingController = false;

  void _onFocusChanged() => _startTracking();

  void _startTracking() {
    if (_isTrackingController) return;
    _isTrackingController = true;
    widget.controller.addListener(_onControllerChanged);
  }

  void _stopTracking() {
    if (!_isTrackingController) return;
    _isTrackingController = false;
    widget.controller.removeListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    final sel = widget.controller.selection;
    if (!sel.isValid) return;
    _savedSelection = sel;
  }

  void _restoreSelectionAndFocus(VoidCallback formatAction) {
    formatAction();
  }

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  @override
  void didUpdateWidget(NoteToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _stopTracking();
      _savedSelection = null;
      _startTracking();
    }
    if (!widget.isChecklistMode && oldWidget.isChecklistMode) {
      _isBoldActive = false;
      _isItalicActive = false;
      _isUnderlineActive = false;
    }
  }

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  bool _isInlineActive(Attribute attr) {
    if (widget.isChecklistMode) {
      if (attr.key == Attribute.bold.key) return _isBoldActive;
      if (attr.key == Attribute.italic.key) return _isItalicActive;
      if (attr.key == Attribute.underline.key) return _isUnderlineActive;
      return false;
    }
    final style = widget.controller.getSelectionStyle();
    return style.attributes.containsKey(attr.key) &&
        style.attributes[attr.key]?.value != null;
  }

  void _toggleInline(Attribute attr) {
    if (widget.isChecklistMode) {
      if (attr.key == Attribute.bold.key) {
        final newVal = !_isBoldActive;
        setState(() => _isBoldActive = newVal);
        widget.onBoldChanged?.call(newVal);
      } else if (attr.key == Attribute.italic.key) {
        final newVal = !_isItalicActive;
        setState(() => _isItalicActive = newVal);
        widget.onItalicChanged?.call(newVal);
      } else if (attr.key == Attribute.underline.key) {
        final newVal = !_isUnderlineActive;
        setState(() => _isUnderlineActive = newVal);
        widget.onUnderlineChanged?.call(newVal);
      }
      return;
    }
    final style = widget.controller.getSelectionStyle();
    final isActive = style.attributes.containsKey(attr.key) &&
        style.attributes[attr.key]?.value != null;
    _restoreSelectionAndFocus(() {
      widget.controller.formatSelection(
        isActive ? Attribute.clone(attr, null) : attr,
      );
    });
  }

  bool _isListActive(Attribute listAttr) {
    final style = widget.controller.getSelectionStyle();
    return style.attributes.containsKey(listAttr.key) &&
        style.attributes[listAttr.key]?.value == listAttr.value;
  }

  void _toggleList(Attribute listAttr) {
    final style = widget.controller.getSelectionStyle();
    final isActive = style.attributes.containsKey(listAttr.key) &&
        style.attributes[listAttr.key]?.value == listAttr.value;
    _restoreSelectionAndFocus(() {
      if (isActive) {
        widget.controller.formatSelection(Attribute.clone(listAttr, null));
      } else {
        widget.controller.formatSelection(listAttr);
      }
    });
  }

  bool _isHeadingActive(int level) {
    final style = widget.controller.getSelectionStyle();
    final currentSize = style.attributes[Attribute.size.key]?.value;
    return currentSize == _headingSize[level];
  }

  void _applyHeading(int level) {
    _restoreSelectionAndFocus(() {
      final controller = widget.controller;
      final selection = controller.selection;
      final text = controller.document.toPlainText();

      int lineStart = selection.start;
      while (lineStart > 0 && text[lineStart - 1] != '\n') lineStart--;
      int lineEnd = selection.end;
      while (lineEnd < text.length && text[lineEnd] != '\n') lineEnd++;

      controller.updateSelection(
        TextSelection(baseOffset: lineStart, extentOffset: lineEnd),
        ChangeSource.local,
      );

      final targetSize = _headingSize[level];
      final currentSize =
          controller.getSelectionStyle().attributes[Attribute.size.key]?.value;

      if (currentSize == targetSize) {
        controller.formatSelection(const SizeAttribute(null));
      } else {
        controller.formatSelection(SizeAttribute(targetSize));
      }
      controller.updateSelection(selection, ChangeSource.local);
    });
  }

  void _applyTextColor(Color color) {
    final hex =
        '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    final removing = _activeTextColor == color;
    _restoreSelectionAndFocus(() {
      if (removing) {
        widget.controller.formatSelection(ColorAttribute(null));
        setState(() => _activeTextColor = null);
        widget.onColorChanged?.call(null);
      } else {
        widget.controller.formatSelection(ColorAttribute(hex));
        setState(() => _activeTextColor = color);
        widget.onColorChanged?.call(color);
      }
    });
  }

  void _applyHighlight(Color color) {
    final hex =
        '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    final removing = _activeHighlight == color;
    _restoreSelectionAndFocus(() {
      if (removing) {
        widget.controller.formatSelection(BackgroundAttribute(null));
        setState(() => _activeHighlight = null);
        widget.onHighlightChanged?.call(null);
      } else {
        widget.controller.formatSelection(BackgroundAttribute(hex));
        setState(() => _activeHighlight = color);
        widget.onHighlightChanged?.call(color);
      }
    });
  }

  void _clearFormatting() {
    _restoreSelectionAndFocus(() {
      widget.controller
          .formatSelection(Attribute.clone(Attribute.bold, null));
      widget.controller
          .formatSelection(Attribute.clone(Attribute.italic, null));
      widget.controller
          .formatSelection(Attribute.clone(Attribute.underline, null));
      widget.controller
          .formatSelection(Attribute.clone(Attribute.strikeThrough, null));
      widget.controller.formatSelection(BackgroundAttribute(null));
      widget.controller.formatSelection(ColorAttribute(null));
      widget.controller.formatSelection(const SizeAttribute(null));
      setState(() {
        _activeHighlight = null;
        _activeTextColor = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0);
    final dividerColor = isDark ? Colors.white12 : Colors.black12;
    final labelColor = isDark ? Colors.white54 : Colors.black45;
    final iconActiveColor = isDark ? Colors.white : Colors.black87;
    final iconInactiveColor = isDark ? Colors.white70 : Colors.black54;
    final activeBg = isDark
        ? Colors.white.withOpacity(0.15)
        : Colors.black.withOpacity(0.08);
    final dividerLineColor = isDark ? Colors.white24 : Colors.black12;
    final disabledColor = isDark ? Colors.white24 : Colors.black26;

    return Container(
      color: bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                _fmtBtn(
                  icon: Icons.format_bold,
                  tooltip: 'Bold',
                  isActive: _isInlineActive(Attribute.bold),
                  onTap: () => _toggleInline(Attribute.bold),
                  activeColor: iconActiveColor,
                  inactiveColor: iconInactiveColor,
                  activeBg: activeBg,
                ),
                _fmtBtn(
                  icon: Icons.format_italic,
                  tooltip: 'Italic',
                  isActive: _isInlineActive(Attribute.italic),
                  onTap: () => _toggleInline(Attribute.italic),
                  activeColor: iconActiveColor,
                  inactiveColor: iconInactiveColor,
                  activeBg: activeBg,
                ),
                _fmtBtn(
                  icon: Icons.format_underlined,
                  tooltip: 'Underline',
                  isActive: _isInlineActive(Attribute.underline),
                  onTap: () => _toggleInline(Attribute.underline),
                  activeColor: iconActiveColor,
                  inactiveColor: iconInactiveColor,
                  activeBg: activeBg,
                ),
                _fmtBtn(
                  icon: Icons.format_strikethrough,
                  tooltip: 'Strikethrough',
                  isActive: _isInlineActive(Attribute.strikeThrough),
                  onTap: () => _toggleInline(Attribute.strikeThrough),
                  activeColor: iconActiveColor,
                  inactiveColor: iconInactiveColor,
                  activeBg: activeBg,
                ),
                _divider(dividerLineColor),
                if (!widget.isChecklistMode) ...[
                  _headingBtn('H1', 1,
                      activeColor: iconActiveColor,
                      inactiveColor: iconInactiveColor,
                      activeBg: activeBg),
                  _headingBtn('H2', 2,
                      activeColor: iconActiveColor,
                      inactiveColor: iconInactiveColor,
                      activeBg: activeBg),
                  _headingBtn('H3', 3,
                      activeColor: iconActiveColor,
                      inactiveColor: iconInactiveColor,
                      activeBg: activeBg),
                  _headingBtn('H4', 4,
                      activeColor: iconActiveColor,
                      inactiveColor: iconInactiveColor,
                      activeBg: activeBg),
                  _headingBtn('H5', 5,
                      activeColor: iconActiveColor,
                      inactiveColor: iconInactiveColor,
                      activeBg: activeBg),
                ] else ...[
                  _disabledBtn('H1', disabledColor),
                  _disabledBtn('H2', disabledColor),
                  _disabledBtn('H3', disabledColor),
                  _disabledBtn('H4', disabledColor),
                  _disabledBtn('H5', disabledColor),
                ],
                _divider(dividerLineColor),
                _fmtBtn(
                  icon: Icons.format_list_bulleted,
                  tooltip: 'Bullet list',
                  isActive: _isListActive(Attribute.ul),
                  onTap: () => _toggleList(Attribute.ul),
                  activeColor: iconActiveColor,
                  inactiveColor: iconInactiveColor,
                  activeBg: activeBg,
                ),
                _fmtBtn(
                  icon: Icons.format_list_numbered,
                  tooltip: 'Numbered list',
                  isActive: _isListActive(Attribute.ol),
                  onTap: () => _toggleList(Attribute.ol),
                  activeColor: iconActiveColor,
                  inactiveColor: iconInactiveColor,
                  activeBg: activeBg,
                ),
                _divider(dividerLineColor),
                _fmtBtn(
                  icon: Icons.format_clear,
                  tooltip: 'Clear formatting',
                  onTap: _clearFormatting,
                  activeColor: iconActiveColor,
                  inactiveColor: iconInactiveColor,
                  activeBg: activeBg,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: dividerColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
            child: Row(
              children: [
                Icon(Icons.format_color_text,
                    color: _activeTextColor ?? iconInactiveColor, size: 16),
                const SizedBox(width: 6),
                Text('Color',
                    style:
                        TextStyle(color: labelColor, fontSize: 11)),
                const SizedBox(width: 8),
                Expanded(
                  child: _ColorScrollRow(
                    colors: _textColors,
                    activeColor: _activeTextColor,
                    onSelected: _applyTextColor,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
            child: Row(
              children: [
                Icon(Icons.format_color_fill,
                    color: _activeHighlight ?? iconInactiveColor, size: 16),
                const SizedBox(width: 6),
                Text('Mark',
                    style:
                        TextStyle(color: labelColor, fontSize: 11)),
                const SizedBox(width: 8),
                Expanded(
                  child: _ColorScrollRow(
                    colors: _highlightColors,
                    activeColor: _activeHighlight,
                    onSelected: _applyHighlight,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fmtBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required Color activeColor,
    required Color inactiveColor,
    required Color activeBg,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: isActive ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon,
              color: isActive ? activeColor : inactiveColor, size: 22),
        ),
      ),
    );
  }

  Widget _headingBtn(
    String label,
    int level, {
    required Color activeColor,
    required Color inactiveColor,
    required Color activeBg,
  }) {
    final isActive = _isHeadingActive(level);
    return Tooltip(
      message: 'Heading $level',
      child: InkWell(
        onTap: () => _applyHeading(level),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : inactiveColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _disabledBtn(String label, Color disabledColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Text(
        label,
        style: TextStyle(
          color: disabledColor,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _divider(Color color) => Container(
        width: 1,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: color,
      );
}

class _ColorScrollRow extends StatefulWidget {
  final List<Map<String, dynamic>> colors;
  final Color? activeColor;
  final ValueChanged<Color> onSelected;
  final bool isDark;

  const _ColorScrollRow({
    required this.colors,
    required this.activeColor,
    required this.onSelected,
    required this.isDark,
  });

  @override
  State<_ColorScrollRow> createState() => _ColorScrollRowState();
}

class _ColorScrollRowState extends State<_ColorScrollRow> {
  final ScrollController _ctrl = ScrollController();
  bool _dragging = false;
  double _dragStartX = 0;
  double _scrollStart = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trackColor =
        widget.isDark ? Colors.white10 : Colors.black12;
    final activeBorderColor =
        widget.isDark ? Colors.white : Colors.black87;
    final inactiveBorderColor =
        widget.isDark ? Colors.white24 : Colors.black12;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(builder: (ctx, constraints) {
          return GestureDetector(
            onHorizontalDragUpdate: (d) {
              if (!_ready || !_ctrl.hasClients) return;
              final max = _ctrl.position.maxScrollExtent;
              if (max <= 0) return;
              final ratio = d.localPosition.dx / constraints.maxWidth;
              _ctrl.jumpTo((ratio * max).clamp(0.0, max));
            },
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: BorderRadius.circular(2)),
              child: !_ready
                  ? null
                  : AnimatedBuilder(
                      animation: _ctrl,
                      builder: (_, __) {
                        if (!_ctrl.hasClients) return const SizedBox();
                        final max = _ctrl.position.maxScrollExtent;
                        if (max <= 0) return const SizedBox();
                        final frac = (constraints.maxWidth /
                                (max + constraints.maxWidth))
                            .clamp(0.1, 1.0);
                        final left = (_ctrl.offset / max) *
                            constraints.maxWidth *
                            (1 - frac);
                        return Stack(children: [
                          Positioned(
                            left: left,
                            top: 0,
                            bottom: 0,
                            width: constraints.maxWidth * frac,
                            child: Container(
                              decoration: BoxDecoration(
                                  color: const Color(0xFFFFA000),
                                  borderRadius:
                                      BorderRadius.circular(2)),
                            ),
                          ),
                        ]);
                      }),
            ),
          );
        }),
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          child: Listener(
            onPointerDown: (e) {
              _dragging = true;
              _dragStartX = e.position.dx;
              _scrollStart = _ctrl.offset;
            },
            onPointerMove: (e) {
              if (!_dragging) return;
              final delta = _dragStartX - e.position.dx;
              if (_ctrl.hasClients) {
                _ctrl.jumpTo((_scrollStart + delta)
                    .clamp(0.0, _ctrl.position.maxScrollExtent));
              }
            },
            onPointerUp: (_) => _dragging = false,
            onPointerCancel: (_) => _dragging = false,
            child: ListView.builder(
              controller: _ctrl,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              itemCount: widget.colors.length,
              itemBuilder: (_, i) {
                final color = widget.colors[i]['color'] as Color;
                final isActive = widget.activeColor == color;
                return GestureDetector(
                  onTap: () => widget.onSelected(color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isActive
                          ? Border.all(
                              color: activeBorderColor, width: 2.5)
                          : Border.all(
                              color: inactiveBorderColor, width: 1),
                    ),
                    child: isActive
                        ? Icon(Icons.check,
                            size: 14,
                            color: color == Colors.white ||
                                    color ==
                                        const Color(0xFFFFFF00) ||
                                    color == const Color(0xFFFFCC00)
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
    );
  }
}