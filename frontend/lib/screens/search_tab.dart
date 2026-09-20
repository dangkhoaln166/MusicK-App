import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../providers/music_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/custom_toast.dart';
import 'player_screen.dart';
import 'channel_detail_screen.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({Key? key}) : super(key: key);

  @override
  _SearchTabState createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final TextEditingController _searchController = TextEditingController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  Timer? _debounce;
  bool _isTyping = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      Provider.of<MusicProvider>(context, listen: false).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: \$val'),
        onError: (val) => print('onError: \$val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            setState(() {
              _searchController.text = val.recognizedWords;
            });
            if (val.hasConfidenceRating && val.confidence > 0) {
              // Wait for user to finish speaking
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      if (_searchController.text.isNotEmpty) {
        _performSearch(_searchController.text);
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _isTyping = true;
    });
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.isEmpty) {
      Provider.of<MusicProvider>(context, listen: false).clearSuggestions();
      setState(() => _isTyping = false);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      Provider.of<MusicProvider>(context, listen: false).fetchSuggestions(query);
    });
  }

  void _performSearch(String query) {
    setState(() {
      _isTyping = false;
    });
    if (query.isNotEmpty) {
      FocusScope.of(context).unfocus();
      _searchController.text = query;
      Provider.of<MusicProvider>(context, listen: false).search(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final bgColor = isDark ? Colors.black : Colors.white;
    final searchBgColor = isDark ? Colors.grey.shade900 : Colors.grey.shade100;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('MusicK', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: searchBgColor,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: settings.t('search_placeholder'),
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                      onChanged: _onSearchChanged,
                      onSubmitted: _performSearch,
                    ),
                  ),
                  GestureDetector(
                    onTapDown: (_) => _listen(),
                    onTapUp: (_) => _listen(),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: CircleAvatar(
                        backgroundColor: _isListening ? Colors.redAccent : Colors.blueAccent,
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Results list
          Expanded(
            child: _searchController.text.isEmpty
                ? _buildHistoryView(context, musicProvider, textColor)
                : _isTyping && musicProvider.suggestions.isNotEmpty
                    ? ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: musicProvider.suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = musicProvider.suggestions[index];
                      return ListTile(
                        leading: const Icon(Icons.search, color: Colors.grey),
                        title: Text(suggestion, style: TextStyle(color: textColor)),
                        onTap: () => _performSearch(suggestion),
                      );
                    },
                  )
                : musicProvider.isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        controller: _scrollController,
                        itemCount: musicProvider.searchResults.length + (musicProvider.isLoadingMore ? 1 : 0) + (musicProvider.searchChannels.isNotEmpty ? 1 : 0),
                        itemBuilder: (context, index) {
                          // 1. Show Channels Section first if it exists
                          if (musicProvider.searchChannels.isNotEmpty && index == 0) {
                            return _buildChannelsSection(context, musicProvider.searchChannels, textColor);
                          }
                          
                          // 2. Calculate actual track index
                          final trackIndex = musicProvider.searchChannels.isNotEmpty ? index - 1 : index;
                          
                          // 3. Show Loading Indicator at the end
                          if (trackIndex == musicProvider.searchResults.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
                            );
                          }
                          
                          // 4. Show Track Item
                          final track = musicProvider.searchResults[trackIndex];
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
                              track.channel ?? '',
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    musicProvider.isFavorite(track) ? Icons.favorite : Icons.favorite_border,
                                    color: musicProvider.isFavorite(track) ? Colors.greenAccent : Colors.blueAccent,
                                  ),
                                  onPressed: () {
                                    musicProvider.toggleFavorite(track);
                                    CustomToast.show(
                                      context,
                                      musicProvider.isFavorite(track) ? settings.t('added_to_liked') : settings.t('removed_from_liked'),
                                      icon: musicProvider.isFavorite(track) ? Icons.favorite : Icons.favorite_border,
                                      color: musicProvider.isFavorite(track) ? Colors.greenAccent : (isDark ? Colors.white54 : Colors.black54),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.playlist_play, color: Colors.blueAccent),
                                  onPressed: () {
                                    musicProvider.addToQueue(track);
                                    CustomToast.show(
                                      context,
                                      'Added "${track.title}" to Queue!',
                                      icon: Icons.playlist_add_check,
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                                  onPressed: () => _showAddToPlaylistSheet(context, track),
                                ),
                              ],
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

  Widget _buildHistoryView(BuildContext context, MusicProvider provider, Color textColor) {
    if (provider.searchHistory.isEmpty && provider.channelHistory.isEmpty) {
      return Center(
        child: Text("Tìm kiếm bài hát, nghệ sĩ hoặc kênh...", style: TextStyle(color: Colors.grey.shade600)),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        if (provider.channelHistory.isNotEmpty)
          _buildChannelsSection(context, provider.channelHistory, textColor, title: "Kênh đã xem", isHistory: true),
        if (provider.searchHistory.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 8.0, top: 16.0, bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Lịch sử tìm kiếm", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                  onPressed: () => _showClearConfirmation(context, "Xóa lịch sử tìm kiếm?", () {
                    for (var query in List.from(provider.searchHistory)) {
                      provider.removeSearchHistory(query);
                    }
                  }),
                ),
              ],
            ),
          ),
        ...provider.searchHistory.map((query) => ListTile(
          leading: const Icon(Icons.history, color: Colors.grey),
          title: Text(query, style: TextStyle(color: textColor)),
          trailing: IconButton(
            icon: const Icon(Icons.close, color: Colors.grey, size: 20),
            onPressed: () => provider.removeSearchHistory(query),
          ),
          onTap: () {
            _searchController.text = query;
            _performSearch(query);
          },
        )).toList(),
      ],
    );
  }
  
  void _showClearConfirmation(BuildContext context, String title, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18)),
        content: const Text("Hành động này không thể hoàn tác.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: const Text("Xóa", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelsSection(BuildContext context, List channels, Color textColor, {String title = "Kênh", bool isHistory = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 8.0, top: 16.0, bottom: 8.0),
          child: Text(title, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            itemCount: channels.length,
            itemBuilder: (context, index) {
              final channel = channels[index];
              return GestureDetector(
                onTap: () {
                  Provider.of<MusicProvider>(context, listen: false).addToChannelHistory(channel);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ChannelDetailScreen(channel: channel)));
                },
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 12.0),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.all(4.0),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundImage: channel.avatar != null ? NetworkImage(channel.avatar!) : null,
                              backgroundColor: Colors.grey.shade800,
                              child: channel.avatar == null ? const Icon(Icons.person, color: Colors.white54, size: 40) : null,
                            ),
                          ),
                          if (isHistory)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => _showClearConfirmation(context, "Xóa kênh này khỏi lịch sử?", () {
                                  Provider.of<MusicProvider>(context, listen: false).removeChannelHistory(channel.id);
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24, width: 1),
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        channel.title,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddToPlaylistSheet(BuildContext context, track) {
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
                      Text('Add to Playlist', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.black54),
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
                                color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                              ),
                              child: playlist.coverImage == null ? const Icon(Icons.music_note, color: Colors.grey) : null,
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
