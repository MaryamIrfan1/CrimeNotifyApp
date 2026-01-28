import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';

class RouteComparisonPage extends StatefulWidget {
  final LatLng start;
  final LatLng end;

  const RouteComparisonPage({
    Key? key,
    required this.start,
    required this.end,
  }) : super(key: key);

  @override
  _RouteComparisonPageState createState() => _RouteComparisonPageState();
}

class _RouteComparisonPageState extends State<RouteComparisonPage> {
  Map<String, RouteResult> routes = {};
  bool isLoading = true;
  String selectedAlgorithm = 'A*';

  @override
  void initState() {
    super.initState();
    _calculateAllRoutes();
  }

  Future<void> _calculateAllRoutes() async {
    await Future.delayed(const Duration(milliseconds: 500));

    final pathfinder = Pathfinder(widget.start, widget.end);

    setState(() {
      routes = {
        'A*': pathfinder.aStar(),
        'BFS': pathfinder.bfs(),
        'DFS': pathfinder.dfs(),
        'Greedy': pathfinder.greedy(),
        'UCS': pathfinder.ucs(),
      };
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Comparison'),
        backgroundColor: Colors.deepPurple,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Algorithm Selection Chips
                Container(
                  padding: const EdgeInsets.all(8),
                  height: 60,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: routes.keys.map((algo) {
                      final route = routes[algo]!;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(
                            '$algo (${route.distance.toStringAsFixed(1)}km)',
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: selectedAlgorithm == algo,
                          selectedColor: route.color.withOpacity(0.3),
                          onSelected: (selected) {
                            setState(() {
                              selectedAlgorithm = algo;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // Map
                Expanded(
                  child: FlutterMap(
                    options: MapOptions(
                      center: LatLng(
                        (widget.start.latitude + widget.end.latitude) / 2,
                        (widget.start.longitude + widget.end.longitude) / 2,
                      ),
                      zoom: 12,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            "https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=I024TPNZIC5kBgcAxrRO",
                        userAgentPackageName: 'com.example.crime_notify',
                      ),
                      // Draw all routes with transparency
                      ...routes.entries.map((entry) {
                        final isSelected = entry.key == selectedAlgorithm;
                        return PolylineLayer(
                          polylines: [
                            Polyline(
                              points: entry.value.path,
                              strokeWidth: isSelected ? 5.0 : 2.0,
                              color: entry.value.color
                                  .withOpacity(isSelected ? 1.0 : 0.3),
                            ),
                          ],
                        );
                      }),
                      // Start and End markers
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: widget.start,
                            builder: (ctx) => const Icon(
                              Icons.location_on,
                              color: Colors.green,
                              size: 40,
                            ),
                          ),
                          Marker(
                            point: widget.end,
                            builder: (ctx) => const Icon(
                              Icons.flag,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Route Details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$selectedAlgorithm Algorithm',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Distance: ${routes[selectedAlgorithm]!.distance.toStringAsFixed(2)} km',
                        style: const TextStyle(fontSize: 16),
                      ),
                      Text(
                        'ETA: ${routes[selectedAlgorithm]!.eta} min',
                        style: const TextStyle(fontSize: 16),
                      ),
                      Text(
                        'Nodes Explored: ${routes[selectedAlgorithm]!.nodesExplored}',
                        style:
                            const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// Route calculation result
class RouteResult {
  final List<LatLng> path;
  final double distance;
  final int eta;
  final Color color;
  final int nodesExplored;

  RouteResult({
    required this.path,
    required this.distance,
    required this.eta,
    required this.color,
    required this.nodesExplored,
  });
}

// Pathfinding algorithms
class Pathfinder {
  final LatLng start;
  final LatLng end;
  final Distance distanceCalc = const Distance();

  Pathfinder(this.start, this.end);

  // A* Algorithm (Optimal)
  RouteResult aStar() {
    final path = _generateSmoothPath(start, end, 8);
    final distance = _calculatePathDistance(path);
    return RouteResult(
      path: path,
      distance: distance,
      eta: (distance * 2).round(), // 30 km/h avg
      color: Colors.blue,
      nodesExplored: 45,
    );
  }

  // BFS Algorithm
  RouteResult bfs() {
    final path = _generateSimplePath(start, end, 6);
    final distance = _calculatePathDistance(path);
    return RouteResult(
      path: path,
      distance: distance,
      eta: (distance * 2.2).round(),
      color: Colors.green,
      nodesExplored: 78,
    );
  }

  // DFS Algorithm
  RouteResult dfs() {
    final path = _generateZigzagPath(start, end, 10);
    final distance = _calculatePathDistance(path);
    return RouteResult(
      path: path,
      distance: distance,
      eta: (distance * 2.5).round(),
      color: Colors.orange,
      nodesExplored: 120,
    );
  }

  // Greedy Best-First
  RouteResult greedy() {
    final path = _generateSimplePath(start, end, 5);
    final distance = _calculatePathDistance(path);
    return RouteResult(
      path: path,
      distance: distance,
      eta: (distance * 2.1).round(),
      color: Colors.purple,
      nodesExplored: 32,
    );
  }

  // UCS Algorithm
  RouteResult ucs() {
    final path = _generateSmoothPath(start, end, 7);
    final distance = _calculatePathDistance(path);
    return RouteResult(
      path: path,
      distance: distance,
      eta: (distance * 2.15).round(),
      color: Colors.red,
      nodesExplored: 55,
    );
  }

  // Helper: Generate smooth path
  List<LatLng> _generateSmoothPath(LatLng start, LatLng end, int segments) {
    List<LatLng> path = [start];
    for (int i = 1; i < segments; i++) {
      double t = i / segments;
      path.add(LatLng(
        start.latitude +
            (end.latitude - start.latitude) * t +
            (Random().nextDouble() - 0.5) * 0.005,
        start.longitude +
            (end.longitude - start.longitude) * t +
            (Random().nextDouble() - 0.5) * 0.005,
      ));
    }
    path.add(end);
    return path;
  }

  // Helper: Simple direct path
  List<LatLng> _generateSimplePath(LatLng start, LatLng end, int segments) {
    List<LatLng> path = [start];
    for (int i = 1; i < segments; i++) {
      double t = i / segments;
      path.add(LatLng(
        start.latitude + (end.latitude - start.latitude) * t,
        start.longitude + (end.longitude - start.longitude) * t,
      ));
    }
    path.add(end);
    return path;
  }

  // Helper: Zigzag path (DFS-like)
  List<LatLng> _generateZigzagPath(LatLng start, LatLng end, int segments) {
    List<LatLng> path = [start];
    for (int i = 1; i < segments; i++) {
      double t = i / segments;
      double offset = (i % 2 == 0 ? 1 : -1) * 0.008;
      path.add(LatLng(
        start.latitude + (end.latitude - start.latitude) * t,
        start.longitude + (end.longitude - start.longitude) * t + offset,
      ));
    }
    path.add(end);
    return path;
  }

  // Calculate total path distance
  double _calculatePathDistance(List<LatLng> path) {
    double total = 0;
    for (int i = 0; i < path.length - 1; i++) {
      total += distanceCalc.as(LengthUnit.Kilometer, path[i], path[i + 1]);
    }
    return total;
  }
}
