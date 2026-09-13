import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../providers/music_provider.dart';
import '../widgets/mini_player.dart';
import 'player_screen.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final String playlistId;

  const PlaylistDetailScreen({Key? key, required this.playlistId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    // Find the playlist dynamically to ensure UI updates when tracks change
    final Playlist? playlist = musicProvider.playlists.cast<Playlist?>().firstWhere(
      (p) => p?.id == playlistId,
      orElse: () => null,
    );

    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Playlist Not Found')),
        body: const Center(child: Text('This playlist no longer exists.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      bottomNavigationBar: musicProvider.currentTrack != null ? const MiniPlayer() : null,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            centerTitle: true,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(playlist.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.purple.shade800, Colors.black],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40.0),
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 30, offset: const Offset(0, 15))
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: playlist.coverImage != null
                          ? Image.network(playlist.coverImage!, fit: BoxFit.cover)
                          : Container(color: Colors.grey.shade800, child: const Icon(Icons.music_note, size: 80, color: Colors.white54)),
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () {
                  final TextEditingController controller = TextEditingController(text: playlist.name);
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: Colors.grey.shade900,
                      title: const Text('Rename Playlist', style: TextStyle(color: Colors.white)),
                      content: TextField(
                        controller: controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'New Playlist Name',
                          hintStyle: TextStyle(color: Colors.white24),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                        ),
                        autofocus: true,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                        ),
                        TextButton(
                          onPressed: () {
                            musicProvider.renamePlaylist(playlist.id, controller.text);
                            Navigator.pop(ctx);
                          },
                          child: const Text('Save', style: TextStyle(color: Colors.blueAccent)),
                        ),
                      ],
                    ),
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
                      title: const Text('Delete Playlist?', style: TextStyle(color: Colors.white)),
                      content: const Text('Are you sure you want to delete this playlist?', style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                        ),
                        TextButton(
                          onPressed: () {
                            musicProvider.deletePlaylist(playlist.id);
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                          },
                          child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
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
                  // Track count info
                  Text(
                    '${playlist.tracks.length} bài hát',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  ),
                  const Spacer(),
                  // Shuffle button
                  if (playlist.tracks.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () {
                        final tracks = playlist.tracks;
                        final randomIndex = (DateTime.now().millisecondsSinceEpoch % tracks.length).toInt();
                        musicProvider.playPlaylist(tracks, startIndex: randomIndex);
                        Navigator.push(
                          context,
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
                  // Play All button
                  if (playlist.tracks.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () {
                        musicProvider.playPlaylist(playlist.tracks);
                        Navigator.push(
                          context,
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
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (playlist.tracks.isEmpty) {
                  return SizedBox(
                    height: 300,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.library_music, size: 64, color: Colors.white24),
                        const SizedBox(height: 16),
                        const Text("No tracks added yet.", style: TextStyle(color: Colors.white54, fontSize: 18)),
                        const SizedBox(height: 8),
                        const Text("Search for a song and add it here!", style: TextStyle(color: Colors.white30, fontSize: 14)),
                      ],
                    ),
                  );
                }

                if (index >= playlist.tracks.length) return null;
                final track = playlist.tracks[index];

                return Dismissible(
                  key: Key(track.videoId),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.redAccent,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    musicProvider.removeTrackFromPlaylist(playlist.id, track.videoId);
                  },
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: track.thumbnail != null
                          ? Image.network(track.thumbnail!, width: 50, height: 50, fit: BoxFit.cover)
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
                    trailing: const Icon(Icons.play_arrow, color: Colors.white54),
                    onTap: () {
                      if (musicProvider.currentTrack?.videoId != track.videoId) {
                        musicProvider.playPlaylist(playlist.tracks, startIndex: index);
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PlayerScreen()),
                      );
                    },
                  ),
                );
              },
              childCount: playlist.tracks.isEmpty ? 1 : playlist.tracks.length,
            ),
          ),
        ],
      ),
    );
  }
}
