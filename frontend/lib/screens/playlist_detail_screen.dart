import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/playlist.dart';
import '../providers/music_provider.dart';
import '../services/api_service.dart';
import '../utils/custom_toast.dart';
import '../utils/playlist_utils.dart';
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
            backgroundColor: Colors.black,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              centerTitle: true,
              title: Text(playlist.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              background: LayoutBuilder(
                builder: (context, constraints) {
                  final top = constraints.biggest.height;
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
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: playlist.coverImage != null
                                ? Image.network(
                                    playlist.coverImage!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.music_note, size: 80, color: Colors.white),
                                  )
                                : const Icon(Icons.music_note, size: 80, color: Colors.white),
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
                    builder: (ctx) => EditPlaylistDialog(
                      playlist: playlist,
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
          SliverReorderableList(
            itemCount: playlist.tracks.length,
            onReorder: (oldIndex, newIndex) {
              musicProvider.reorderPlaylistTracks(playlist.id, oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
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

                if (index >= playlist.tracks.length) return const SizedBox.shrink();
                final track = playlist.tracks[index];

                return ReorderableDelayedDragStartListener(
                  key: Key(track.videoId),
                  index: index,
                  child: Material(
                    color: Colors.transparent,
                    child: Dismissible(
                      key: Key('dismiss_${track.videoId}'),
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
                      musicProvider.playPlaylist(playlist.tracks, startIndex: index);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PlayerScreen()),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          ),
        ],
      ),
    );
  }
}

class EditPlaylistDialog extends StatefulWidget {
  final Playlist playlist;
  final MusicProvider musicProvider;

  const EditPlaylistDialog({
    Key? key,
    required this.playlist,
    required this.musicProvider,
  }) : super(key: key);

  @override
  State<EditPlaylistDialog> createState() => _EditPlaylistDialogState();
}

class _EditPlaylistDialogState extends State<EditPlaylistDialog> {
  late TextEditingController _nameController;
  late TextEditingController _coverController;
  bool _isUploading = false;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.playlist.name);
    _coverController = TextEditingController(text: widget.playlist.customCoverImage ?? '');
    _isLocked = widget.playlist.customCoverImage != null && widget.playlist.customCoverImage!.isNotEmpty;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _coverController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.image,
      );

      if (files.isNotEmpty) {
        setState(() {
          _isUploading = true;
        });
        
        final file = files.first;
        final bytes = await file.readAsBytes();
        
        final url = await ApiService().uploadImage(bytes, file.name);
        if (url != null) {
            setState(() {
              _coverController.text = url;
            });
            CustomToast.show(context, 'Image uploaded successfully!', color: Colors.greenAccent);
          } else {
            CustomToast.show(context, 'Failed to upload image', color: Colors.redAccent);
          }
      }
    } catch (e) {
      CustomToast.show(context, 'Error picking image', color: Colors.redAccent);
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey.shade900,
      title: const Text('Edit Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview Image
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              clipBehavior: Clip.antiAlias,
              child: _coverController.text.isNotEmpty
                  ? Image.network(_coverController.text, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.error, color: Colors.white54))
                  : const Icon(Icons.image, size: 50, color: Colors.white24),
            ),
            const SizedBox(height: 16),
            
            // Upload Button
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickAndUploadImage,
              icon: _isUploading 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.upload_file),
              label: Text(_isUploading ? 'Uploading...' : 'Upload Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Form Fields
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Playlist Name',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.black12,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.blueAccent)),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _coverController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Cover Image URL (Optional)',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.black12,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.blueAccent)),
              ),
              onChanged: (val) {
                // Trigger rebuild to update image preview
                setState(() {
                  _isLocked = val.isNotEmpty;
                });
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text("Khóa ảnh bìa này", style: TextStyle(color: Colors.white)),
              subtitle: const Text("Không thay đổi bìa khi thêm bài hát mới", style: TextStyle(color: Colors.white54, fontSize: 12)),
              value: _isLocked,
              activeColor: Colors.blueAccent,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() {
                  _isLocked = val;
                  if (_isLocked) {
                    _coverController.text = widget.playlist.coverImage ?? '';
                  } else {
                    _coverController.text = '';
                  }
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: () {
            widget.musicProvider.updatePlaylist(widget.playlist.id, _nameController.text, _coverController.text);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.greenAccent,
            foregroundColor: Colors.black,
          ),
          child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
