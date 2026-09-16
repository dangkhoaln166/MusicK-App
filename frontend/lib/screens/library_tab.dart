import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../providers/settings_provider.dart';
import '../models/playlist.dart';
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
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final bgColor = isDark ? Colors.black : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? null : bgColor,
        gradient: isDark ? const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E1E1E),
            Colors.black,
          ],
        ) : null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    settings.t('your_library'),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.search, color: textColor),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: Icon(Icons.add, color: textColor, size: 28),
                        onPressed: () => _showCreatePlaylistDialog(context),
                      ),
                    ],
                  )
                ],
              ),
            ),
            Expanded(
              child: _buildPlaylists(context, settings),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylists(BuildContext context, SettingsProvider settings) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final likedCount = musicProvider.favorites.length;
    final isDark = settings.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;

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
          title: Text(settings.t('liked_songs'), style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              children: [
                const Icon(Icons.push_pin, color: Colors.blueAccent, size: 14),
                const SizedBox(width: 4),
                Text('$likedCount ${settings.t('songs')}', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, fontSize: 14)),
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
                  ? Image.network(
                      playlist.coverImage!, 
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.album, color: Colors.white54, size: 50),
                      ),
                    )
                  : Container(color: Colors.grey.shade800, child: const Icon(Icons.music_note, color: Colors.white54, size: 50)),
            ),
            title: Text(playlist.name, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text('${settings.t('playlist')} • ${playlist.tracks.length} ${settings.t('tracks')}', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, fontSize: 14)),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PlaylistDetailScreen(playlistId: playlist.id)),
              );
            },
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: isDark ? Colors.white54 : Colors.black54),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => EditPlaylistDialog(
                        playlistId: playlist.id,
                        currentName: playlist.name,
                        currentCoverUrl: playlist.customCoverImage,
                        musicProvider: musicProvider,
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
                        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
                        title: Text('Delete Playlist?', style: TextStyle(color: textColor)),
                        content: Text('Are you sure you want to delete this playlist?', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                          ),
                          TextButton(
                            onPressed: () {
                              musicProvider.deletePlaylist(playlist.id);
                              Navigator.pop(ctx);
                            },
                            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 100), // padding for mini player
      ],
    );
  }


  void _showCreatePlaylistDialog(BuildContext context) {
    _playlistNameController.clear();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final isDark = settings.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Give your playlist a name', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: _playlistNameController,
            style: TextStyle(color: textColor, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'My Playlist #6',
              hintStyle: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
            ),
            autofocus: true,
          ),
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 16)),
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
