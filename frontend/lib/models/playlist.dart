import 'track.dart';

class Playlist {
  final String id;
  String name;
  final List<Track> tracks;
  final DateTime createdAt;

  Playlist({
    required this.id,
    required this.name,
    List<Track>? tracks,
    DateTime? createdAt,
  })  : tracks = tracks ?? [],
        createdAt = createdAt ?? DateTime.now();

  String? get coverImage {
    if (tracks.isNotEmpty) {
      return tracks.first.thumbnail;
    }
    return null;
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'],
      name: json['name'],
      tracks: json['tracks'] != null ? (json['tracks'] as List).map((e) => Track.fromJson(Map<String, dynamic>.from(e))).toList() : [],
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tracks': tracks.map((t) => t.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
