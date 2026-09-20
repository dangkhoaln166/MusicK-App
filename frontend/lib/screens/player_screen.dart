import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../providers/music_provider.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../utils/custom_toast.dart';
import '../models/lyric_line.dart';
import '../services/api_service.dart';
import '../widgets/synced_lyrics_widget.dart';

enum LyricsLanguage { original, romaji, translatedVi, translatedEn }

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({Key? key}) : super(key: key);

  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Track? _cachedTrack;
  Future<Map<String, dynamic>?>? _lyricsFuture;
  
  LyricsLanguage _lyricsLanguage = LyricsLanguage.original;
  bool _isTranslating = false;
  
  // Cache for lyrics variations for current track
  final Map<LyricsLanguage, Map<String, dynamic>> _lyricsCache = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mp = context.read<MusicProvider>();

    // Cache lyrics per track — only refetch when track changes
    final track = mp.currentTrack;
    if (track != null && track.videoId != _cachedTrack?.videoId) {
      _cachedTrack = track;
      _lyricsCache.clear();
      _lyricsLanguage = LyricsLanguage.original;
      
      _lyricsFuture = () async {
        final customData = await ApiService().getCustomLyrics(track.videoId);
        final data = customData ?? await ApiService().getLyrics(track.title, videoId: track.videoId);
        if (data != null && mounted) {
          _lyricsCache[LyricsLanguage.original] = data;
        }
        return data;
      }();
    }
  }
  
  void _syncAnimation(bool isPlaying) {
    if (isPlaying && !_animationController.isAnimating) {
      _animationController.repeat();
    } else if (!isPlaying && _animationController.isAnimating) {
      _animationController.stop();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inHours > 0 ? '${duration.inHours}:' : ''}$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final track = context.select<MusicProvider, Track?>((p) => p.currentTrack);
    if (track == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text("No track playing", style: TextStyle(color: Colors.white))),
      );
    }

    // Select isPlaying so build re-runs whenever play state changes
    final isPlaying = context.select<MusicProvider, bool>((p) => p.isPlaying);
    // Sync vinyl outside the build frame to avoid setState-during-build errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncAnimation(isPlaying);
    });

    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple.shade900.withOpacity(0.5),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, size: 32, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Now Playing',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the flex
                  ],
                ),
              ),
              // Main Content (Album Art + Lyrics)
              Expanded(
                child: isWide ? _buildWideMainArea(context, track) : _buildPortraitMainArea(context, track),
              ),
              // Bottom Player Bar
              _buildBottomPlayerBar(context, track, isWide),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideMainArea(BuildContext context, Track track) {
    final imageSize = MediaQuery.of(context).size.height * 0.5 > 400.0 ? 400.0 : MediaQuery.of(context).size.height * 0.5;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 4,
          child: Center(child: _buildAlbumArt(track.thumbnail, imageSize, track)),
        ),
        Expanded(
          flex: 5,
          child: _buildLyricsView(track),
        ),
      ],
    );
  }

  Widget _buildPortraitMainArea(BuildContext context, Track track) {
    final imageSize = MediaQuery.of(context).size.width * 0.7;
    return Column(
      children: [
        const SizedBox(height: 20),
        _buildAlbumArt(track.thumbnail, imageSize, track),
        const SizedBox(height: 20),
        Expanded(child: _buildLyricsView(track)),
      ],
    );
  }

  void _showChangeCoverDialog(BuildContext context, Track track) {
    final TextEditingController urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Thay đổi ảnh bìa', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey.shade900,
        content: TextField(
          controller: urlController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Dán đường link ảnh (URL) vào đây...',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Hủy', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              if (urlController.text.isNotEmpty) {
                final success = await ApiService().updateThumbnail(track.videoId, urlController.text);
                if (success) {
                  setState(() {
                    track.thumbnail = urlController.text;
                  });
                  if (mounted) CustomToast.show(context, 'Cập nhật ảnh bìa thành công!');
                } else {
                  if (mounted) CustomToast.show(context, 'Có lỗi xảy ra!');
                }
              }
              if (mounted) Navigator.pop(c);
            },
            child: const Text('Lưu', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  void _showEditLyricsDialog(BuildContext context, Track track, Map<String, dynamic>? currentLyricsData) {
    final TextEditingController textController = TextEditingController(
        text: currentLyricsData?['syncedLyrics'] ?? currentLyricsData?['plainLyrics'] ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Sửa lời bài hát', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.grey.shade900,
            content: SizedBox(
              width: double.maxFinite,
              child: TextField(
                controller: textController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 15,
                decoration: const InputDecoration(
                  hintText: 'Dán lời bài hát (dạng trơn hoặc file .lrc) vào đây...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Hủy', style: TextStyle(color: Colors.white70)),
              ),
              TextButton(
                onPressed: isSaving ? null : () async {
                  setDialogState(() => isSaving = true);
                  final text = textController.text.trim();
                  // Check if it's LRC format
                  bool isSynced = text.contains(RegExp(r'\[\d{2}:\d{2}\.\d{2}\]'));
                  
                  final success = await ApiService().saveCustomLyrics(
                    track.videoId,
                    isSynced ? null : text,
                    isSynced ? text : null,
                  );
                  
                  if (success) {
                    if (mounted) {
                      CustomToast.show(context, 'Đã lưu lời bài hát!');
                      // Trigger a reload
                      setState(() {
                        _cachedTrack = null;
                      });
                      didChangeDependencies();
                      Navigator.pop(c);
                    }
                  } else {
                    if (mounted) {
                      CustomToast.show(context, 'Có lỗi khi lưu lời bài hát.');
                      setDialogState(() => isSaving = false);
                    }
                  }
                },
                child: isSaving 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Lưu', style: TextStyle(color: Colors.blueAccent)),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildLyricsView(Track track) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _lyricsFuture,
      builder: (context, snapshot) {
        Widget content;
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          content = const Center(child: CircularProgressIndicator(color: Colors.white24));
        } else {
          final originalData = snapshot.data;
          if (originalData == null || (originalData['syncedLyrics'] == null && originalData['plainLyrics'] == null)) {
            content = const Center(child: Text("Lyrics not available", style: TextStyle(color: Colors.white54, fontSize: 18)));
          } else {
            // Determine data to show based on language
            var dataToShow = originalData;
            if (_lyricsCache.containsKey(_lyricsLanguage)) {
              dataToShow = _lyricsCache[_lyricsLanguage]!;
            }

            if (dataToShow['syncedLyrics'] != null && dataToShow['syncedLyrics'].toString().trim().isNotEmpty) {
              final lines = LyricLine.parseLrc(dataToShow['syncedLyrics']);
              if (lines.isNotEmpty) {
                content = SyncedLyricsWidget(lyrics: lines);
              } else {
                content = const Center(child: Text("Invalid synced lyrics", style: TextStyle(color: Colors.white54, fontSize: 18)));
              }
            } else {
              // Fallback to plain lyrics
              content = SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                child: Text(
                  dataToShow['plainLyrics'] ?? '',
                  style: const TextStyle(fontSize: 20, height: 2.0, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              );
            }
          }
        }
        
        return Stack(
          fit: StackFit.expand,
          children: [
            content,
            Positioned(
              top: 16,
              right: 16,
              child: Row(
                children: [
                  if (snapshot.connectionState != ConnectionState.waiting)
                    IconButton(
                      icon: const Icon(Icons.edit_note, color: Colors.white70),
                      onPressed: () => _showEditLyricsDialog(context, track, snapshot.data),
                      tooltip: 'Sửa lời bài hát',
                    ),
                  const SizedBox(width: 8),
                  _buildLanguageToggleBtn(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanguageToggleBtn() {
    String label = 'Gốc';
    if (_lyricsLanguage == LyricsLanguage.romaji) label = 'Latin';
    if (_lyricsLanguage == LyricsLanguage.translatedVi) label = 'Tiếng Việt';
    if (_lyricsLanguage == LyricsLanguage.translatedEn) label = 'Tiếng Anh';

    final originalData = _lyricsCache[LyricsLanguage.original];
    final lang = originalData?['lang'] ?? 'unknown';

    PopupMenuItem<LyricsLanguage> _buildMenuItem(LyricsLanguage value, String text, IconData icon) {
      final isSelected = _lyricsLanguage == value;
      return PopupMenuItem<LyricsLanguage>(
        value: value,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: isSelected ? Colors.deepPurpleAccent.shade100 : Colors.white70),
            const SizedBox(width: 12),
            Text(
              text, 
              style: TextStyle(
                color: isSelected ? Colors.deepPurpleAccent.shade100 : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              )
            ),
            const SizedBox(width: 16), // Spacing before checkmark
            if (isSelected)
              Icon(Icons.check_circle, size: 18, color: Colors.deepPurpleAccent.shade100)
            else
              const SizedBox(width: 18), // Placeholder for alignment
          ],
        ),
      );
    }

    List<PopupMenuEntry<LyricsLanguage>> menuItems = [
      _buildMenuItem(LyricsLanguage.original, 'Gốc (Original)', Icons.library_music),
    ];

    if (lang == 'vi') {
      menuItems.add(const PopupMenuDivider(height: 1));
      menuItems.add(_buildMenuItem(LyricsLanguage.translatedEn, 'Dịch sang Tiếng Anh', Icons.g_translate));
    } else if (lang == 'en') {
      menuItems.add(const PopupMenuDivider(height: 1));
      menuItems.add(_buildMenuItem(LyricsLanguage.translatedVi, 'Dịch sang Tiếng Việt', Icons.g_translate));
    } else {
      menuItems.add(const PopupMenuDivider(height: 1));
      menuItems.add(_buildMenuItem(LyricsLanguage.romaji, 'Phiên âm (Latin)', Icons.sort_by_alpha));
      menuItems.add(const PopupMenuDivider(height: 1));
      menuItems.add(_buildMenuItem(LyricsLanguage.translatedVi, 'Dịch sang Tiếng Việt', Icons.translate));
      menuItems.add(_buildMenuItem(LyricsLanguage.translatedEn, 'Dịch sang Tiếng Anh', Icons.g_translate));
    }

    return PopupMenuButton<LyricsLanguage>(
      color: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      offset: const Offset(0, 40),
      onSelected: (LyricsLanguage result) async {
        if (_lyricsLanguage == result) return;

        if (_lyricsCache[LyricsLanguage.original] == null || _lyricsCache[LyricsLanguage.original]?['syncedLyrics'] == null) {
          if (mounted) CustomToast.show(context, 'Chưa có lời bài hát để dịch');
          return;
        }

        if (result == LyricsLanguage.original || _lyricsCache.containsKey(result)) {
          setState(() {
            _lyricsLanguage = result;
          });
          return;
        }

        // Need to translate
        setState(() {
          _isTranslating = true;
        });

        String targetLang = 'vi';
        if (result == LyricsLanguage.translatedEn) targetLang = 'en';

        final originalLrc = _lyricsCache[LyricsLanguage.original]!['syncedLyrics'];
        final res = await ApiService().translateLyrics(originalLrc, targetLang: targetLang);
        
        if (res != null && mounted) {
          final originalData = _lyricsCache[LyricsLanguage.original]!;
          
          final transKey = targetLang == 'en' ? LyricsLanguage.translatedEn : LyricsLanguage.translatedVi;
          
          bool translationSuccess = res['translated'] != null && res['translated'].toString().trim().isNotEmpty;
          
          if (translationSuccess) {
            _lyricsCache[transKey] = {
              'plainLyrics': originalData['plainLyrics'],
              'syncedLyrics': res['translated']
            };
          }
          
          if (res['romaji'] != null && res['romaji'].toString().trim().isNotEmpty) {
            _lyricsCache[LyricsLanguage.romaji] = {
              'plainLyrics': originalData['plainLyrics'],
              'syncedLyrics': res['romaji']
            };
          }
          
          if (result == transKey && !translationSuccess) {
            if (mounted) {
              CustomToast.show(context, 'Lỗi khi dịch lời bài hát (Google Translate quá tải, thử lại sau)');
              setState(() {
                _isTranslating = false;
              });
            }
            return;
          }
          
          setState(() {
            _lyricsLanguage = result;
            _isTranslating = false;
          });
        } else {
          if (mounted) {
            CustomToast.show(context, 'Lỗi khi dịch lời bài hát (có thể quá tải, thử lại sau)');
            setState(() {
              _isTranslating = false;
            });
          }
        }
      },
      itemBuilder: (BuildContext context) => menuItems,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.translate, size: 16, color: Colors.deepPurpleAccent.shade100),
            const SizedBox(width: 8),
            _isTranslating 
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
              : Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumArt(String? url, double size, Track track) {
    // Upscale the thumbnail URL from 120x120 to 800x800 for the player screen
    final highResUrl = url?.replaceAll(RegExp(r'=w\d+-h\d+'), '=w800-h800');

    return GestureDetector(
      onLongPress: () => _showChangeCoverDialog(context, track),
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: RotationTransition(
          turns: _animationController,
          child: RepaintBoundary(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black54, width: 8),
                color: Colors.grey.shade900,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipOval(
                    child: highResUrl != null
                        ? Image.network(
                            highResUrl,
                            width: size,
                            height: size,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (context, error, stackTrace) => url != null 

                              ? Image.network(
                                  url,
                                  width: size,
                                  height: size,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.high,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: size,
                                    height: size,
                                    color: Colors.grey.shade800,
                                    child: const Icon(Icons.music_note, color: Colors.white54, size: 120),
                                  ),
                                )
                              : Container(
                                  width: size,
                                  height: size,
                                  color: Colors.grey.shade800,
                                  child: const Icon(Icons.music_note, color: Colors.white54, size: 120),
                                ),
                          )
                        : Container(
                            width: size,
                            height: size,
                            color: Colors.grey.shade800,
                            child: const Icon(Icons.music_note, color: Colors.white54, size: 120),
                          ),
                  ),
                  Center(
                child: Container(
                  height: size * 0.15,
                  width: size * 0.15,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black87,
                    border: Border.all(color: Colors.white24, width: 2),
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

  Widget _buildBottomPlayerBar(BuildContext context, Track track, bool isWide) {
    if (isWide) {
      return Container(
        height: 85,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(color: Colors.grey.shade900.withOpacity(0.8)),
        child: Row(
          children: [
            SizedBox(
              width: 300,
              child: _buildTrackInfo(context, track),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControls(context),
                      const SizedBox(height: 4),
                      _buildProgressBar(context),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 300,
              child: _buildExtraActions(context, track),
            ),
          ],
        ),
      );
    } else {
      // Portrait bottom bar
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        decoration: BoxDecoration(color: Colors.grey.shade900.withOpacity(0.9)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTrackInfo(context, track),
            const SizedBox(height: 16),
            _buildProgressBar(context),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildExtraActions(context, track, compact: true),
                Expanded(child: _buildControls(context)),
              ],
            )
          ],
        ),
      );
    }
  }

  String _cleanTitle(String title) {
    String clean = title;
    if (clean.contains('|')) clean = clean.split('|').first;
    if (clean.contains('//')) clean = clean.split('//').first;
    if (clean.contains('(')) clean = clean.split('(').first;
    if (clean.contains('[')) clean = clean.split('[').first;
    return clean.trim();
  }

  Widget _buildTrackInfo(BuildContext context, Track track) {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    return Row(
      children: [
        if (track.thumbnail != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              track.thumbnail!, 
              width: 56, 
              height: 56, 
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 56,
                height: 56,
                color: Colors.grey.shade800,
                child: const Icon(Icons.music_note, color: Colors.white54),
              ),
            ),
          ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _cleanTitle(track.title),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                track.channel ?? 'Unknown Artist',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    return StreamBuilder<Duration>(
      stream: musicProvider.audioPlayer.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? musicProvider.position;
        return Row(
          children: [
            Text(_formatDuration(position), style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.grey.shade800,
                  thumbColor: Colors.white,
                  trackHeight: 3.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
                ),
                child: Slider(
                  min: 0,
                  max: musicProvider.duration.inSeconds.toDouble() > 0 ? musicProvider.duration.inSeconds.toDouble() : 1.0,
                  value: position.inSeconds.toDouble().clamp(0, musicProvider.duration.inSeconds.toDouble()),
                  onChanged: (value) {
                    musicProvider.seek(Duration(seconds: value.toInt()));
                  },
                ),
              ),
            ),
            Text(_formatDuration(musicProvider.duration), style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        );
      },
    );
  }

  Widget _buildControls(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, musicProvider, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.shuffle, color: musicProvider.isShuffle ? Colors.greenAccent : Colors.white54, size: 20),
              onPressed: () => musicProvider.toggleShuffle(),
            ),
            const SizedBox(width: 5),
            IconButton(
              icon: const Icon(Icons.skip_previous, size: 32),
              color: Colors.white,
              onPressed: () => musicProvider.playPrevious(),
            ),
            const SizedBox(width: 5),
            IconButton(
              icon: const Icon(Icons.replay_10, size: 28),
              color: Colors.white70,
              onPressed: () => musicProvider.seekBackward(),
            ),
            const SizedBox(width: 5),
              Container(
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                child: IconButton(
                  icon: Icon(
                    musicProvider.isCompleted 
                        ? Icons.replay 
                        : (musicProvider.isPlaying ? Icons.pause : Icons.play_arrow), 
                    size: 36, 
                    color: Colors.black
                  ),
                  onPressed: () => musicProvider.togglePlayPause(),
                ),
              ),
            const SizedBox(width: 5),
            IconButton(
              icon: const Icon(Icons.forward_10, size: 28),
              color: Colors.white70,
              onPressed: () => musicProvider.seekForward(),
            ),
            const SizedBox(width: 5),
            IconButton(
              icon: const Icon(Icons.skip_next, size: 32),
              color: Colors.white,
              onPressed: () => musicProvider.playNext(),
            ),
            const SizedBox(width: 5),
            IconButton(
              icon: Icon(
                musicProvider.loopMode == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                color: musicProvider.loopMode != LoopMode.off ? Colors.greenAccent : Colors.white54,
                size: 20,
              ),
              onPressed: () => musicProvider.toggleRepeat(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExtraActions(BuildContext context, Track track, {bool compact = false}) {
    return Row(
      mainAxisAlignment: compact ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: [
        if (!compact) ...[
          Consumer<MusicProvider>(
            builder: (context, mp, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(mp.volume > 0 ? Icons.volume_up : Icons.volume_off, color: Colors.white54, size: 20),
                    onPressed: () {
                      if (mp.volume > 0) {
                        mp.setVolume(0);
                      } else {
                        mp.setVolume(1.0);
                      }
                    },
                  ),
                  SizedBox(
                    width: 80,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.white54,
                        inactiveTrackColor: Colors.grey.shade800,
                        thumbColor: Colors.white,
                        trackHeight: 3.0,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                      ),
                      child: Slider(
                        value: mp.volume,
                        onChanged: (v) {
                          mp.setVolume(v);
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        Consumer<MusicProvider>(
          builder: (context, mp, _) {
            return IconButton(
              icon: Icon(
                mp.isFavorite(track) ? Icons.favorite : Icons.favorite_border,
                color: mp.isFavorite(track) ? Colors.greenAccent : Colors.white54,
              ),
              onPressed: () {
                mp.toggleFavorite(track);
                CustomToast.show(
                  context,
                  mp.isFavorite(track) ? 'Added to Liked Songs' : 'Removed from Liked Songs',
                  icon: mp.isFavorite(track) ? Icons.favorite : Icons.favorite_border,
                  color: mp.isFavorite(track) ? Colors.greenAccent : Colors.white54,
                );
              },
            );
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white54),
          color: Colors.grey.shade900,
          onSelected: (value) {
            if (value == 'playlist') {
              _showAddToPlaylistSheet(context, track);
            } else {
              CustomToast.show(context, 'Tính năng sắp ra mắt: $value', icon: Icons.info_outline, color: Colors.blueAccent);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'playlist',
              child: ListTile(
                leading: Icon(Icons.playlist_add, color: Colors.white),
                title: Text('Thêm vào album', style: TextStyle(color: Colors.white)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem<String>(
              value: 'speed',
              child: ListTile(
                leading: Icon(Icons.speed, color: Colors.white),
                title: Text('Tốc độ phát', style: TextStyle(color: Colors.white)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem<String>(
              value: 'sleep',
              child: ListTile(
                leading: Icon(Icons.snooze, color: Colors.white),
                title: Text('Hẹn giờ ngủ', style: TextStyle(color: Colors.white)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem<String>(
              value: 'battery',
              child: ListTile(
                leading: Icon(Icons.battery_saver, color: Colors.white),
                title: Text('Tiết kiệm điện', style: TextStyle(color: Colors.white)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem<String>(
              value: 'ringtone',
              child: ListTile(
                leading: Icon(Icons.phonelink_ring, color: Colors.white),
                title: Text('Làm nhạc chuông', style: TextStyle(color: Colors.white)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.redAccent),
                title: Text('Xóa', style: TextStyle(color: Colors.redAccent)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showAddToPlaylistSheet(BuildContext context, Track track) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 400,
            constraints: const BoxConstraints(maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Add to Playlist', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                Flexible(
                  child: Consumer<MusicProvider>(
                    builder: (context, mp, _) {
                      if (mp.playlists.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.library_music_outlined, size: 60, color: Colors.white24),
                              SizedBox(height: 16),
                              const Text("No Playlists Found", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              const Text("Go to the Library tab to create your first playlist!", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 14)),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showCreatePlaylistDialog(context);
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Create Playlist', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: mp.playlists.length,
                        itemBuilder: (context, index) {
                          final playlist = mp.playlists[index];
                          final isAdded = playlist.tracks.any((t) => t.videoId == track.videoId);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: playlist.coverImage != null ? DecorationImage(image: NetworkImage(playlist.coverImage!), fit: BoxFit.cover) : null,
                                color: Colors.grey.shade800,
                              ),
                              child: playlist.coverImage == null ? const Icon(Icons.music_note, color: Colors.white54) : null,
                            ),
                            title: Text(playlist.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text('${playlist.tracks.length} tracks', style: TextStyle(color: Colors.grey.shade500)),
                            trailing: isAdded
                                ? const Icon(Icons.check_circle, color: Colors.blueAccent, size: 26)
                                : const Icon(Icons.circle_outlined, color: Colors.white24, size: 26),
                            onTap: () {
                              if (isAdded) {
                                mp.removeTrackFromPlaylist(playlist.id, track.videoId);
                              } else {
                                mp.addTrackToPlaylist(playlist.id, track);
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Give your playlist a name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'My Playlist',
              hintStyle: TextStyle(color: Colors.grey.shade600),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
            ),
            autofocus: true,
          ),
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                Provider.of<MusicProvider>(context, listen: false).createPlaylist(controller.text);
                Navigator.pop(ctx);
              },
              child: const Text('Create', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
