class Track {
  final String videoId;
  final String title;
  String? thumbnail;
  final int? duration;
  final String? channel;

  Track({
    required this.videoId,
    required this.title,
    this.thumbnail,
    this.duration,
    this.channel,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      videoId: json['video_id']?.toString() ?? json['id']?.toString() ?? 'unknown_id',
      title: json['title']?.toString() ?? 'Unknown Title',
      thumbnail: json['thumbnail']?.toString(),
      duration: json['duration'] != null ? int.tryParse(json['duration'].toString()) : null,
      channel: json['channel']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'video_id': videoId,
      'title': title,
      'thumbnail': thumbnail,
      'duration': duration,
      'channel': channel,
    };
  }

  @override
  bool operator ==(Object other) => other is Track && other.videoId == videoId;

  @override
  int get hashCode => videoId.hashCode;
}

class StreamInfo {
  final String audioUrl;
  final String? videoUrl;

  StreamInfo({required this.audioUrl, this.videoUrl});

  factory StreamInfo.fromJson(Map<String, dynamic> json) {
    return StreamInfo(
      audioUrl: json['audio_url'],
      videoUrl: json['video_url'],
    );
  }
}
