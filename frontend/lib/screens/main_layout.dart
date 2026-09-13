import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../widgets/mini_player.dart';
import 'home_tab.dart';
import 'search_tab.dart';
import 'library_tab.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  _MainLayoutState createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeTab(),
    const SearchTab(),
    const LibraryTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final hasTrack = Provider.of<MusicProvider>(context).currentTrack != null;
    
    // Check if desktop width
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: Row(
        children: [
          if (isDesktop)
            NavigationRail(
              backgroundColor: Colors.black,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              labelType: NavigationRailLabelType.all,
              useIndicator: true,
              indicatorColor: Colors.blueAccent.withOpacity(0.2),
              selectedIconTheme: const IconThemeData(color: Colors.blueAccent),
              unselectedIconTheme: IconThemeData(color: Colors.grey.shade500),
              selectedLabelTextStyle: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
              unselectedLabelTextStyle: TextStyle(color: Colors.grey.shade500),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.search_outlined),
                  selectedIcon: Icon(Icons.search),
                  label: Text('Search'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music),
                  label: Text('Library'),
                ),
              ],
            ),
          
          if (isDesktop)
            const VerticalDivider(thickness: 1, width: 1, color: Colors.white10),
            
          Expanded(
            child: Stack(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.02, 0.0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    key: ValueKey<int>(_selectedIndex),
                    child: _pages[_selectedIndex],
                  ),
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
                  backgroundColor: Colors.black,
                  currentIndex: _selectedIndex,
                  selectedItemColor: Colors.blueAccent,
                  unselectedItemColor: Colors.grey.shade600,
                  onTap: (int index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.home_outlined),
                      activeIcon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.search_outlined),
                      activeIcon: Icon(Icons.search),
                      label: 'Search',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.library_music_outlined),
                      activeIcon: Icon(Icons.library_music),
                      label: 'Library',
                    ),
                  ],
                ),
              ],
            )
          : null,
    );
  }
}
