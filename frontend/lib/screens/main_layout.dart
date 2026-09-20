import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/mini_player.dart';
import 'home_tab.dart';
import 'search_tab.dart';
import 'library_tab.dart';
import 'trending_tab.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  _MainLayoutState createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeTab(),
    const TrendingTab(),
    const SearchTab(),
    const LibraryTab(),
  ];

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  Widget _buildNavigator(int index) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => _pages[index],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasTrack = context.select<MusicProvider, bool>((p) => p.currentTrack != null);
    
    // Check if desktop width
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final isDark = Provider.of<SettingsProvider>(context).isDarkMode;

    return WillPopScope(
      onWillPop: () async {
        final currentNav = _navigatorKeys[_selectedIndex].currentState;
        if (currentNav != null && currentNav.canPop()) {
          currentNav.pop();
          return false;
        }
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: Row(
          children: [
            if (isDesktop)
              NavigationRail(
                backgroundColor: isDark ? Colors.black : Colors.white,
                selectedIndex: _selectedIndex,
                onDestinationSelected: (int index) {
                  setState(() {
                    if (_selectedIndex == index) {
                      // Pop to root of this tab
                      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
                    } else {
                      _selectedIndex = index;
                    }
                  });
                },
                labelType: NavigationRailLabelType.all,
                useIndicator: true,
                indicatorColor: Colors.blueAccent.withOpacity(0.2),
                selectedIconTheme: const IconThemeData(color: Colors.blueAccent),
                unselectedIconTheme: IconThemeData(color: Colors.grey.shade500),
                selectedLabelTextStyle: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                unselectedLabelTextStyle: TextStyle(color: Colors.grey.shade500),
                destinations: [
                  NavigationRailDestination(
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: const Icon(Icons.home),
                    label: Text(Provider.of<SettingsProvider>(context).t('home')),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.local_fire_department_outlined),
                    selectedIcon: Icon(Icons.local_fire_department),
                    label: Text('Trending'),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.search_outlined),
                    selectedIcon: const Icon(Icons.search),
                    label: Text(Provider.of<SettingsProvider>(context).t('search')),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.library_music_outlined),
                    selectedIcon: const Icon(Icons.library_music),
                    label: Text(Provider.of<SettingsProvider>(context).t('library')),
                  ),
                ],
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: IconButton(
                        icon: const Icon(Icons.settings, color: Colors.grey),
                        onPressed: () => _showSettingsDialog(context),
                      ),
                    ),
                  ),
                ),
              ),
            
            if (isDesktop)
              const VerticalDivider(thickness: 1, width: 1, color: Colors.white10),
              
            Expanded(
              child: Stack(
                children: [
                  IndexedStack(
                    index: _selectedIndex,
                    children: List.generate(4, (index) => _buildNavigator(index)),
                  ),
                if (hasTrack && isDesktop)
                  const Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: MiniPlayer(),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: !isDesktop
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasTrack) const MiniPlayer(),
                BottomNavigationBar(
                  backgroundColor: isDark ? Colors.black : Colors.white,
                  currentIndex: _selectedIndex,
                  selectedItemColor: Colors.blueAccent,
                  unselectedItemColor: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  onTap: (int index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  items: [
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.home_outlined),
                      activeIcon: const Icon(Icons.home),
                      label: Provider.of<SettingsProvider>(context).t('home'),
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.local_fire_department_outlined),
                      activeIcon: Icon(Icons.local_fire_department),
                      label: 'Trending',
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.search_outlined),
                      activeIcon: const Icon(Icons.search),
                      label: Provider.of<SettingsProvider>(context).t('search'),
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.library_music_outlined),
                      activeIcon: const Icon(Icons.library_music),
                      label: Provider.of<SettingsProvider>(context).t('library'),
                    ),
                  ],
                ),
              ],
            )
          : null,
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Consumer<SettingsProvider>(
          builder: (context, settings, _) {
            final isDark = settings.isDarkMode;
            final textColor = isDark ? Colors.white : Colors.black87;
            final bgColor = isDark ? Colors.grey.shade900 : Colors.white;

            return AlertDialog(
              backgroundColor: bgColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                settings.t('settings'),
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: isDark ? Colors.white70 : Colors.black54),
                    title: Text(settings.t('theme'), style: TextStyle(color: textColor)),
                    trailing: DropdownButton<bool>(
                      value: settings.isDarkMode,
                      dropdownColor: bgColor,
                      style: TextStyle(color: textColor),
                      underline: const SizedBox(),
                      items: [
                        DropdownMenuItem(
                          value: true,
                          child: Text(settings.t('dark_mode')),
                        ),
                        DropdownMenuItem(
                          value: false,
                          child: Text(settings.t('light_mode')),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null && val != settings.isDarkMode) {
                          settings.toggleTheme();
                        }
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.language, color: isDark ? Colors.white70 : Colors.black54),
                    title: Text(settings.t('language'), style: TextStyle(color: textColor)),
                    trailing: DropdownButton<String>(
                      value: settings.locale,
                      dropdownColor: bgColor,
                      style: TextStyle(color: textColor),
                      underline: const SizedBox(),
                      items: [
                        DropdownMenuItem(
                          value: 'en',
                          child: Text(settings.t('english')),
                        ),
                        DropdownMenuItem(
                          value: 'vi',
                          child: Text(settings.t('vietnamese')),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          settings.setLocale(val);
                        }
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(settings.t('close'), style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
