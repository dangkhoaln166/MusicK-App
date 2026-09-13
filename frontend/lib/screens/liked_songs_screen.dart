import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../widgets/mini_player.dart';
import 'player_screen.dart';

class LikedSongsScreen extends StatelessWidget {
  const LikedSongsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final favorites = musicProvider.favorites;

    return Scaffold(
      backgroundColor: Colors.black,
      bottomNavigationBar: musicProvider.currentTrack != null ? const MiniPlayer() : null,
      appBar: AppBar(
        title: const Text('Liked Songs', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple.shade900.withOpacity(0.6),
              Colors.black,
            ],
          ),
        ),
        child: favorites.isEmpty
            ? const Center(
                child: Text(
                  "You haven't liked any songs yet.",
                  style: TextStyle(color: Colors.white54, fontSize: 18),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final track = favorites[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: track.thumbnail != null
                          ? Image.network(track.thumbnail!, width: 60, height: 60, fit: BoxFit.cover)
                          : Container(width: 60, height: 60, color: Colors.grey.shade800),
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
                          icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                          onPressed: () {
                            musicProvider.toggleFavorite(track);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.play_arrow, color: Colors.white),
                          onPressed: () {
                            if (musicProvider.currentTrack?.videoId != track.videoId) {
                              musicProvider.playTrack(track);
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const PlayerScreen()),
                            );
                          },
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
    );
  }
}
