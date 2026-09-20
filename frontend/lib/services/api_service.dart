import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track.dart';
import '../models/playlist.dart';
import '../models/channel.dart';
import 'device_service.dart';

class ApiService {
  // Use Render deployment URL for production and cross-device syncing
  static const String baseUrl = 'http://127.0.0.1:8000/api';
  // static const String baseUrl = 'https://musick-app.onrender.com/api';

  static Map<String, String> _getHeaders({Map<String, String>? additionalHeaders}) {
    final headers = {
      'X-Device-Id': DeviceService.deviceId,
    };
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }
    return headers;
  }

  Future<Map<String, dynamic>> searchAll(String query, {int page = 1}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/search?q=$query&page=$page'),
      headers: _getHeaders(),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final List results = data['results'] ?? [];
      final List channelsData = data['channels'] ?? [];
      
      return {
        'tracks': results.map((json) => Track.fromJson(json)).toList(),
        'channels': channelsData.map((json) => Channel.fromJson(json)).toList(),
      };
    } else {
      throw Exception('Failed to load search results');
    }
  }

  Future<List<Track>> getChannelVideos(String channelId, {String sortBy = 'p', int page = 1}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/channels/$channelId/videos?sort_by=$sortBy&page=$page'),
      headers: _getHeaders(),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final List results = data['results'] ?? [];
      return results.map((json) => Track.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load channel videos');
    }
  }

  Future<Map<String, List<Track>>> getExplore() async {
    final response = await http.get(
      Uri.parse('$baseUrl/explore'),
      headers: _getHeaders(),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final List trendingData = data['trending'] ?? [];
      final List newReleasesData = data['new_releases'] ?? [];
      
      return {
        'trending': (trendingData as List).map((json) => Track.fromJson(Map<String, dynamic>.from(json as Map))).toList(),
        'newReleases': (newReleasesData as List).map((json) => Track.fromJson(Map<String, dynamic>.from(json as Map))).toList(),
      };
    } else {
      throw Exception('Failed to load explore data');
    }
  }

  Future<Map<String, List<Track>>> getCharts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/charts'),
      headers: _getHeaders(),
    );
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      Map<String, List<Track>> charts = {};
      data.forEach((key, value) {
        if (value is List) {
          charts[key] = value.map((json) => Track.fromJson(Map<String, dynamic>.from(json as Map))).toList();
        }
      });
      return charts;
    } else {
      throw Exception('Failed to load charts data');
    }
  }

  Future<List<String>> getSuggestions(String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl/suggest?q=$query'),
      headers: _getHeaders(),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['suggestions'] ?? [];
      return results.map((e) => e.toString()).toList();
    } else {
      return [];
    }
  }

  Future<StreamInfo> getStream(String videoId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/stream/$videoId'),
      headers: _getHeaders(),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return StreamInfo.fromJson(data);
    } else {
      throw Exception('Failed to get stream info');
    }
  }

  Future<Map<String, dynamic>?> getLyrics(String query, {String? videoId}) async {
    String url = '$baseUrl/lyrics?q=${Uri.encodeComponent(query)}';
    if (videoId != null && videoId.isNotEmpty) {
      url += '&video_id=${Uri.encodeComponent(videoId)}';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: _getHeaders(),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body)['lyrics'];
    }
    return null;
  }

  Future<Map<String, dynamic>?> translateLyrics(String lyrics, {String targetLang = 'vi'}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/translate_lyrics'),
        headers: _getHeaders(additionalHeaders: {'Content-Type': 'application/json'}),
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
      final response = await http.get(
        Uri.parse('$baseUrl/db/favorites'),
        headers: _getHeaders(),
      );
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
      headers: _getHeaders(additionalHeaders: {'Content-Type': 'application/json'}),
      body: json.encode(track.toJson()),
    );
  }

  Future<void> removeFavorite(String videoId) async {
    await http.delete(
      Uri.parse('$baseUrl/db/favorites/$videoId'),
      headers: _getHeaders(),
    );
  }

  // History & Settings
  Future<List<Track>> getHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/db/history'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((json) => Track.fromJson(json)).toList();
      }
    } catch(e) {
      print("getHistory error: $e");
    }
    return [];
  }

  Future<void> addToHistory(Track track) async {
    await http.post(
      Uri.parse('$baseUrl/db/history'),
      headers: _getHeaders(additionalHeaders: {'Content-Type': 'application/json'}),
      body: json.encode(track.toJson()),
    );
  }

  Future<void> removeFromHistory(String videoId) async {
    await http.delete(
      Uri.parse('$baseUrl/db/history/$videoId'),
      headers: _getHeaders(),
    );
  }

  Future<Map<String, String>> getSettings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/db/settings'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        Map<String, String> settings = {};
        data.forEach((key, value) {
          settings[key] = value?.toString() ?? '';
        });
        return settings;
      }
    } catch(e) {
      print("getSettings error: $e");
    }
    return {};
  }

  Future<void> updateSetting(String key, String value) async {
    await http.post(
      Uri.parse('$baseUrl/db/settings'),
      headers: _getHeaders(additionalHeaders: {'Content-Type': 'application/json'}),
      body: json.encode({key: value}),
    );
  }

  Future<List<Playlist>> getPlaylists() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/db/playlists'),
        headers: _getHeaders(),
      );
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
      headers: _getHeaders(additionalHeaders: {'Content-Type': 'application/json'}),
      body: json.encode({'name': name}),
    );
    if (response.statusCode == 200) {
      return Playlist.fromJson(json.decode(response.body));
    }
    return null;
  }

  Future<void> deletePlaylist(String id) async {
    await http.delete(
      Uri.parse('$baseUrl/db/playlists/$id'),
      headers: _getHeaders(),
    );
  }

  Future<void> updatePlaylist(String id, String newName, String? newCoverImage) async {
    await http.put(
      Uri.parse('$baseUrl/db/playlists/$id'),
      headers: _getHeaders(additionalHeaders: {'Content-Type': 'application/json'}),
      body: json.encode({'name': newName, 'cover_image': newCoverImage}),
    );
  }

  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    await http.post(
      Uri.parse('$baseUrl/db/playlists/$playlistId/tracks'),
      headers: _getHeaders(additionalHeaders: {'Content-Type': 'application/json'}),
      body: json.encode(track.toJson()),
    );
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String videoId) async {
    await http.delete(
      Uri.parse('$baseUrl/db/playlists/$playlistId/tracks/$videoId'),
      headers: _getHeaders(),
    );
  }

  Future<void> reorderPlaylistTracks(String playlistId, List<String> trackIds) async {
    await http.put(
      Uri.parse('$baseUrl/db/playlists/$playlistId/reorder'),
      headers: _getHeaders(additionalHeaders: {'Content-Type': 'application/json'}),
      body: json.encode(trackIds),
    );
  }

  Future<void> reorderFavorites(List<String> trackIds) async {
    await http.put(
      Uri.parse('$baseUrl/db/favorites/reorder'),
      headers: _getHeaders(additionalHeaders: {'Content-Type': 'application/json'}),
      body: json.encode(trackIds),
    );
  }

  Future<void> clearFavorites() async {
    await http.delete(
      Uri.parse('$baseUrl/db/favorites'),
      headers: _getHeaders(),
    );
  }

  Future<bool> updateThumbnail(String videoId, String imageUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/db/tracks/$videoId/thumbnail'),
        headers: _getHeaders(additionalHeaders: {'Content-Type': 'application/x-www-form-urlencoded'}),
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
      request.headers.addAll(_getHeaders());
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
  Future<Map<String, dynamic>?> getCustomLyrics(String videoId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/db/lyrics/$videoId'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body)['lyrics'];
      }
    } catch (e) {
      print('getCustomLyrics error: $e');
    }
    return null;
  }

  Future<bool> saveCustomLyrics(String videoId, String? plainLyrics, String? syncedLyrics) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/db/lyrics/$videoId'),
        headers: _getHeaders(additionalHeaders: {'Content-Type': 'application/json'}),
        body: json.encode({
          'plain_lyrics': plainLyrics,
          'synced_lyrics': syncedLyrics,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('saveCustomLyrics error: $e');
      return false;
    }
  }
}
