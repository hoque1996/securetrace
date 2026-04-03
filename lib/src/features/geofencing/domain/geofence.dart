class Geofence {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius; // In meters
  final bool isEnabled;

  Geofence({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.isEnabled = true,
  });

  factory Geofence.fromFirestore(Map<String, dynamic> data, String id) {
    return Geofence(
      id: id,
      name: data['name'] as String? ?? 'Safe Zone',
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      radius: (data['radius'] as num? ?? 100).toDouble(),
      isEnabled: data['isEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'isEnabled': isEnabled,
    };
  }
}
