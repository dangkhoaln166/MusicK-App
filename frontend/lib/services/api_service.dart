import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track.dart';
import '../models/playlist.dart';

class ApiService {
  // Use 10.0.2.2 for Android emulator to access host localhost
  // Use localhost for iOS simulator or Desktop
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  Future<List<Track>> searchTracks(String query, {int page = 1}) async {
    final response = await http.get(Uri.parse('$baseUrl/search?q=$query&page=$page'));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'] ?? [];
      return results.map((json) => Track.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load search results');
    }
  }

  Future<List<String>> getSuggestions(String query) async {
    final response = await http.get(Uri.parse('$baseUrl/suggest?q=$query'));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['suggestions'] ?? [];
      return results.map((e) => e.toString()).toList();
    } else {
      return [];
    }
  }

  Future<StreamInfo> getStream(String videoId) async {
    final response = await http.get(Uri.parse('$baseUrl/stream/$videoId'));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return StreamInfo.fromJson(data);
    } else {
      throw Exception('Failed to get stream info');
    }
  }

  Future<Map<String, dynamic>?> getLyrics(String query) async {
    final response = await http.get(Uri.parse('$baseUrl/lyrics?q=$query'));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['lyrics'];
    } else {
      return null;
    }
  }

  // --- Database API ---

  Future<List<Track>> getFavorites() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/db/favorites'));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((json) => Track.fromJson(json)).toList();
      }
    } catch(e) {
      print("getFavorites error: $e");
    }
    return [];
  }

  Future<void> addFavorite(Track track) async {
    await http.post(
      Uri.parse('$baseUrl/db/favorites'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(track.toJson()),
    );
  }

  Future<void> removeFavorite(String videoId) async {
    await http.delete(Uri.parse('$baseUrl/db/favorites/$videoId'));
  }

  Future<List<Playlist>> getPlaylists() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/db/playlists'));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((json) => Playlist.fromJson(json)).toList();
      }
    } catch(e) {
      print("getPlaylists error: $e");
    }
    return [];
  }

  Future<Playlist?> createPlaylist(String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/db/playlists'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name}),
    );
    if (response.statusCode == 200) {
      return Playlist.fromJson(json.decode(response.body));
    }
    return null;
  }

  Future<void> deletePlaylist(String id) async {
    await http.delete(Uri.parse('$baseUrl/db/playlists/$id'));
  }

  Future<void> renamePlaylist(String id, String newName) async {
    await http.put(
      Uri.parse('$baseUrl/db/playlists/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': newName}),
    );
  }

  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    await http.post(
      Uri.parse('$baseUrl/db/playlists/$playlistId/tracks'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(track.toJson()),
    );
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String videoId) async {
    await http.delete(Uri.parse('$baseUrl/db/playlists/$playlistId/tracks/$videoId'));
  }
}
