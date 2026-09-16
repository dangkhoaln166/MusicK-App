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
  List<Track> _recentlyPlayed = [];
  List<Track> _favorites = [];
  List<Playlist> _playlists = [];
  double _volume = 1.0;

  List<Track> get searchResults => _searchResults;
  List<String> get suggestions => _suggestions;
  List<Track> get queue => _queue;
  List<Track> get recentlyPlayed => _recentlyPlayed;
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
  bool get isCompleted => _audioPlayer.processingState == ProcessingState.completed;

  MusicProvider() {
    _loadData();
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        if (_loopMode == LoopMode.one) {
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.play();
        } else {
          // Play next track if possible. Otherwise it stops here.
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

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueStr = prefs.getString('queue');
      if (queueStr != null) {
        final List decoded = json.decode(queueStr);
        _queue = decoded.map((e) => Track.fromJson(Map<String, dynamic>.from(e))).toList();
      }
      
      final currentTrackStr = prefs.getString('currentTrack');
      if (currentTrackStr != null) {
        _currentTrack = Track.fromJson(Map<String, dynamic>.from(json.decode(currentTrackStr)));
      }

      final recentlyPlayedStr = prefs.getString('recentlyPlayed');
      if (recentlyPlayedStr != null) {
        final List decoded = json.decode(recentlyPlayedStr);
        _recentlyPlayed = decoded.map((e) => Track.fromJson(Map<String, dynamic>.from(e))).toList();
      }
      
      _favorites = await _apiService.getFavorites();
      _playlists = await _apiService.getPlaylists();
      
      notifyListeners();
    } catch (e) {
      print("Error loading data: $e");
    }
  }

  Future<void> _saveQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(_queue.map((e) => e.toJson()).toList());
    await prefs.setString('queue', encoded);
  }



  Future<void> _saveCurrentTrack() async {
    if (_currentTrack == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentTrack', json.encode(_currentTrack!.toJson()));
  }

  Future<void> _saveRecentlyPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _recentlyPlayed.map((e) => e.toJson()).toList();
    await prefs.setString('recentlyPlayed', json.encode(list));
  }


  // Playlist Management
  Future<void> createPlaylist(String name) async {
    if (name.trim().isEmpty) return;
    final newPlaylist = await _apiService.createPlaylist(name.trim());
    if (newPlaylist != null) {
      _playlists.add(newPlaylist);
      notifyListeners();
    }
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    await _apiService.deletePlaylist(id);
    notifyListeners();
  }

  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    final playlist = _playlists.firstWhere((p) => p.id == playlistId);
    if (!playlist.tracks.any((t) => t.videoId == track.videoId)) {
      playlist.tracks.add(track);
      await _apiService.addTrackToPlaylist(playlistId, track);
      notifyListeners();
    }
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    final playlist = _playlists.firstWhere((p) => p.id == playlistId);
    playlist.tracks.removeWhere((t) => t.videoId == trackId);
    await _apiService.removeTrackFromPlaylist(playlistId, trackId);
    notifyListeners();
  }

  Future<void> updatePlaylist(String id, String newName, String? newCoverImage) async {
    if (newName.trim().isEmpty) return;
    final playlist = _playlists.firstWhere((p) => p.id == id);
    playlist.name = newName.trim();
    playlist.customCoverImage = newCoverImage?.trim().isEmpty == true ? null : newCoverImage?.trim();
    await _apiService.updatePlaylist(id, newName.trim(), playlist.customCoverImage);
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
    _saveCurrentTrack(); // Save track for persistence
    
    // Update recently played
    _recentlyPlayed.removeWhere((t) => t.videoId == track.videoId);
    _recentlyPlayed.insert(0, track);
    if (_recentlyPlayed.length > 20) {
      _recentlyPlayed = _recentlyPlayed.take(20).toList();
    }
    _saveRecentlyPlayed();

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

  Future<void> toggleFavorite(Track track) async {
    if (isFavorite(track)) {
      _favorites.removeWhere((t) => t.videoId == track.videoId);
      await _apiService.removeFavorite(track.videoId);
    } else {
      _favorites.add(track);
      await _apiService.addFavorite(track);
    }
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
      if (_audioPlayer.processingState == ProcessingState.completed) {
        _audioPlayer.seek(Duration.zero);
      }
      _audioPlayer.play();
    }
  }

  Future<void> stopPlayback() async {
    await _audioPlayer.stop();
    _currentTrack = null;
    
    // Remove from saved preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentTrack');
    
    notifyListeners();
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
