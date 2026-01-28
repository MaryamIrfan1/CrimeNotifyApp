import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'crime_report_details.dart';
import 'history.dart';
import 'analytics_page.dart';
import 'route_comparison_page.dart';
import 'models/officer.dart';
import 'dart:math';

class PoliceDashboard extends StatefulWidget {
  const PoliceDashboard({Key? key}) : super(key: key);

  @override
  _PoliceDashboardState createState() => _PoliceDashboardState();
}

class _PoliceDashboardState extends State<PoliceDashboard> {
  int _selectedIndex = 0;
  bool showHotspots = true;

  void _onItemTapped(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HistoryPage()),
      );
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AnalyticsPage()),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Police Dashboard'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Command Center',
            onPressed: () {
              Navigator.pushNamed(context, '/command_center');
            },
          ),
          Switch(
            value: showHotspots,
            onChanged: (val) => setState(() {
              showHotspots = val;
            }),
            activeThumbColor: Colors.red,
          ),
          const Text('Hotspots'),
        ],
      ),
      body: _selectedIndex == 0
          ? const CrimeReportsList()
          : const Center(child: Text('Unknown Page')),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.analytics), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepPurple,
        onTap: _onItemTapped,
      ),
    );
  }
}

class CrimeReportsList extends StatefulWidget {
  const CrimeReportsList({Key? key}) : super(key: key);

  @override
  _CrimeReportsListState createState() => _CrimeReportsListState();
}

class _CrimeReportsListState extends State<CrimeReportsList> {
  List<Officer> mockOfficers = [
    Officer(
      id: 'off1',
      name: 'Officer Khan',
      location: LatLng(33.6844, 73.0479), // Rawalpindi
      activeCases: 1,
    ),
    Officer(
      id: 'off2',
      name: 'Officer Ahmed',
      location: LatLng(31.5204, 74.3587), // Lahore
      activeCases: 0,
    ),
    Officer(
      id: 'off3',
      name: 'Officer Fatima',
      location: LatLng(24.8607, 67.0011), // Karachi
      activeCases: 2,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('CrimeReports').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No crime reports available.'));
        }

        final reports = snapshot.data!.docs;
        final openReports =
            reports.where((report) => report['status'] == 'Open').toList();

        // Sort by priority (Feature 1)
        final sortedReports = _sortByPriority(openReports);

        // Detect hotspots (Feature 3)
        final hotspots = _detectHotspots(openReports);

        final firstReport = openReports.isNotEmpty
            ? openReports.first['location'] as GeoPoint?
            : null;
        final defaultCenter = firstReport != null
            ? LatLng(firstReport.latitude, firstReport.longitude)
            : LatLng(30.3753, 69.3451); // Pakistan center

        return Column(
          children: [
            // Map with hotspots
            Expanded(
              flex: 2,
              child: FlutterMap(
                options: MapOptions(
                  center: defaultCenter,
                  zoom: 5.5,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        "https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=I024TPNZIC5kBgcAxrRO",
                    userAgentPackageName: 'com.example.crime_notify',
                  ),
                  // Hotspot circles (Feature 3)
                  CircleLayer(
                    circles: hotspots.map((hotspot) {
                      return CircleMarker(
                        point: hotspot.center,
                        radius: hotspot.radius,
                        color: Colors.red.withOpacity(0.2),
                        borderColor: Colors.red,
                        borderStrokeWidth: 2,
                        useRadiusInMeter: true,
                      );
                    }).toList(),
                  ),
                  // Crime markers
                  MarkerLayer(
                    markers: sortedReports.map((report) {
                      final geoPoint = report['location'] as GeoPoint?;
                      if (geoPoint == null) {
                        return Marker(
                            point: LatLng(0, 0), builder: (_) => Container());
                      }
                      final priority = _calculatePriority(report);
                      return Marker(
                        point: LatLng(geoPoint.latitude, geoPoint.longitude),
                        builder: (ctx) => GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    CrimeReportDetails(report: report),
                              ),
                            );
                          },
                          child: Icon(
                            Icons.location_pin,
                            color: _getPriorityColor(priority),
                            size: 35,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const Divider(height: 2, color: Colors.black),
            // Crime list
            Expanded(
              flex: 3,
              child: ListView.builder(
                itemCount: sortedReports.length,
                itemBuilder: (context, index) {
                  final report = sortedReports[index];
                  final title = report['title'];
                  final type = report['type'];
                  final timestamp = report['timestamp'] as Timestamp?;
                  final dateTime = timestamp?.toDate();
                  final priority = _calculatePriority(report);
                  final geoPoint = report['location'] as GeoPoint?;

                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              // Priority Badge (Feature 1)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getPriorityColor(priority),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _getPriorityLabel(priority),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Type: $type\nDate: ${dateTime?.toLocal().toString().split(" ")[0]}\nTime: ${dateTime?.toLocal().toString().split(" ")[1].split(".")[0]}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (geoPoint != null) ...[
                            const SizedBox(height: 8),
                            // Risk Prediction (Feature 3)
                            Row(
                              children: [
                                const Icon(Icons.warning_amber,
                                    size: 18, color: Colors.orange),
                                const SizedBox(width: 4),
                                Text(
                                  'Risk Score: ${_calculateRiskScore(report, sortedReports)}%',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              // Route Comparison Button (Feature 2)
                              if (geoPoint != null)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            RouteComparisonPage(
                                          start: LatLng(
                                              33.6844, 73.0479), // Police HQ
                                          end: LatLng(geoPoint.latitude,
                                              geoPoint.longitude),
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.route, size: 18),
                                  label: const Text('Compare Routes',
                                      style: TextStyle(fontSize: 12)),
                                ),
                              // Auto-Dispatch Button (Feature 4)
                              if (geoPoint != null)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () {
                                    _showAutoDispatchDialog(
                                      context,
                                      report,
                                      LatLng(geoPoint.latitude,
                                          geoPoint.longitude),
                                    );
                                  },
                                  icon: const Icon(Icons.send, size: 18),
                                  label: const Text('Auto-Dispatch',
                                      style: TextStyle(fontSize: 12)),
                                ),
                              // Mark as Done
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text('Mark as Done'),
                                        content: const Text(
                                            'Are you sure to mark this crime as done?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              FirebaseFirestore.instance
                                                  .collection('CrimeReports')
                                                  .doc(report.id)
                                                  .update({'status': 'Done'});
                                              Navigator.pop(context);
                                            },
                                            child: const Text('Confirm'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('Done',
                                    style: TextStyle(fontSize: 12)),
                              ),
                              // View Details
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CrimeReportDetails(report: report),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.info, size: 18),
                                label: const Text('Details',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ========== FEATURE 1: INTELLIGENT PRIORITY SCORING ==========
  List<QueryDocumentSnapshot> _sortByPriority(
      List<QueryDocumentSnapshot> reports) {
    reports.sort((a, b) {
      final priorityA = _calculatePriority(a);
      final priorityB = _calculatePriority(b);
      return priorityB.compareTo(priorityA); // High priority first
    });
    return reports;
  }

  int _calculatePriority(QueryDocumentSnapshot report) {
    int score = 0;

    // Crime type severity
    final type = report['type'] ?? '';
    if (type == 'Assault') {
      score += 50;
    } else if (type == 'Theft')
      score += 30;
    else if (type == 'Fraud')
      score += 20;
    else
      score += 10;

    // Time urgency (recent = higher priority)
    final timestamp = report['timestamp'] as Timestamp?;
    if (timestamp != null) {
      final age = DateTime.now().difference(timestamp.toDate()).inHours;
      if (age < 1) {
        score += 30;
      } else if (age < 6)
        score += 20;
      else if (age < 24) score += 10;
    }

    return score;
  }

  Color _getPriorityColor(int priority) {
    if (priority >= 70) return Colors.red;
    if (priority >= 40) return Colors.orange;
    return Colors.green;
  }

  String _getPriorityLabel(int priority) {
    if (priority >= 70) return 'HIGH';
    if (priority >= 40) return 'MEDIUM';
    return 'LOW';
  }

  // ========== FEATURE 3: HOTSPOT DETECTION & RISK PREDICTION ==========
  List<Hotspot> _detectHotspots(List<QueryDocumentSnapshot> reports) {
    if (reports.length < 3) return [];

    List<LatLng> locations = reports
        .map((r) => r['location'] as GeoPoint?)
        .where((g) => g != null)
        .map((g) => LatLng(g!.latitude, g.longitude))
        .toList();

    // K-Means Clustering (NEW CONCEPT 1)
    List<LatLng> clusters =
        _kMeansClustering(locations, min(3, locations.length));

    return clusters.map((center) {
      int nearbyCount = locations.where((loc) {
        const distance = Distance();
        return distance.as(LengthUnit.Kilometer, center, loc) < 10;
      }).length;

      return Hotspot(
        center: center,
        radius: 5000.0 + (nearbyCount * 1000), // Bigger for more crimes
        crimeCount: nearbyCount,
      );
    }).toList();
  }

  // K-Means Clustering Algorithm (NEW CONCEPT 1)
  List<LatLng> _kMeansClustering(List<LatLng> points, int k) {
    if (points.isEmpty || k <= 0) return [];

    final random = Random();
    List<LatLng> centroids = List.generate(
      k,
      (i) => points[random.nextInt(points.length)],
    );

    // Run 5 iterations
    for (int iter = 0; iter < 5; iter++) {
      Map<int, List<LatLng>> clusters = {};

      // Assign points to nearest centroid
      for (var point in points) {
        int nearest = 0;
        double minDist = double.infinity;

        for (int i = 0; i < centroids.length; i++) {
          double dist = _distance(point, centroids[i]);
          if (dist < minDist) {
            minDist = dist;
            nearest = i;
          }
        }

        clusters[nearest] = clusters[nearest] ?? [];
        clusters[nearest]!.add(point);
      }

      // Update centroids
      for (int i = 0; i < k; i++) {
        if (clusters[i] != null && clusters[i]!.isNotEmpty) {
          double avgLat =
              clusters[i]!.map((p) => p.latitude).reduce((a, b) => a + b) /
                  clusters[i]!.length;
          double avgLon =
              clusters[i]!.map((p) => p.longitude).reduce((a, b) => a + b) /
                  clusters[i]!.length;
          centroids[i] = LatLng(avgLat, avgLon);
        }
      }
    }

    return centroids;
  }

  double _distance(LatLng a, LatLng b) {
    return sqrt(
        pow(a.latitude - b.latitude, 2) + pow(a.longitude - b.longitude, 2));
  }

  // Statistical Risk Prediction (NEW CONCEPT 2)
  int _calculateRiskScore(
      QueryDocumentSnapshot report, List<QueryDocumentSnapshot> allReports) {
    final geoPoint = report['location'] as GeoPoint?;
    if (geoPoint == null) return 0;

    final location = LatLng(geoPoint.latitude, geoPoint.longitude);
    const distance = Distance();

    // Count nearby crimes within 5km
    int nearbyCount = allReports.where((r) {
      final otherGeo = r['location'] as GeoPoint?;
      if (otherGeo == null) return false;
      final dist = distance.as(
        LengthUnit.Kilometer,
        location,
        LatLng(otherGeo.latitude, otherGeo.longitude),
      );
      return dist < 5.0 && r.id != report.id;
    }).length;

    // Calculate probability score
    int baseRisk = _calculatePriority(report);
    int densityRisk = min(nearbyCount * 10, 40);

    return min(baseRisk + densityRisk, 100);
  }

  // ========== FEATURE 4: AUTO-DISPATCH TO NEAREST OFFICER ==========
  void _showAutoDispatchDialog(BuildContext context,
      QueryDocumentSnapshot report, LatLng crimeLocation) {
    // Beam Search to find best officer (Syllabus Algorithm)
    Officer bestOfficer = _findBestOfficer(crimeLocation);
    double distance = bestOfficer.distanceTo(crimeLocation);
    int eta = (distance * 2).round(); // 30 km/h avg speed

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.local_police, color: Colors.teal),
            SizedBox(width: 8),
            Text('Auto-Dispatch'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Best Officer Found:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 20, color: Colors.teal),
                      const SizedBox(width: 8),
                      Text(
                        bestOfficer.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.directions_car,
                          size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text('Distance: ${distance.toStringAsFixed(1)} km'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text('ETA: $eta minutes'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.work, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text('Active Cases: ${bestOfficer.activeCases}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () {
              // In real app: Send notification to officer
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✓ Dispatched to ${bestOfficer.name}'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            icon: const Icon(Icons.send),
            label: const Text('Dispatch'),
          ),
        ],
      ),
    );
  }

  // Greedy Best-First + Beam Search for officer selection
  Officer _findBestOfficer(LatLng crimeLocation) {
    mockOfficers.sort((a, b) => a
        .assignmentScore(crimeLocation)
        .compareTo(b.assignmentScore(crimeLocation)));
    return mockOfficers.first;
  }
}

// Hotspot model
class Hotspot {
  final LatLng center;
  final double radius;
  final int crimeCount;

  Hotspot({
    required this.center,
    required this.radius,
    required this.crimeCount,
  });
}
