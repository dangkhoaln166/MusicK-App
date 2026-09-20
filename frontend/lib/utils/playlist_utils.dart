import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/music_provider.dart';
import '../providers/settings_provider.dart';
import 'custom_toast.dart';

class PlaylistUtils {
  static void showAddToPlaylistDialog(BuildContext context, Track track) {
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
                            onPressed: () => showCreatePlaylistDialog(context),
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
                              const Text("Bấm vào biểu tượng dấu + ở trên để tạo playlist đầu tiên của bạn!", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 14)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: mp.playlists.length,
                        itemBuilder: (context, index) {
                          final playlist = mp.playlists[index];
                          final isAlreadyAdded = playlist.tracks.any((t) => t.videoId == track.videoId);
                          
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                image: playlist.coverImage != null
                                    ? DecorationImage(
                                        image: NetworkImage(playlist.coverImage!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: playlist.coverImage == null
                                  ? Icon(Icons.music_note, color: isDark ? Colors.white54 : Colors.black54)
                                  : null,
                            ),
                            title: Text(
                              playlist.name,
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${playlist.tracks.length} bài hát',
                              style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                            ),
                            trailing: isAlreadyAdded
                                ? Icon(Icons.check_circle, color: Colors.greenAccent)
                                : Icon(Icons.add_circle_outline, color: isDark ? Colors.white54 : Colors.black54),
                            onTap: () {
                              if (isAlreadyAdded) {
                                mp.removeTrackFromPlaylist(playlist.id, track.videoId);
                                CustomToast.show(context, 'Đã bỏ khỏi ${playlist.name}', icon: Icons.remove_circle_outline, color: Colors.orangeAccent);
                              } else {
                                mp.addTrackToPlaylist(playlist.id, track);
                                CustomToast.show(context, 'Đã thêm vào ${playlist.name}', icon: Icons.check_circle, color: Colors.greenAccent);
                                Navigator.pop(context); // Optional: close after adding
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

  static void showCreatePlaylistDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final isDark = settings.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Tạo Playlist mới', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: textColor, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Tên Playlist...',
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
              child: Text('Hủy', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Provider.of<MusicProvider>(context, listen: false).createPlaylist(controller.text);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Tạo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
