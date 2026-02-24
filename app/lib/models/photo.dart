class Photo {
  final String id;
  final String coupleId;
  final String authorId;
  final String imageUrl;
  final String? thumbnailUrl;
  final String? caption;
  final double? latitude;
  final double? longitude;
  final String? address;
  final DateTime? takenAt;
  final DateTime createdAt;

  const Photo({required this.id, required this.coupleId, required this.authorId, required this.imageUrl, this.thumbnailUrl, this.caption, this.latitude, this.longitude, this.address, this.takenAt, required this.createdAt});

  factory Photo.fromJson(Map<String, dynamic> json) => Photo(
    id: json['id'], coupleId: json['coupleId'] ?? '', authorId: json['authorId'] ?? '',
    imageUrl: json['imageUrl'], thumbnailUrl: json['thumbnailUrl'],
    caption: json['caption'],
    latitude: json['latitude']?.toDouble(), longitude: json['longitude']?.toDouble(),
    address: json['address'],
    takenAt: json['takenAt'] != null ? DateTime.parse(json['takenAt']) : null,
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
  );

  bool get hasLocation => latitude != null && longitude != null;
}
