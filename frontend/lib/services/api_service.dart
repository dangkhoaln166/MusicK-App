import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track.dart';
import '../models/playlist.dart';

class ApiService {
  // Use 10.0.2.2 for Android emulator to access host localhost
  // Use 127.0.0.1 instead of localhost to prevent IPv4/IPv6 resolution issues on Windows
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
    final response = await http.get(Uri.parse('$baseUrl/lyrics?q=${Uri.encodeComponent(query)}'));
    if (response.statusCode == 200) {
      return json.decode(response.body)['lyrics'];
    }
    return null;
  }

  Future<Map<String, dynamic>?> translateLyrics(String lyrics, {String targetLang = 'vi'}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/translate_lyrics'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'lyrics': lyrics,
          'target_lang': targetLang,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return {
          'translated': data['translated'] ?? '',
          'romaji': data['romaji'] ?? '',
        };
      }
    } catch (e) {
      print("translateLyrics error: $e");
    }
    return null;
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

  Future<void> updatePlaylist(String id, String newName, String? newCoverImage) async {
    await http.put(
      Uri.parse('$baseUrl/db/playlists/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': newName, 'cover_image': newCoverImage}),
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

  Future<bool> updateThumbnail(String videoId, String imageUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/db/tracks/$videoId/thumbnail'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'image_url': imageUrl},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating thumbnail: $e');
      return false;
    }
  }

  Future<String?> uploadImage(List<int> bytes, String filename) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/db/upload_image'));
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ));
      
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonResponse = json.decode(responseData);
        return jsonResponse['url'];
      }
    } catch (e) {
      print('Error uploading image: $e');
    }
    return null;
  }
}
