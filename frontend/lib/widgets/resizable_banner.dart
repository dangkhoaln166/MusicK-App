import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/home_ui_provider.dart';

class ResizableBanner extends StatelessWidget {
  final Widget child;

  const ResizableBanner({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final homeUi = Provider.of<HomeUiProvider>(context);
    final isEditMode = homeUi.isEditMode;
    final currentHeight = homeUi.bannerHeight;
    final currentWidth = homeUi.bannerWidth;

    Widget content = SizedBox(
      height: currentHeight,
      width: currentWidth ?? double.infinity,
      child: child,
    );

    if (!isEditMode) {
      return content;
    }

    return SizedBox(
      height: currentHeight,
      width: currentWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: child),
          // Bottom-Right Resize Handle
          Positioned(
            bottom: -15,
            right: -15,
            child: GestureDetector(
              onPanUpdate: (details) {
                double newHeight = currentHeight + details.delta.dy;
                if (newHeight < 150) newHeight = 150;
                if (newHeight > 800) newHeight = 800;
                
                double newWidth = (currentWidth ?? MediaQuery.of(context).size.width - 48) + details.delta.dx;
                if (newWidth < 200) newWidth = 200;
                if (newWidth > MediaQuery.of(context).size.width) newWidth = MediaQuery.of(context).size.width;

                homeUi.updateBannerHeight(newHeight);
                homeUi.updateBannerWidth(newWidth);
              },
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: const Offset(0, 2))
                  ],
                ),
                child: const Icon(Icons.open_with, color: Colors.white, size: 16),
              ),
            ),
          ),
          // Highlight border
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blueAccent, width: 2, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
