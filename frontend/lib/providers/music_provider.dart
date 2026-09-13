import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/track.dart';
import '../models/playlist.dart';
import '../services/api_service.dart';

class MusicProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Track> _searchResults = [];
  List<String> _suggestions = [];
  Track? _currentTrack;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isPlaying = false;
  int _currentPage = 1;
  String _currentQuery = '';
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  
  int _currentIndex = -1;
  bool _isShuffle = false;
  LoopMode _loopMode = LoopMode.off;
  List<Track> _queue = [];
  List<Track> _favorites = [];
  List<Playlist> _playlists = [];
  double _volume = 1.0;

  List<Track> get searchResults => _searchResults;
  List<String> get suggestions => _suggestions;
  List<Track> get queue => _queue;
  List<Track> get favorites => _favorites;
  List<Playlist> get playlists => _playlists;
  Track? get currentTrack => _currentTrack;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  AudioPlayer get audioPlayer => _audioPlayer;
  bool get isShuffle => _isShuffle;
  LoopMode get loopMode => _loopMode;
  double get volume => _volume;

  MusicProvider() {
    _loadPreferences();
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        if (_loopMode == LoopMode.one) {
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.play();
        } else {
          playNext();
        }
      }
      notifyListeners();
    });

    _audioPlayer.positionStream.listen((pos) {
      // Only notify when the displayed second changes (saves ~4 rebuilds/sec)
      if (pos.inSeconds != _position.inSeconds) {
        _position = pos;
        notifyListeners();
      } else {
        _position = pos; // still update internally
      }
    });

    _audioPlayer.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueStr = prefs.getString('queue');
      if (queueStr != null) {
        final List decoded = json.decode(queueStr);
        _queue = decoded.map((e) => Track.fromJson(Map<String, dynamic>.from(e))).toList();
      }
      
      final favStr = prefs.getString('favorites');
      if (favStr != null) {
        final List decoded = json.decode(favStr);
        _favorites = decoded.map((e) => Track.fromJson(Map<String, dynamic>.from(e))).toList();
      }
      
      final playStr = prefs.getString('playlists');
      if (playStr != null) {
        final List decoded = json.decode(playStr);
        _playlists = decoded.map((e) => Playlist.fromJson(Map<String, dynamic>.from(e))).toList();
      }
      notifyListeners();
    } catch (e) {
      print("Error loading preferences: $e");
    }
  }

  Future<void> _saveQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(_queue.map((e) => e.toJson()).toList());
    await prefs.setString('queue', encoded);
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(_favorites.map((e) => e.toJson()).toList());
    await prefs.setString('favorites', encoded);
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(_playlists.map((e) => e.toJson()).toList());
    await prefs.setString('playlists', encoded);
  }

  // Playlist Management
  void createPlaylist(String name) {
    if (name.trim().isEmpty) return;
    final newPlaylist = Playlist(id: const Uuid().v4(), name: name.trim());
    _playlists.add(newPlaylist);
    _savePlaylists();
    notifyListeners();
  }

  void deletePlaylist(String id) {
    _playlists.removeWhere((p) => p.id == id);
    _savePlaylists();
    notifyListeners();
  }

  void addTrackToPlaylist(String playlistId, Track track) {
    final playlist = _playlists.firstWhere((p) => p.id == playlistId);
    if (!playlist.tracks.any((t) => t.videoId == track.videoId)) {
      playlist.tracks.add(track);
      _savePlaylists();
      notifyListeners();
    }
  }

  void removeTrackFromPlaylist(String playlistId, String trackId) {
    final playlist = _playlists.firstWhere((p) => p.id == playlistId);
    playlist.tracks.removeWhere((t) => t.videoId == trackId);
    _savePlaylists();
    notifyListeners();
  }

  void renamePlaylist(String id, String newName) {
    if (newName.trim().isEmpty) return;
    final playlist = _playlists.firstWhere((p) => p.id == id);
    playlist.name = newName.trim();
    _savePlaylists();
    notifyListeners();
  }

  Future<void> search(String query) async {
    _isLoading = true;
    _currentPage = 1;
    _currentQuery = query;
    notifyListeners();

    try {
      _searchResults = await _apiService.searchTracks(query, page: _currentPage);
    } catch (e) {
      print("Search error: $e");
      _searchResults = [];
    }

    _isLoading = false;
    _suggestions = []; // clear suggestions when search is done
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || _currentQuery.isEmpty) return;
    
    _isLoadingMore = true;
    _currentPage++;
    notifyListeners();

    try {
      final moreResults = await _apiService.searchTracks(_currentQuery, page: _currentPage);
      _searchResults.addAll(moreResults);
    } catch (e) {
      print("Load more error: $e");
      _currentPage--; // Revert page on failure
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> fetchSuggestions(String query) async {
    if (query.isEmpty) {
      _suggestions = [];
      notifyListeners();
      return;
    }
    try {
      _suggestions = await _apiService.getSuggestions(query);
      notifyListeners();
    } catch (e) {
      print("Suggest error: $e");
    }
  }

  void clearSuggestions() {
    _suggestions = [];
    notifyListeners();
  }

  Future<void> playTrack(Track track) async {
    _currentTrack = track;
    // Update _currentIndex only if track is in _searchResults (don't override if caller already set it)
    final idx = _searchResults.indexOf(track);
    if (idx != -1) _currentIndex = idx;
    notifyListeners();

    try {
      print('[MusicProvider] Playing track: "${track.title}" | videoId: ${track.videoId} | index: $_currentIndex');
      // Stop current playback before loading new track
      await _audioPlayer.stop();
      final streamInfo = await _apiService.getStream(track.videoId);
      print('[MusicProvider] Got stream URL for: ${track.videoId}');
      await _audioPlayer.setUrl(streamInfo.audioUrl);
      _audioPlayer.play();
    } catch (e) {
      print('[MusicProvider] ERROR playing ${track.videoId}: $e');
    }
  }

  /// Plays all tracks from a playlist, starting from [startIndex].
  /// Sets the playlist tracks as the active queue for next/previous navigation.
  Future<void> playPlaylist(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    // Use playlist tracks as the active source for playNext/playPrevious
    _searchResults = List.from(tracks);
    _currentIndex = startIndex;
    // Clear any manual queue so playlist order is respected
    _queue.clear();

    // Set currentTrack immediately so UI shows correct song right away
    _currentTrack = tracks[startIndex];
    notifyListeners();

    try {
      print('[MusicProvider] PlayPlaylist: "${tracks[startIndex].title}" | index: $startIndex');
      await _audioPlayer.stop();
      final streamInfo = await _apiService.getStream(tracks[startIndex].videoId);
      await _audioPlayer.setUrl(streamInfo.audioUrl);
      _audioPlayer.play();
    } catch (e) {
      print('[MusicProvider] ERROR in playPlaylist: $e');
    }
  }

  void playNext() {
    if (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      _saveQueue();
      playTrack(next);
      return;
    }

    if (_searchResults.isEmpty) return;

    if (_isShuffle) {
      _currentIndex = (DateTime.now().millisecondsSinceEpoch % _searchResults.length);
      playTrack(_searchResults[_currentIndex]);
      return;
    }

    if (_currentIndex < _searchResults.length - 1) {
      _currentIndex++;
      playTrack(_searchResults[_currentIndex]);
    } else if (_loopMode == LoopMode.all) {
      _currentIndex = 0;
      playTrack(_searchResults[_currentIndex]);
    }
  }

  void addToQueue(Track track) {
    if (!_queue.contains(track)) {
      _queue.add(track);
      _saveQueue();
      notifyListeners();
    }
  }

  void toggleFavorite(Track track) {
    if (isFavorite(track)) {
      _favorites.removeWhere((t) => t.videoId == track.videoId);
    } else {
      _favorites.add(track);
    }
    _saveFavorites();
    notifyListeners();
  }

  bool isFavorite(Track track) {
    return _favorites.any((t) => t.videoId == track.videoId);
  }

  void playPrevious() {
    if (_searchResults.isEmpty) return;
    if (_currentIndex > 0) {
      _currentIndex--;
      playTrack(_searchResults[_currentIndex]);
    } else if (_loopMode == LoopMode.all) {
      _currentIndex = _searchResults.length - 1;
      playTrack(_searchResults[_currentIndex]);
    }
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void toggleRepeat() {
    if (_loopMode == LoopMode.off) {
      _loopMode = LoopMode.all;
    } else if (_loopMode == LoopMode.all) {
      _loopMode = LoopMode.one;
    } else {
      _loopMode = LoopMode.off;
    }
    notifyListeners();
  }

  void togglePlayPause() {
    if (_audioPlayer.playing) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }



  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
    _audioPlayer.setVolume(_volume);
    notifyListeners();
  }

  void seek(Duration position) {
    _audioPlayer.seek(position);
  }

  void seekForward() {
    final currentPosition = _audioPlayer.position;
    _audioPlayer.seek(currentPosition + const Duration(seconds: 10));
  }

  void seekBackward() {
    final currentPosition = _audioPlayer.position;
    final newPosition = currentPosition - const Duration(seconds: 10);
    _audioPlayer.seek(newPosition.isNegative ? Duration.zero : newPosition);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
