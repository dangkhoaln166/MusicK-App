import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/home_ui_provider.dart';

class EditableTextElement extends StatelessWidget {
  final TextElementConfig config;
  final String defaultText;
  final TextStyle defaultStyle;
  final Function(TextElementConfig) onSave;

  const EditableTextElement({
    Key? key,
    required this.config,
    required this.defaultText,
    required this.defaultStyle,
    required this.onSave,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final homeUi = Provider.of<HomeUiProvider>(context);
    final isEditMode = homeUi.isEditMode;

    final displayText = config.text ?? defaultText;
    final displayColor = config.color != null ? Color(config.color!) : defaultStyle.color;
    final displaySize = config.size ?? defaultStyle.fontSize;
    // Note: To support custom fontFamily properly, it requires loading fonts, 
    // but for now we fallback if not present, or assume standard flutter fonts.
    final displayFont = config.fontFamily ?? defaultStyle.fontFamily;

    final textWidget = Text(
      displayText,
      style: defaultStyle.copyWith(
        color: displayColor,
        fontSize: displaySize,
        fontFamily: displayFont,
      ),
    );

    if (!isEditMode) return textWidget;

    return GestureDetector(
      onTap: () => _showEditDialog(context),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blueAccent, width: 2, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(8),
          color: Colors.blueAccent.withOpacity(0.1),
        ),
        padding: const EdgeInsets.all(4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            textWidget,
            Positioned(
              right: -10,
              top: -10,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, size: 12, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final textCtrl = TextEditingController(text: config.text ?? defaultText);
    String? currentFont = config.fontFamily;
    int? currentColor = config.color;
    double currentSize = config.size ?? defaultStyle.fontSize ?? 14.0;

    final List<String> fonts = ['Roboto', 'Inter', 'Arial', 'Courier', 'Georgia'];
    final List<Color> colors = [
      Colors.white, Colors.black, Colors.red, Colors.blue, 
      Colors.green, Colors.yellow, Colors.purple, Colors.orange
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.grey.shade900,
              title: const Text('Edit Element', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: textCtrl,
                      style: const TextStyle(color: Colors.white),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(labelText: 'Text', labelStyle: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(height: 16),
                    const Text('Font Size', style: TextStyle(color: Colors.white)),
                    Slider(
                      value: currentSize,
                      min: 10,
                      max: 100,
                      onChanged: (v) => setStateDialog(() => currentSize = v),
                    ),
                    const SizedBox(height: 16),
                    const Text('Color', style: TextStyle(color: Colors.white)),
                    Wrap(
                      spacing: 8,
                      children: colors.map((c) {
                        return GestureDetector(
                          onTap: () => setStateDialog(() => currentColor = c.value),
                          child: Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(color: currentColor == c.value ? Colors.blueAccent : Colors.transparent, width: 2),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Font Family (If available)', style: TextStyle(color: Colors.white)),
                    DropdownButton<String>(
                      dropdownColor: Colors.grey.shade800,
                      value: fonts.contains(currentFont) ? currentFont : null,
                      hint: const Text('Default', style: TextStyle(color: Colors.white54)),
                      items: fonts.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(color: Colors.white)))).toList(),
                      onChanged: (v) => setStateDialog(() => currentFont = v),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        setStateDialog(() {
                          currentColor = null;
                          currentFont = null;
                          currentSize = defaultStyle.fontSize ?? 14.0;
                          textCtrl.text = defaultText;
                        });
                      },
                      child: const Text('Reset to Default', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    onSave(TextElementConfig(
                      text: textCtrl.text != defaultText ? textCtrl.text : null,
                      fontFamily: currentFont,
                      color: currentColor,
                      size: currentSize,
                    ));
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
