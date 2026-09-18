class Channel {
  final String id;
  final String title;
  final String? avatar;
  final String? subscribers;

  Channel({
    required this.id,
    required this.title,
    this.avatar,
    this.subscribers,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['channel_id'] ?? '',
      title: json['title'] ?? 'Unknown Channel',
      avatar: json['avatar'],
      subscribers: json['subscribers'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'channel_id': id,
      'title': title,
      'avatar': avatar,
      'subscribers': subscribers,
    };
  }
}
