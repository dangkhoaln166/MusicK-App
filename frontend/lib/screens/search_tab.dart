import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../providers/music_provider.dart';
import '../utils/custom_toast.dart';
import 'player_screen.dart';

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

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('MusicK', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search songs, artists, or links...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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
            child: _isTyping && musicProvider.suggestions.isNotEmpty
                ? ListView.builder(
                    itemCount: musicProvider.suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = musicProvider.suggestions[index];
                      return ListTile(
                        leading: const Icon(Icons.search, color: Colors.grey),
                        title: Text(suggestion, style: const TextStyle(color: Colors.white)),
                        onTap: () => _performSearch(suggestion),
                      );
                    },
                  )
                : musicProvider.isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: musicProvider.searchResults.length + (musicProvider.isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == musicProvider.searchResults.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
                            );
                          }
                          final track = musicProvider.searchResults[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: track.thumbnail != null
                                  ? Image.network(track.thumbnail!, width: 60, height: 60, fit: BoxFit.cover)
                                  : Container(width: 60, height: 60, color: Colors.grey.shade800),
                            ),
                            title: Text(
                              track.title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                              Navigator.push(
                                context,
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

  void _showAddToPlaylistSheet(BuildContext context, track) {
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
