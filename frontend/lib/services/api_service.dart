import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track.dart';

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
}
