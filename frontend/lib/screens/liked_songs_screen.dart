import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../widgets/mini_player.dart';
import '../utils/custom_toast.dart';
import '../utils/playlist_utils.dart';
import 'player_screen.dart';
import 'package:file_picker/file_picker.dart';

class LikedSongsScreen extends StatelessWidget {
  const LikedSongsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final favorites = musicProvider.favorites;

    return Scaffold(
      backgroundColor: Colors.black,
      bottomNavigationBar: musicProvider.currentTrack != null ? const MiniPlayer() : null,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            centerTitle: true,
            backgroundColor: Colors.black,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              centerTitle: true,
              title: const Text('Liked Songs', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              background: LayoutBuilder(
                builder: (context, constraints) {
                  final top = constraints.biggest.height;
                  // Fade out the image as it collapses. Fully visible at 300, invisible at 200.
                  final opacity = ((top - 200) / 100).clamp(0.0, 1.0);
                  
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.indigo.shade800, Colors.black],
                      ),
                    ),
                    child: Opacity(
                      opacity: opacity,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 30, offset: const Offset(0, 15))
                              ],
                              gradient: musicProvider.likedSongsCover == null
                                  ? const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Colors.blueAccent, Colors.purpleAccent],
                                    )
                                  : null,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: musicProvider.likedSongsCover != null
                                ? Image.network(
                                    musicProvider.likedSongsCover!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.favorite, size: 80, color: Colors.white),
                                  )
                                : const Icon(Icons.favorite, size: 80, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => EditLikedSongsDialog(musicProvider: musicProvider),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: Colors.grey.shade900,
                      title: const Text('Clear Liked Songs?', style: TextStyle(color: Colors.white)),
                      content: const Text('Are you sure you want to remove all your liked songs? This cannot be undone.', style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                        ),
                        TextButton(
                          onPressed: () {
                            musicProvider.clearFavorites();
                            Navigator.pop(ctx);
                          },
                          child: const Text('Clear All', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                },
              )
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Text(
                    '${favorites.length} bài hát',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  ),
                  const Spacer(),
                  if (favorites.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () {
                        final randomIndex = (DateTime.now().millisecondsSinceEpoch % favorites.length).toInt();
                        musicProvider.playPlaylist(favorites, startIndex: randomIndex);
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(builder: (context) => const PlayerScreen()),
                        );
                      },
                      icon: const Icon(Icons.shuffle, size: 18),
                      label: const Text('Trộn'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  const SizedBox(width: 12),
                  if (favorites.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () {
                        musicProvider.playPlaylist(favorites);
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(builder: (context) => const PlayerScreen()),
                        );
                      },
                      icon: const Icon(Icons.play_arrow, size: 20),
                      label: const Text('Phát tất cả'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverReorderableList(
            itemCount: favorites.length,
            onReorder: (oldIndex, newIndex) {
              musicProvider.reorderFavorites(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              if (favorites.isEmpty) {
                return SizedBox(
                  key: const ValueKey('empty_state'),
                  height: 300,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.favorite_border, size: 64, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text("You haven't liked any songs yet.", style: TextStyle(color: Colors.white54, fontSize: 18)),
                    ],
                  ),
                );
              }

              if (index >= favorites.length) return const SizedBox.shrink();
              final track = favorites[index];

              return ReorderableDelayedDragStartListener(
                key: Key(track.videoId),
                index: index,
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: track.thumbnail != null
                          ? Image.network(
                              track.thumbnail!, 
                              width: 50, 
                              height: 50, 
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 50,
                                height: 50,
                                color: Colors.grey.shade800,
                                child: const Icon(Icons.music_note, color: Colors.white54),
                              ),
                            )
                          : Container(width: 50, height: 50, color: Colors.grey.shade800),
                    ),
                    title: Text(
                      track.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      track.channel ?? 'Unknown Artist',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.white54),
                          onPressed: () => PlaylistUtils.showAddToPlaylistDialog(context, track),
                        ),
                        Consumer<MusicProvider>(
                          builder: (context, mp, _) {
                            final isFav = mp.isFavorite(track);
                            return IconButton(
                              icon: Icon(
                                isFav ? Icons.favorite : Icons.favorite_border,
                                color: isFav ? Colors.greenAccent : Colors.white54,
                              ),
                              onPressed: () {
                                mp.toggleFavorite(track);
                                CustomToast.show(
                                  context,
                                  isFav ? 'Removed from Liked Songs' : 'Added to Liked Songs',
                                  icon: isFav ? Icons.favorite_border : Icons.favorite,
                                  color: isFav ? Colors.white54 : Colors.greenAccent,
                                );
                              },
                            );
                          },
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.only(left: 8.0, right: 8.0),
                            child: Icon(Icons.drag_handle, color: Colors.white54),
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      musicProvider.playPlaylist(favorites, startIndex: index);
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (context) => const PlayerScreen()),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }
}

class EditLikedSongsDialog extends StatefulWidget {
  final MusicProvider musicProvider;

  const EditLikedSongsDialog({Key? key, required this.musicProvider}) : super(key: key);

  @override
  State<EditLikedSongsDialog> createState() => _EditLikedSongsDialogState();
}

class _EditLikedSongsDialogState extends State<EditLikedSongsDialog> {
  String? _imageUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.musicProvider.likedSongsCover;
  }



  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF282828),
      title: const Text('Edit Liked Songs', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: 'Cover Image URL (Optional)',
              labelStyle: const TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade700)),
              focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (val) {
              setState(() {
                _imageUrl = val;
              });
            },
            controller: TextEditingController(text: _imageUrl)..selection = TextSelection.fromPosition(TextPosition(offset: _imageUrl?.length ?? 0)),
          ),
          const SizedBox(height: 16),
          if (_imageUrl != null && _imageUrl!.isNotEmpty)
            Image.network(_imageUrl!, height: 100, errorBuilder: (c,e,s) => const Text('Invalid URL', style: TextStyle(color: Colors.red)))
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: () {
            widget.musicProvider.updateLikedSongsCover(_imageUrl);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
