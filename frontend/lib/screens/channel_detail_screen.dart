import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/channel.dart';
import '../models/track.dart';
import '../providers/settings_provider.dart';
import '../providers/music_provider.dart';
import '../services/api_service.dart';
import '../utils/custom_toast.dart';
import 'player_screen.dart';
import '../utils/playlist_utils.dart';

class ChannelDetailScreen extends StatefulWidget {
  final Channel channel;

  const ChannelDetailScreen({Key? key, required this.channel}) : super(key: key);

  @override
  _ChannelDetailScreenState createState() => _ChannelDetailScreenState();
}

class _ChannelDetailScreenState extends State<ChannelDetailScreen> {
  final ApiService _apiService = ApiService();
  List<Track> _tracks = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _sortBy = 'p'; // 'p' for Popular, 'dd' for Newest
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchVideos();
    _scrollController.addListener(_onScroll);
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoading && !_isLoadingMore) {
      _loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchVideos() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
    });
    try {
      final tracks = await _apiService.getChannelVideos(widget.channel.id, sortBy: _sortBy, page: _currentPage);
      setState(() {
        _tracks = tracks;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching channel videos: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      _currentPage++;
      final tracks = await _apiService.getChannelVideos(widget.channel.id, sortBy: _sortBy, page: _currentPage);
      setState(() {
        _tracks.addAll(tracks);
        _isLoadingMore = false;
      });
    } catch (e) {
      print("Error fetching more channel videos: $e");
      setState(() {
        _isLoadingMore = false;
        _currentPage--;
      });
    }
  }

  void _onSortChanged(String? newValue) {
    if (newValue != null && newValue != _sortBy) {
      setState(() {
        _sortBy = newValue;
      });
      _fetchVideos();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final musicProvider = Provider.of<MusicProvider>(context);
    final isDark = settings.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final bgColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(widget.channel.title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Column(
        children: [
          // Channel Info
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: widget.channel.avatar != null ? NetworkImage(widget.channel.avatar!) : null,
                  backgroundColor: Colors.grey.shade800,
                  child: widget.channel.avatar == null ? const Icon(Icons.person, size: 50, color: Colors.white54) : null,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.channel.title,
                        style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.channel.subscribers ?? 'Subscriber count unavailable',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Filter Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Sắp xếp theo: ', style: TextStyle(color: textColor, fontSize: 16)),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _sortBy,
                  dropdownColor: isDark ? Colors.grey.shade900 : Colors.white,
                  style: TextStyle(color: textColor, fontSize: 16),
                  underline: Container(height: 1, color: Colors.deepPurpleAccent),
                  onChanged: _onSortChanged,
                  items: const [
                    DropdownMenuItem(value: 'p', child: Text('Phổ biến nhất (Lượt nghe)')),
                    DropdownMenuItem(value: 'dd', child: Text('Mới nhất')),
                  ],
                ),
              ],
            ),
          ),
          
          const Divider(),
          
          // Video List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
                : _tracks.isEmpty
                    ? Center(child: Text("Không có video nào.", style: TextStyle(color: textColor)))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        controller: _scrollController,
                        itemCount: _tracks.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _tracks.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent)),
                            );
                          }
                          final track = _tracks[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: track.thumbnail != null
                                  ? Image.network(
                                      track.thumbnail!,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.grey.shade800,
                                        child: const Icon(Icons.music_note, color: Colors.white54),
                                      ),
                                    )
                                  : Container(width: 60, height: 60, color: Colors.grey.shade800),
                            ),
                            title: Text(
                              track.title,
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              track.duration != null && track.duration! > 0 ? 'Thời lượng: ${track.duration! ~/ 60}:${(track.duration! % 60).toString().padLeft(2, '0')}' : '',
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                            trailing: Consumer<MusicProvider>(
                              builder: (context, mp, _) {
                                final isFav = mp.isFavorite(track);
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        isFav ? Icons.favorite : Icons.favorite_border,
                                        color: Colors.blueAccent,
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
                            onTap: () {
                              if (musicProvider.currentTrack?.videoId != track.videoId) {
                                musicProvider.playTrack(track);
                              }
                              Navigator.of(context, rootNavigator: true).push(
                                MaterialPageRoute(builder: (context) => const PlayerScreen()),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
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
