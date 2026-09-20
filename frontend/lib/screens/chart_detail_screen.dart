import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../providers/settings_provider.dart';
import '../models/track.dart';
import '../utils/custom_toast.dart';
import 'player_screen.dart';
import '../utils/playlist_utils.dart';

class ChartDetailScreen extends StatelessWidget {
  final String title;
  final List<Track> tracks;

  const ChartDetailScreen({
    Key? key,
    required this.title,
    required this.tracks,
  }) : super(key: key);

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);

    final firstThumb = tracks.isNotEmpty ? tracks.first.thumbnail : null;

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: bgColor,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 48, bottom: 16),
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (firstThumb != null)
                    Image.network(
                      firstThumb,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(color: Colors.blueGrey),
                  
                  // Blur effect
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.1),
                            Colors.black.withOpacity(0.4),
                            bgColor,
                          ],
                          stops: const [0.0, 0.7, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = tracks[index];
                  return _ChartListItem(
                    track: track,
                    index: index,
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                    durationStr: _formatDuration(track.duration ?? 0),
                  );
                },
                childCount: tracks.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        onPressed: () {
          if (tracks.isNotEmpty) {
            final mp = Provider.of<MusicProvider>(context, listen: false);
            mp.playPlaylist(tracks);
            Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => const PlayerScreen()));
          }
        },
        child: const Icon(Icons.play_arrow, size: 32, color: Colors.white),
      ),
    );
  }
}

class _ChartListItem extends StatefulWidget {
  final Track track;
  final int index;
  final Color textColor;
  final Color subtitleColor;
  final String durationStr;

  const _ChartListItem({
    Key? key,
    required this.track,
    required this.index,
    required this.textColor,
    required this.subtitleColor,
    required this.durationStr,
  }) : super(key: key);

  @override
  __ChartListItemState createState() => __ChartListItemState();
}

class __ChartListItemState extends State<_ChartListItem> {
  bool _isHovered = false;

  Color _getRankColor(int index) {
    if (index == 0) return const Color(0xFFFFD700); // Gold
    if (index == 1) return const Color(0xFFC0C0C0); // Silver
    if (index == 2) return const Color(0xFFCD7F32); // Bronze
    return widget.textColor.withOpacity(0.5);
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final isTop3 = widget.index < 3;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          final mp = Provider.of<MusicProvider>(context, listen: false);
          mp.playTrack(track);
          Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => const PlayerScreen()));
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: _isHovered ? widget.textColor.withOpacity(0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    '${widget.index + 1}',
                    style: TextStyle(
                      color: _getRankColor(widget.index),
                      fontSize: isTop3 ? 24 : 18,
                      fontWeight: isTop3 ? FontWeight.bold : FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      if (track.thumbnail != null)
                        Image.network(
                          track.thumbnail!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        )
                      else
                        Container(
                          width: 56,
                          height: 56,
                          color: Colors.grey.withOpacity(0.2),
                          child: Icon(Icons.music_note, color: widget.subtitleColor),
                        ),
                      if (_isHovered)
                        Container(
                          width: 56,
                          height: 56,
                          color: Colors.black45,
                          child: const Icon(Icons.play_arrow, color: Colors.white),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: TextStyle(
                          color: widget.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track.channel ?? 'Unknown Channel',
                        style: TextStyle(
                          color: widget.subtitleColor,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (widget.durationStr.isNotEmpty)
                  Text(
                    widget.durationStr,
                    style: TextStyle(
                      color: widget.subtitleColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(width: 8),
                Consumer<MusicProvider>(
                  builder: (context, mp, _) {
                    final isFav = mp.isFavorite(track);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav ? Colors.blueAccent : Colors.blueAccent,
                          ),
                          onPressed: () {
                            mp.toggleFavorite(track);
                            CustomToast.show(
                              context,
                              mp.isFavorite(track) ? 'Đã thêm vào Yêu thích' : 'Đã bỏ Yêu thích',
                              icon: mp.isFavorite(track) ? Icons.favorite : Icons.favorite_border,
                              color: mp.isFavorite(track) ? Colors.redAccent : Colors.white,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.playlist_add, color: Colors.blueAccent),
                          onPressed: () {
                            mp.addToQueue(track);
                            CustomToast.show(
                              context,
                              'Đã thêm "${track.title}" vào hàng đợi!',
                              icon: Icons.queue_music,
                              color: Colors.blueAccent,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                          onPressed: () => _showAddToPlaylistSheet(context, track),
                        ),
                      ],
                    );
                  }
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddToPlaylistSheet(BuildContext context, Track track) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final isDark = settings.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: bgColor,
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
                      Text('Thêm vào Playlist', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                            tooltip: 'Tạo Playlist mới',
                            onPressed: () => PlaylistUtils.showCreatePlaylistDialog(context),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.black54),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
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
                              const SizedBox(height: 16),
                              const Text("Chưa có Playlist nào", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              const Text("Hãy vào tab Thư viện để tạo playlist đầu tiên của bạn!", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 14)),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: mp.playlists.length,
                        itemBuilder: (context, index) {
                          final pl = mp.playlists[index];
                          final bool hasTrack = pl.tracks.any((t) => t.videoId == track.videoId);
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: pl.tracks.isNotEmpty && pl.tracks.first.thumbnail != null
                                  ? Image.network(
                                      pl.tracks.first.thumbnail!,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 48,
                                        height: 48,
                                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                        child: const Icon(Icons.music_note, color: Colors.grey),
                                      ),
                                    )
                                  : Container(
                                      width: 48,
                                      height: 48,
                                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                      child: const Icon(Icons.music_note, color: Colors.grey),
                                    ),
                            ),
                            title: Text(pl.name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                            subtitle: Text('${pl.tracks.length} bài hát', style: const TextStyle(color: Colors.grey)),
                            trailing: hasTrack 
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : const Icon(Icons.add_circle_outline, color: Colors.grey),
                            onTap: () {
                              if (!hasTrack) {
                                mp.addTrackToPlaylist(pl.id, track);
                                Navigator.pop(context);
                                CustomToast.show(
                                  context,
                                  'Đã thêm vào "${pl.name}"',
                                  icon: Icons.playlist_add_check,
                                  color: Colors.greenAccent,
                                );
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
