import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import 'liked_songs_screen.dart';
import 'playlist_detail_screen.dart';

class LibraryTab extends StatefulWidget {
  const LibraryTab({Key? key}) : super(key: key);

  @override
  _LibraryTabState createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  final TextEditingController _playlistNameController = TextEditingController();

  @override
  void dispose() {
    _playlistNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E1E1E),
            Colors.black,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Library',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white, size: 28),
                        onPressed: () => _showCreatePlaylistDialog(context),
                      ),
                    ],
                  )
                ],
              ),
            ),
            Expanded(
              child: _buildPlaylists(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylists(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final likedCount = musicProvider.favorites.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          leading: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.purpleAccent, Colors.blueAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: const Icon(Icons.favorite, color: Colors.white, size: 30),
          ),
          title: const Text('Liked Songs', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              children: [
                Icon(Icons.push_pin, color: Colors.blueAccent, size: 14),
                const SizedBox(width: 4),
                Text('$likedCount songs', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
              ],
            ),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LikedSongsScreen()),
            );
          },
        ),
        const SizedBox(height: 8),
        ...musicProvider.playlists.map((playlist) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            leading: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: playlist.coverImage != null
                  ? Image.network(playlist.coverImage!, fit: BoxFit.cover)
                  : Container(color: Colors.grey.shade800, child: const Icon(Icons.music_note, color: Colors.white54)),
            ),
            title: Text(playlist.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text('Playlist • ${playlist.tracks.length} tracks', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PlaylistDetailScreen(playlistId: playlist.id)),
              );
            },
          );
        }).toList(),
        const SizedBox(height: 100), // padding for mini player
      ],
    );
  }


  void _showCreatePlaylistDialog(BuildContext context) {
    _playlistNameController.clear();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Give your playlist a name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: _playlistNameController,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'My Playlist #6',
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
                Provider.of<MusicProvider>(context, listen: false).createPlaylist(_playlistNameController.text);
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
