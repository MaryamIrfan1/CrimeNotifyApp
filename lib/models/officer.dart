import 'package:latlong2/latlong.dart';

class Officer {
  final String id;
  final String name;
  final LatLng location;
  final bool isAvailable;
  final int activeCases;

  Officer({
    required this.id,
    required this.name,
    required this.location,
    this.isAvailable = true,
    this.activeCases = 0,
  });

  // Calculate distance to a crime location (in km)
  double distanceTo(LatLng crimeLocation) {
    const distance = Distance();
    return distance.as(LengthUnit.Kilometer, location, crimeLocation);
  }

  // Calculate priority score for assignment (lower is better)
  double assignmentScore(LatLng crimeLocation) {
    double dist = distanceTo(crimeLocation);
    return dist * (1 + activeCases * 0.2); // Penalize busy officers
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'isAvailable': isAvailable,
      'activeCases': activeCases,
    };
  }

  factory Officer.fromMap(Map<String, dynamic> map, String id) {
    return Officer(
      id: id,
      name: map['name'] ?? 'Unknown',
      location: LatLng(
        map['latitude'] ?? 0.0,
        map['longitude'] ?? 0.0,
      ),
      isAvailable: map['isAvailable'] ?? true,
      activeCases: map['activeCases'] ?? 0,
    );
  }
}
