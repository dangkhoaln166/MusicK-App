import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/lyric_line.dart';
import '../providers/music_provider.dart';

class SyncedLyricsWidget extends StatefulWidget {
  final List<LyricLine> lyrics;

  const SyncedLyricsWidget({Key? key, required this.lyrics}) : super(key: key);

  @override
  _SyncedLyricsWidgetState createState() => _SyncedLyricsWidgetState();
}

class _SyncedLyricsWidgetState extends State<SyncedLyricsWidget> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  late List<GlobalKey> _keys;
  int _currentIndex = 0;
  StreamSubscription? _positionSub;

  static const double _activeFontSize = 36.0;
  static const double _inactiveFontSize = 26.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _keys = List.generate(widget.lyrics.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mp = context.read<MusicProvider>();
      _positionSub = mp.audioPlayer.positionStream.listen(_checkPosition);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-center when coming back from background
      _scrollToActive(_currentIndex);
    }
  }

  void _checkPosition(Duration position) {
    if (widget.lyrics.isEmpty || !mounted) return;

    int newIndex = 0;
    for (int i = 0; i < widget.lyrics.length; i++) {
      if (position >= widget.lyrics[i].time) {
        newIndex = i;
      } else {
        break;
      }
    }

    if (newIndex != _currentIndex) {
      setState(() {
        _currentIndex = newIndex;
      });
      _scrollToActive(newIndex);
    }
  }

  void _scrollToActive(int index) async {
    // We don't block multiple scrolls. If a new lyric comes up quickly, 
    // the new ensureVisible will override the ongoing one.
    
    // Wait for rebuild with updated sizes
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final key = _keys[index];
    if (key.currentContext != null) {
      try {
        await Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          alignment: 0.5, // center the active lyric
        );
      } catch (e) {
        debugPrint('Scroll error: $e');
      }
    }
  }

  @override
  void didUpdateWidget(covariant SyncedLyricsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyrics.length != widget.lyrics.length || 
        (oldWidget.lyrics.isNotEmpty && widget.lyrics.isNotEmpty && oldWidget.lyrics.first.text != widget.lyrics.first.text)) {
      _keys = List.generate(widget.lyrics.length, (_) => GlobalKey());
      _currentIndex = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lyrics.isEmpty) {
      return const Center(
        child: Text(
          'No lyrics available.',
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      // Top & bottom padding allow first/last items to scroll to center
      padding: EdgeInsets.symmetric(
        vertical: MediaQuery.of(context).size.height * 0.38,
        horizontal: 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(widget.lyrics.length, (index) {
          final isActive = index == _currentIndex;
          return GestureDetector(
            key: _keys[index],
            onTap: () {
              final mp = context.read<MusicProvider>();
              mp.seek(widget.lyrics[index].time);
            },
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: isActive ? 12.0 : 8.0),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: isActive ? _activeFontSize : _inactiveFontSize,
                  fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
                  color: isActive
                      ? Colors.white
                      : Colors.white.withOpacity(0.25),
                  height: 1.35,
                  letterSpacing: isActive ? 0.3 : 0,
                ),
                child: Text(
                  widget.lyrics[index].text,
                  textAlign: TextAlign.left,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
