import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../providers/settings_provider.dart';
import '../models/track.dart';
import '../widgets/hover_scale_card.dart';
import 'player_screen.dart';
import 'chart_detail_screen.dart';

class TrendingTab extends StatefulWidget {
  const TrendingTab({Key? key}) : super(key: key);

  @override
  State<TrendingTab> createState() => _TrendingTabState();
}

class _TrendingTabState extends State<TrendingTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MusicProvider>(context, listen: false).fetchExplore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black;
    final isDesktop = MediaQuery.of(context).size.width > 800;

    if (musicProvider.isLoadingExplore) {
      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 8),
                child: Text(
                  '🔥 Đang Thịnh Hành',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1.0,
                  ),
                ),
              ),
            ),
            if (musicProvider.exploreTrending.isNotEmpty)
              _buildSectionTitle('Top Bài Hát', textColor, context: context, tracks: musicProvider.exploreTrending),
            if (musicProvider.exploreTrending.isNotEmpty)
              _buildHorizontalList(context, musicProvider.exploreTrending, isDark, textColor, isDesktop),
            
            if (musicProvider.exploreNewReleases.isNotEmpty)
              _buildSectionTitle('✨ Mới Phát Hành', textColor, context: context, tracks: musicProvider.exploreNewReleases),
            if (musicProvider.exploreNewReleases.isNotEmpty)
              _buildHorizontalList(context, musicProvider.exploreNewReleases, isDark, textColor, isDesktop),

            ..._buildChartSection(context, musicProvider, 'Global', '🌐 Top 20 Toàn Cầu', isDark, textColor, isDesktop),
            ..._buildChartSection(context, musicProvider, 'VN', '🇻🇳 Top 20 Việt Nam', isDark, textColor, isDesktop),
            ..._buildChartSection(context, musicProvider, 'US', '🇺🇸 Top 20 Mỹ (US)', isDark, textColor, isDesktop),
            ..._buildChartSection(context, musicProvider, 'KR', '🇰🇷 Top 20 Hàn Quốc (K-Pop)', isDark, textColor, isDesktop),
            ..._buildChartSection(context, musicProvider, 'UK', '🇬🇧 Top 20 Anh (UK)', isDark, textColor, isDesktop),
              
            const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding for player
          ],
        );
      }
    );
  }

  Widget _buildSectionTitle(String title, Color textColor, {BuildContext? context, List<Track>? tracks}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            if (context != null && tracks != null)
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChartDetailScreen(title: title, tracks: tracks)));
                },
                child: Text('Xem tất cả', style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 14)),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildChartSection(BuildContext context, MusicProvider musicProvider, String key, String title, bool isDark, Color textColor, bool isDesktop) {
    final tracks = musicProvider.chartsData[key];
    if (tracks == null || tracks.isEmpty) return [const SliverToBoxAdapter(child: SizedBox.shrink())];
    
    return [
      _buildSectionTitle(title, textColor, context: context, tracks: tracks),
      _buildHorizontalList(context, tracks, isDark, textColor, isDesktop),
    ];
  }

  Widget _buildHorizontalList(BuildContext context, List<Track> tracks, bool isDark, Color textColor, bool isDesktop) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 220,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            return HoverScaleCard(
              child: GestureDetector(
                onTap: () {
                  final mp = Provider.of<MusicProvider>(context, listen: false);
                  mp.playTrack(track);
                  Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => const PlayerScreen()));
                },
                child: Container(
                  width: 160,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 160,
                        width: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: track.thumbnail != null
                            ? Image.network(
                                track.thumbnail!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
                              )
                            : _buildPlaceholder(isDark),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        track.title,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track.channel ?? 'Unknown',
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      child: Icon(Icons.music_note, size: 50, color: isDark ? Colors.white54 : Colors.black54),
    );
  }
}
