import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/home_ui_provider.dart';
import '../utils/custom_toast.dart';
import '../widgets/draggable_editable_text.dart';
import '../widgets/resizable_banner.dart';
import '../services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/hover_scale_card.dart';
import 'player_screen.dart';
import 'playlist_detail_screen.dart';
import 'history_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String? _customHeroImage;

  @override
  void initState() {
    super.initState();
    _loadCustomHeroImage();
  }

  Future<void> _loadCustomHeroImage() async {
    final settings = await ApiService().getSettings();
    setState(() {
      _customHeroImage = settings['customHeroImage'];
      if (_customHeroImage != null && _customHeroImage!.isEmpty) _customHeroImage = null;
    });
  }

  String _getGreeting(SettingsProvider settings) {
    final hour = DateTime.now().hour;
    if (hour < 12) return settings.t('good_morning');
    if (hour < 17) return settings.t('good_afternoon');
    return settings.t('good_evening');
  }

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final homeUi = Provider.of<HomeUiProvider>(context);
    final isDark = settings.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;

    final recentlyPlayed = musicProvider.recentlyPlayed.take(6).toList();
    final String recentlyPlayedTitle = settings.t('recently_played');
    final trendingPlaylists = musicProvider.playlists.take(6).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? null : Colors.white,
        gradient: isDark ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2C1055), // Deep purple
            Color(0xFF0F172A), // Slate dark
            Color(0xFF000000), // Black
          ],
          stops: [0.0, 0.4, 1.0],
        ) : null,
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool isDesktop = constraints.maxWidth > 800;
            return CustomScrollView(
              physics: homeUi.isEditMode ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        DraggableEditableText(
                          config: homeUi.greetingConfig,
                          defaultText: _getGreeting(settings),
                          defaultStyle: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            letterSpacing: -1,
                          ),
                          onSave: (cfg) => homeUi.updateGreeting(cfg),
                          defaultDx: 0,
                          defaultDy: 0,
                          asPositioned: false,
                        ),
                        const Spacer(),
                        if (!homeUi.isEditMode)
                        StreamBuilder(
                          stream: Stream.periodic(const Duration(seconds: 1)),
                          builder: (context, snapshot) {
                            final now = DateTime.now();
                            final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
                            final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 38,
                                    color: textColor,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blueAccent.withOpacity(0.9),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            );
                          }
                        ),
                      ],
                    ),
                  ),
                ),
                // Hero Banner
                SliverToBoxAdapter(
                  child: _buildHeroBanner(isDesktop, musicProvider, settings, homeUi),
                ),
                
                // Recently Played (Grid)
                if (recentlyPlayed.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                      child: Row(
                        children: [
                          Text(
                            recentlyPlayedTitle,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
                            },
                            child: const Text('SEE ALL', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isDesktop ? 3 : (constraints.maxWidth > 600 ? 2 : 2),
                        childAspectRatio: isDesktop ? 4 : (constraints.maxWidth > 600 ? 3.5 : 2.5),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final track = recentlyPlayed[index];
                          return HoverScaleCard(
                            child: Stack(
                              children: [
                                InkWell(
                                  onTap: () {
                                    musicProvider.playTrack(track);
                                    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => const PlayerScreen()));
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05), width: 1),
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                                          child: track.thumbnail != null
                                            ? Image.network(track.thumbnail!, width: 70, height: double.infinity, fit: BoxFit.cover,
                                                errorBuilder: (ctx, err, stack) => Container(width: 70, color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, child: Icon(Icons.music_note, color: isDark ? Colors.white54 : Colors.black54)),
                                              )
                                            : Container(width: 70, color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, child: Icon(Icons.music_note, color: isDark ? Colors.white54 : Colors.black54)),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                track.title,
                                                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                track.channel ?? 'Unknown Artist',
                                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
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
                                        const Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: Icon(Icons.play_circle_fill, color: Colors.blueAccent, size: 32),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    color: Colors.white54,
                                    onPressed: () {
                                      musicProvider.removeFromHistory(track);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: recentlyPlayed.length,
                      ),
                    ),
                  ),
                ],

                // Trending Playlists
                if (trendingPlaylists.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
                      child: Text(
                        settings.t('trending_playlists'),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 240,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: trendingPlaylists.length,
                        itemBuilder: (context, index) {
                          final playlist = trendingPlaylists[index];
                          return HoverScaleCard(
                            child: InkWell(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => PlaylistDetailScreen(playlistId: playlist.id)));
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 160,
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      height: 160,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 4)),
                                        ],
                                        image: DecorationImage(
                                          image: playlist.coverImage != null 
                                            ? NetworkImage(playlist.coverImage!) 
                                            : const AssetImage('assets/placeholder.png') as ImageProvider,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      playlist.name,
                                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${playlist.tracks.length} tracks',
                                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                
                const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding
              ],
            );
          },
        ),
      ),
    );
  }



  Widget _buildHeroBanner(bool isDesktop, MusicProvider mp, SettingsProvider settings, HomeUiProvider homeUi) {
    String? displayImage = _customHeroImage;
    if (displayImage == null || displayImage.isEmpty) {
      if (mp.recentlyPlayed.isNotEmpty && mp.recentlyPlayed.first.thumbnail != null) {
        displayImage = mp.recentlyPlayed.first.thumbnail;
      } else if (mp.playlists.isNotEmpty && mp.playlists.first.coverImage != null) {
        displayImage = mp.playlists.first.coverImage;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: ResizableBanner(
        child: HoverScaleCard(
          child: GestureDetector(
            onPanUpdate: homeUi.isEditMode ? (details) {
              double dx = homeUi.imageOffsetX - (details.delta.dx / 100);
              double dy = homeUi.imageOffsetY - (details.delta.dy / 100);
              if (dx < -2) dx = -2;
              if (dx > 2) dx = 2;
              if (dy < -2) dy = -2;
              if (dy > 2) dy = 2;
              homeUi.updateImageOffset(dx, dy);
            } : null,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Colors.grey.shade900,
                image: DecorationImage(
                  image: displayImage != null && displayImage.isNotEmpty
                      ? NetworkImage(displayImage)
                      : const AssetImage('assets/placeholder.png') as ImageProvider,
                  fit: BoxFit.cover,
                  alignment: Alignment(homeUi.imageOffsetX, homeUi.imageOffsetY),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurpleAccent.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.bottomRight,
                        end: Alignment.topLeft,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Spacer(),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.greenAccent,
                              boxShadow: [
                                BoxShadow(color: Colors.greenAccent.withOpacity(0.3), blurRadius: 8, spreadRadius: 1),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.play_arrow, color: Colors.black, size: 32),
                              onPressed: () {
                                if (mp.recentlyPlayed.isNotEmpty) {
                                  mp.playTrack(mp.recentlyPlayed.first);
                                  Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => const PlayerScreen()));
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  DraggableEditableText(
                    config: homeUi.bannerTitleConfig,
                    defaultText: settings.t('featured'),
                    defaultStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                    onSave: (cfg) => homeUi.updateBannerTitle(cfg),
                    defaultDx: 24,
                    defaultDy: homeUi.bannerHeight - 110,
                  ),
                  DraggableEditableText(
                    config: homeUi.bannerSubtitleConfig,
                    defaultText: settings.t('discover_new_music'),
                    defaultStyle: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -1),
                    onSave: (cfg) => homeUi.updateBannerSubtitle(cfg),
                    defaultDx: 24,
                    defaultDy: homeUi.bannerHeight - 80,
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                child: Row(
                  children: [
                    if (homeUi.isEditMode)
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.greenAccent),
                        onPressed: () => homeUi.toggleEditMode(),
                        tooltip: 'Exit Edit Mode',
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.design_services, color: Colors.white70),
                        onPressed: () => homeUi.toggleEditMode(),
                        tooltip: 'Edit UI',
                      ),
                    IconButton(
                      icon: const Icon(Icons.image, color: Colors.white70),
                      onPressed: () {
                        _showEditBannerDialog(context);
                      },
                      tooltip: 'Change Background Image',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
}

  void _showEditBannerDialog(BuildContext context) {
    final TextEditingController urlController = TextEditingController(text: _customHeroImage ?? '');
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.grey.shade900,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Edit Banner Image', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: urlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Image URL',
                      labelStyle: TextStyle(color: Colors.grey.shade400),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade700),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.blueAccent),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('OR', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isUploading
                          ? null
                          : () async {
                              try {
                                var files = await FilePicker.pickFiles(
                                  type: FileType.image,
                                );
                                if (files.isNotEmpty) {
                                  setStateDialog(() {
                                    isUploading = true;
                                  });
                                  final file = files.first;
                                  final bytes = await file.readAsBytes();
                                  String? uploadedUrl = await ApiService().uploadImage(
                                    bytes,
                                    file.name,
                                  );
                                  setStateDialog(() {
                                    isUploading = false;
                                  });
                                  if (uploadedUrl != null) {
                                    urlController.text = uploadedUrl;
                                  } else {
                                    if (mounted) {
                                      CustomToast.show(context, 'Upload failed', icon: Icons.error, color: Colors.redAccent);
                                    }
                                  }
                                }
                              } catch (e) {
                                setStateDialog(() {
                                  isUploading = false;
                                });
                                if (mounted) {
                                  CustomToast.show(context, 'Upload failed: $e', icon: Icons.error, color: Colors.redAccent);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade800,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: isUploading 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.upload_file, color: Colors.white),
                      label: Text(
                        isUploading ? 'Uploading...' : 'Upload Image',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () async {
                    final newUrl = urlController.text.trim();
                    if (newUrl.isEmpty) {
                      await ApiService().updateSetting('customHeroImage', '');
                    } else {
                      await ApiService().updateSetting('customHeroImage', newUrl);
                    }
                    setState(() {
                      _customHeroImage = newUrl.isEmpty ? null : newUrl;
                    });
                    if (mounted) {
                      Navigator.pop(ctx);
                      CustomToast.show(context, 'Banner updated!', icon: Icons.check, color: Colors.greenAccent);
                    }
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
