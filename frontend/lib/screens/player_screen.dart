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

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({Key? key}) : super(key: key);

  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Track? _cachedTrack;
  Future<Map<String, dynamic>?>? _lyricsFuture;

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
      final cleanTitle = track.title.split(RegExp(r'[\(\[|]'))[0].trim();
      _lyricsFuture = ApiService().getLyrics(cleanTitle);
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
          child: Center(child: _buildAlbumArt(track.thumbnail, imageSize)),
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
        _buildAlbumArt(track.thumbnail, imageSize),
        const SizedBox(height: 20),
        Expanded(child: _buildLyricsView(track)),
      ],
    );
  }

  Widget _buildLyricsView(Track track) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _lyricsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white24));
        }

        final data = snapshot.data;
        if (data == null || (data['syncedLyrics'] == null && data['plainLyrics'] == null)) {
          return const Center(child: Text("Lyrics not available", style: TextStyle(color: Colors.white54, fontSize: 18)));
        }

        if (data['syncedLyrics'] != null) {
          final lines = LyricLine.parseLrc(data['syncedLyrics']);
          if (lines.isNotEmpty) {
            return SyncedLyricsWidget(lyrics: lines);
          }
        }

        // Fallback to plain lyrics
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
          child: Text(
            data['plainLyrics'] ?? '',
            style: const TextStyle(fontSize: 20, height: 2.0, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  Widget _buildAlbumArt(String? thumbnailUrl, double size) {
    return Container(
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
      child: RepaintBoundary(
        child: RotationTransition(
          turns: _animationController,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black54, width: 8),
              image: DecorationImage(
                image: thumbnailUrl != null
                  ? NetworkImage(thumbnailUrl)
                  : const AssetImage('assets/placeholder.png') as ImageProvider,
                fit: BoxFit.cover,
              ),
            ),
            child: Center(
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
            child: Image.network(track.thumbnail!, width: 56, height: 56, fit: BoxFit.cover),
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
    return Consumer<MusicProvider>(
      builder: (context, musicProvider, _) {
        return Row(
          children: [
            Text(_formatDuration(musicProvider.position), style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
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
                  value: musicProvider.position.inSeconds.toDouble().clamp(0, musicProvider.duration.inSeconds.toDouble()),
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
                icon: Icon(musicProvider.isPlaying ? Icons.pause : Icons.play_arrow, size: 36, color: Colors.black),
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
                            children: const [
                              Icon(Icons.library_music_outlined, size: 60, color: Colors.white24),
                              SizedBox(height: 16),
                              Text("No Playlists Found", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              SizedBox(height: 8),
                              Text("Go to the Library tab to create your first playlist!", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 14)),
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
}
