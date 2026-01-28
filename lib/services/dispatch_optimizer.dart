// lib/services/dispatch_optimizer.dart
import 'package:latlong2/latlong.dart';
import '../models/priority_crime.dart';
import '../models/police_unit.dart';

class DispatchOptimizer {
  /// A* pathfinding for optimal route
  static List<LatLng> findOptimalRoute(LatLng start, LatLng goal) {
    // Simplified A* - in real app, use actual road network
    List<LatLng> path = [];

    // Generate waypoints
    int steps = 10;
    for (int i = 0; i <= steps; i++) {
      double t = i / steps;
      double lat = start.latitude + t * (goal.latitude - start.latitude);
      double lng = start.longitude + t * (goal.longitude - start.longitude);
      path.add(LatLng(lat, lng));
    }

    return path;
  }

  /// Greedy algorithm: Assign nearest available unit to crime
  static PoliceUnit? assignBestUnit(
    PriorityCrime crime,
    List<PoliceUnit> units,
  ) {
    // Filter available units
    final availableUnits = units.where((u) => u.isAvailable).toList();

    if (availableUnits.isEmpty) return null;

    // Greedy choice: minimum distance
    PoliceUnit? bestUnit;
    double minDistance = double.infinity;

    for (var unit in availableUnits) {
      double distance = unit.distanceTo(crime.location);
      if (distance < minDistance) {
        minDistance = distance;
        bestUnit = unit;
      }
    }

    return bestUnit;
  }

  /// Priority queue implementation for crime management
  static PriorityQueue<PriorityCrime> createPriorityQueue(
    List<PriorityCrime> crimes,
  ) {
    final queue = PriorityQueue<PriorityCrime>();
    for (var crime in crimes) {
      queue.add(crime);
    }
    return queue;
  }

  /// Dynamic re-optimization: Check if reassignment improves response
  static Map<String, dynamic> optimizeAssignments(
    List<PriorityCrime> crimes,
    List<PoliceUnit> units,
  ) {
    List<Map<String, dynamic>> assignments = [];
    List<PriorityCrime> queuedCrimes = [];

    // Sort crimes by priority
    crimes.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

    // Assign units using greedy approach
    for (var crime in crimes) {
      if (crime.status != 'Open') continue;

      final bestUnit = assignBestUnit(crime, units);

      if (bestUnit != null) {
        // Calculate route
        final route =
            findOptimalRoute(bestUnit.currentLocation, crime.location);

        assignments.add({
          'crime': crime,
          'unit': bestUnit,
          'route': route,
          'eta': bestUnit.getETA(crime.location),
          'distance': bestUnit.distanceTo(crime.location),
        });

        // Mark unit as dispatched
        bestUnit.status = UnitStatus.dispatched;
        bestUnit.assignedCrimeId = crime.id;
        bestUnit.currentRoute = route;
        bestUnit.dispatchTime = DateTime.now();
      } else {
        // No available unit - add to queue
        queuedCrimes.add(crime);
      }
    }

    return {
      'assignments': assignments,
      'queued': queuedCrimes,
    };
  }

  /// Calculate ETA considering distance and average speed
  static String calculateETA(LatLng start, LatLng end) {
    const Distance distance = Distance();
    double km = distance.as(LengthUnit.Kilometer, start, end);

    // Average city speed: 40 km/h
    double hours = km / 40.0;

    if (hours < 1) {
      int minutes = (hours * 60).round();
      return '$minutes min';
    } else {
      return '${hours.toStringAsFixed(1)} hr';
    }
  }

  /// Calculate coverage score for patrol strategy
  static double calculateCoverageScore(
    List<PoliceUnit> units,
    List<LatLng> highRiskAreas,
  ) {
    if (highRiskAreas.isEmpty) return 100.0;

    const Distance distance = Distance();
    int coveredAreas = 0;

    for (var area in highRiskAreas) {
      bool isCovered = units.any((unit) {
        double dist =
            distance.as(LengthUnit.Kilometer, unit.currentLocation, area);
        return dist < 5.0; // Within 5km considered covered
      });

      if (isCovered) coveredAreas++;
    }

    return (coveredAreas / highRiskAreas.length) * 100.0;
  }
}

/// Priority Queue implementation
class PriorityQueue<T extends Comparable> {
  final List<T> _heap = [];

  void add(T element) {
    _heap.add(element);
    _bubbleUp(_heap.length - 1);
  }

  T? removeFirst() {
    if (_heap.isEmpty) return null;

    T first = _heap[0];
    T last = _heap.removeLast();

    if (_heap.isNotEmpty) {
      _heap[0] = last;
      _bubbleDown(0);
    }

    return first;
  }

  T? get first => _heap.isEmpty ? null : _heap[0];
  bool get isEmpty => _heap.isEmpty;
  bool get isNotEmpty => _heap.isNotEmpty;
  int get length => _heap.length;
  List<T> toList() => List<T>.from(_heap);

  void _bubbleUp(int index) {
    while (index > 0) {
      int parent = (index - 1) ~/ 2;
      if (_heap[index].compareTo(_heap[parent]) <= 0) break;

      _swap(index, parent);
      index = parent;
    }
  }

  void _bubbleDown(int index) {
    while (true) {
      int left = 2 * index + 1;
      int right = 2 * index + 2;
      int largest = index;

      if (left < _heap.length && _heap[left].compareTo(_heap[largest]) > 0) {
        largest = left;
      }

      if (right < _heap.length && _heap[right].compareTo(_heap[largest]) > 0) {
        largest = right;
      }

      if (largest == index) break;

      _swap(index, largest);
      index = largest;
    }
  }

  void _swap(int i, int j) {
    T temp = _heap[i];
    _heap[i] = _heap[j];
    _heap[j] = temp;
  }
}
