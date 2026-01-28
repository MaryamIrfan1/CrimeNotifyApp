// lib/models/priority_crime.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class PriorityCrime implements Comparable<PriorityCrime> {
  final String id;
  final String title;
  final String description;
  final String type;
  final LatLng location;
  final DateTime timestamp;
  final String status;
  final double priorityScore;
  final bool hasPhotos;
  final bool hasVideo;
  String? assignedUnit;
  DateTime? assignedTime;

  PriorityCrime({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.location,
    required this.timestamp,
    required this.status,
    required this.priorityScore,
    this.hasPhotos = false,
    this.hasVideo = false,
    this.assignedUnit,
    this.assignedTime,
  });

  factory PriorityCrime.fromFirestore(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final geoPoint = data['location'] as GeoPoint?;
    final timestamp = data['timestamp'] as Timestamp?;

    return PriorityCrime(
      id: doc.id,
      title: data['title'] ?? 'No Title',
      description: data['description'] ?? '',
      type: data['type'] ?? 'Other',
      location: geoPoint != null
          ? LatLng(geoPoint.latitude, geoPoint.longitude)
          : LatLng(0, 0),
      timestamp: timestamp?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'Open',
      priorityScore: (data['priorityScore'] as num?)?.toDouble() ?? 0.0,
      hasPhotos: data['hasPhotos'] ?? false,
      hasVideo: data['hasVideo'] ?? false,
      assignedUnit: data['assignedUnit'],
      assignedTime: data['assignedTime'] != null
          ? (data['assignedTime'] as Timestamp).toDate()
          : null,
    );
  }

  @override
  int compareTo(PriorityCrime other) {
    // Higher priority score comes first
    return other.priorityScore.compareTo(priorityScore);
  }

  String getPriorityLevel() {
    if (priorityScore >= 8.0) return 'CRITICAL';
    if (priorityScore >= 6.0) return 'HIGH';
    if (priorityScore >= 4.0) return 'MEDIUM';
    return 'LOW';
  }

  String getPriorityEmoji() {
    if (priorityScore >= 8.0) return '🔴';
    if (priorityScore >= 6.0) return '🟠';
    if (priorityScore >= 4.0) return '🟡';
    return '🟢';
  }
}
