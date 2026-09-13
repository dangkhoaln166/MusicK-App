import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../screens/player_screen.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({Key? key}) : super(key: key);

  String _cleanTitle(String title) {
    String clean = title;
    if (clean.contains('|')) clean = clean.split('|').first;
    if (clean.contains('//')) clean = clean.split('//').first;
    if (clean.contains('(')) clean = clean.split('(').first;
    if (clean.contains('[')) clean = clean.split('[').first;
    return clean.trim();
  }

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final track = musicProvider.currentTrack;

    if (track == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PlayerScreen()),
        );
      },
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.grey.shade900.withOpacity(0.8),
              border: Border(
                top: BorderSide(color: Colors.grey.shade800, width: 0.5),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // Thumbnail
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    image: DecorationImage(
                      image: track.thumbnail != null
                          ? NetworkImage(track.thumbnail!)
                          : const AssetImage('assets/placeholder.png') as ImageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title and Artist
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _cleanTitle(track.title),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track.channel ?? 'Unknown Artist',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Controls
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    musicProvider.loopMode == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                    color: musicProvider.loopMode == LoopMode.off ? Colors.grey.shade400 : Colors.greenAccent,
                  ),
                  iconSize: 20,
                  onPressed: () => musicProvider.toggleRepeat(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.skip_previous),
                  iconSize: 24,
                  color: Colors.white,
                  onPressed: () => musicProvider.playPrevious(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    musicProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 28,
                  ),
                  color: Colors.white,
                  onPressed: () {
                    musicProvider.togglePlayPause();
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.skip_next),
                  iconSize: 24,
                  color: Colors.white,
                  onPressed: () => musicProvider.playNext(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
