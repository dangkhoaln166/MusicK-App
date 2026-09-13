import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import 'player_screen.dart';
import 'playlist_detail_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final quickPicks = musicProvider.favorites.take(6).toList();
    final trendingPlaylists = musicProvider.playlists.take(6).toList();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2C1055), // Deep purple
            const Color(0xFF0F172A), // Slate dark
            const Color(0xFF000000), // Black
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool isDesktop = constraints.maxWidth > 800;
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _getGreeting(),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                        const Spacer(),
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
                                  style: const TextStyle(
                                    fontSize: 38,
                                    color: Colors.white,
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
                  child: _buildHeroBanner(isDesktop),
                ),
                
                // Quick Picks (Grid)
                if (quickPicks.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                      child: Row(
                        children: [
                          const Text(
                            'Quick Picks',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {},
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
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final track = quickPicks[index];
                          return HoverScaleCard(
                            child: InkWell(
                              onTap: () {
                                musicProvider.playTrack(track);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerScreen()));
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                                      child: track.thumbnail != null
                                        ? Image.network(track.thumbnail!, width: 70, height: double.infinity, fit: BoxFit.cover,
                                            errorBuilder: (ctx, err, stack) => Container(width: 70, color: Colors.grey.shade800, child: const Icon(Icons.music_note, color: Colors.white54)),
                                          )
                                        : Container(width: 70, color: Colors.grey.shade800, child: const Icon(Icons.music_note, color: Colors.white54)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            track.title,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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
                                    const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: Icon(Icons.play_circle_fill, color: Colors.blueAccent, size: 32),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: quickPicks.length,
                      ),
                    ),
                  ),
                ],

                // Trending Playlists
                if (trendingPlaylists.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24, 40, 24, 16),
                      child: Text(
                        'Trending Playlists',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
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
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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

  Widget _buildHeroBanner(bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: HoverScaleCard(
        child: Container(
          height: isDesktop ? 300 : 220,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.grey.shade900,
            image: const DecorationImage(
              image: AssetImage('assets/placeholder.png'), // Fallback safe image
              fit: BoxFit.cover,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurpleAccent.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Container(
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('FEATURED', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
                const SizedBox(height: 12),
                const Text(
                  'DISCOVER \nNEW MUSIC',
                  style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -1),
                ),
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
                    padding: const EdgeInsets.all(12),
                    child: const Icon(Icons.play_arrow, color: Colors.black, size: 32),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HoverScaleCard extends StatefulWidget {
  final Widget child;
  const HoverScaleCard({Key? key, required this.child}) : super(key: key);

  @override
  _HoverScaleCardState createState() => _HoverScaleCardState();
}

class _HoverScaleCardState extends State<HoverScaleCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isPressed = true),
      onExit: (_) => setState(() => _isPressed = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: RepaintBoundary(child: widget.child),
        ),
      ),
    );
  }
}
