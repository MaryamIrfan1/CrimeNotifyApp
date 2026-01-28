// lib/models/police_unit.dart
import 'package:latlong2/latlong.dart';

enum UnitStatus { available, dispatched, busy, offline }

class PoliceUnit {
  final String id;
  final String name;
  LatLng currentLocation;
  UnitStatus status;
  String? assignedCrimeId;
  List<LatLng>? currentRoute;
  DateTime? dispatchTime;

  PoliceUnit({
    required this.id,
    required this.name,
    required this.currentLocation,
    this.status = UnitStatus.available,
    this.assignedCrimeId,
    this.currentRoute,
    this.dispatchTime,
  });

  bool get isAvailable => status == UnitStatus.available;

  double distanceTo(LatLng target) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, currentLocation, target);
  }

  String getStatusText() {
    switch (status) {
      case UnitStatus.available:
        return 'Available';
      case UnitStatus.dispatched:
        return 'En Route';
      case UnitStatus.busy:
        return 'Busy';
      case UnitStatus.offline:
        return 'Offline';
    }
  }

  String getETA(LatLng target) {
    double dist = distanceTo(target);
    double timeHours = dist / 40; // Average 40 km/h in city

    if (timeHours < 1) {
      int minutes = (timeHours * 60).round();
      return '$minutes min';
    } else {
      return '${timeHours.toStringAsFixed(1)} hr';
    }
  }
}
