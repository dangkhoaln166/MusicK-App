import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class SettingsProvider with ChangeNotifier {
  late bool _isDarkMode;
  late String _locale;
  final ApiService _apiService = ApiService();
  bool _isLoaded = false;

  bool get isDarkMode => _isDarkMode;
  String get locale => _locale;
  bool get isLoaded => _isLoaded;

  SettingsProvider() {
    _isDarkMode = true; // Default
    _locale = 'en'; // Default
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _apiService.getSettings();
    _isDarkMode = (settings['isDarkMode'] ?? 'true') == 'true';
    _locale = settings['locale'] ?? 'en';
    _isLoaded = true;
    notifyListeners();
  }

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    await _apiService.updateSetting('isDarkMode', _isDarkMode.toString());
  }

  void setLocale(String localeCode) async {
    if (_locale != localeCode) {
      _locale = localeCode;
      notifyListeners();
      await _apiService.updateSetting('locale', _locale);
    }
  }

  // Very basic translation dictionary
  static const Map<String, Map<String, String>> _localizedStrings = {
    'en': {
      'home': 'Home',
      'search': 'Search',
      'library': 'Library',
      'settings': 'Settings',
      'theme': 'Theme',
      'language': 'Language',
      'dark_mode': 'Dark Mode',
      'light_mode': 'Light Mode',
      'english': 'English',
      'vietnamese': 'Vietnamese',
      'recently_played': 'Recently Played',
      'trending_playlists': 'Trending Playlists',
      'featured': 'FEATURED',
      'discover_new_music': 'DISCOVER\nNEW MUSIC',
      'liked_songs': 'Liked Songs',
      'songs': 'songs',
      'tracks': 'tracks',
      'playlist': 'Playlist',
      'good_morning': 'Good morning',
      'good_afternoon': 'Good afternoon',
      'good_evening': 'Good evening',
      'close': 'Close',
      'search_placeholder': 'Search songs, artists, or links...',
      'added_to_liked': 'Added to Liked Songs',
      'removed_from_liked': 'Removed from Liked Songs',
      'your_library': 'Your Library',
    },
    'vi': {
      'home': 'Trang chủ',
      'search': 'Tìm kiếm',
      'library': 'Thư viện',
      'settings': 'Cài đặt',
      'theme': 'Giao diện',
      'language': 'Ngôn ngữ',
      'dark_mode': 'Nền tối',
      'light_mode': 'Nền sáng',
      'english': 'Tiếng Anh',
      'vietnamese': 'Tiếng Việt',
      'recently_played': 'Vừa mới nghe',
      'trending_playlists': 'Playlist thịnh hành',
      'featured': 'NỔI BẬT',
      'discover_new_music': 'KHÁM PHÁ\nNHẠC MỚI',
      'liked_songs': 'Bài hát yêu thích',
      'songs': 'bài hát',
      'tracks': 'bài',
      'playlist': 'Danh sách phát',
      'good_morning': 'Chào buổi sáng',
      'good_afternoon': 'Chào buổi chiều',
      'good_evening': 'Chào buổi tối',
      'close': 'Đóng',
      'search_placeholder': 'Tìm bài hát, nghệ sĩ, hoặc liên kết...',
      'added_to_liked': 'Đã thêm vào mục yêu thích',
      'removed_from_liked': 'Đã xoá khỏi mục yêu thích',
      'your_library': 'Thư viện của bạn',
    }
  };

  String t(String key) {
    return _localizedStrings[_locale]?[key] ?? key;
  }
}
