import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/home_ui_provider.dart';
import 'editable_text_element.dart';

class DraggableEditableText extends StatelessWidget {
  final TextElementConfig config;
  final String defaultText;
  final TextStyle defaultStyle;
  final Function(TextElementConfig) onSave;
  final double defaultDx;
  final double defaultDy;
  final bool asPositioned;

  const DraggableEditableText({
    Key? key,
    required this.config,
    required this.defaultText,
    required this.defaultStyle,
    required this.onSave,
    this.defaultDx = 0,
    this.defaultDy = 0,
    this.asPositioned = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final homeUi = Provider.of<HomeUiProvider>(context);
    final isEditMode = homeUi.isEditMode;

    double dx = config.dx ?? defaultDx;
    double dy = config.dy ?? defaultDy;

    final content = isEditMode
        ? GestureDetector(
            onPanUpdate: (details) {
              final newConfig = TextElementConfig(
                text: config.text,
                fontFamily: config.fontFamily,
                color: config.color,
                size: config.size,
                dx: dx + details.delta.dx,
                dy: dy + details.delta.dy,
              );
              onSave(newConfig);
            },
            child: EditableTextElement(
              config: config,
              defaultText: defaultText,
              defaultStyle: defaultStyle,
              onSave: (newCfg) {
                newCfg.dx = dx;
                newCfg.dy = dy;
                onSave(newCfg);
              },
            ),
          )
        : EditableTextElement(
            config: config,
            defaultText: defaultText,
            defaultStyle: defaultStyle,
            onSave: (newCfg) {
              newCfg.dx = dx;
              newCfg.dy = dy;
              onSave(newCfg);
            },
          );

    if (asPositioned) {
      return Positioned(
        left: dx,
        top: dy,
        child: content,
      );
    } else {
      return Transform.translate(
        offset: Offset(dx, dy),
        child: content,
      );
    }
  }
}
