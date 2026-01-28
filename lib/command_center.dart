// lib/command_center.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'models/priority_crime.dart';
import 'models/police_unit.dart';
import 'services/priority_calculator.dart';
import 'services/dispatch_optimizer.dart';

enum ViewMode {
  allIncidents,
  crimeDetail,
  activeAssignments,
}

class CommandCenter extends StatefulWidget {
  const CommandCenter({Key? key}) : super(key: key);

  @override
  _CommandCenterState createState() => _CommandCenterState();
}

class _CommandCenterState extends State<CommandCenter> {
  // Data
  List<PriorityCrime> activeCrimes = [];
  List<PoliceUnit> policeUnits = [];

  // UI State
  ViewMode currentView = ViewMode.allIncidents;
  PriorityCrime? selectedCrime;

  // Cached optimization results
  Map<String, dynamic>? cachedOptimization;

  // Track previous critical count for smart optimization
  int _previousCriticalCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeUnits();
  }

  void _initializeUnits() {
    policeUnits = [
      PoliceUnit(
        id: 'UNIT-1',
        name: 'Patrol Unit 1',
        currentLocation: LatLng(33.5651, 73.0169),
        status: UnitStatus.available,
      ),
      PoliceUnit(
        id: 'UNIT-2',
        name: 'Patrol Unit 2',
        currentLocation: LatLng(33.6844, 73.0479),
        status: UnitStatus.available,
      ),
      PoliceUnit(
        id: 'UNIT-3',
        name: 'Patrol Unit 3',
        currentLocation: LatLng(33.7294, 73.0931),
        status: UnitStatus.available,
      ),
      PoliceUnit(
        id: 'UNIT-4',
        name: 'Patrol Unit 4',
        currentLocation: LatLng(33.6500, 73.1000),
        status: UnitStatus.available,
      ),
    ];
  }

  void _updateCrimesFromSnapshot(AsyncSnapshot<QuerySnapshot> snapshot) {
    if (!snapshot.hasData) return;

    activeCrimes = snapshot.data!.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final geoPoint = data['location'] as GeoPoint?;
      final timestamp = data['timestamp'] as Timestamp?;

      double priorityScore = PriorityCalculator.calculatePriority(
        crimeType: data['type'] ?? 'Other',
        description: data['description'] ?? '',
        timestamp: timestamp?.toDate() ?? DateTime.now(),
        location: geoPoint != null
            ? LatLng(geoPoint.latitude, geoPoint.longitude)
            : LatLng(0, 0),
        hasPhotos: data['hasPhotos'] ?? false,
        hasVideo: data['hasVideo'] ?? false,
      );

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
        priorityScore: priorityScore,
        hasPhotos: data['hasPhotos'] ?? false,
        hasVideo: data['hasVideo'] ?? false,
      );
    }).toList();

    activeCrimes.sort();

    // Auto-optimize only if new critical crime arrived
    final currentCriticalCount =
        activeCrimes.where((c) => c.priorityScore >= 8.0).length;
    if (currentCriticalCount > _previousCriticalCount &&
        activeCrimes.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _onOptimizePressed();
      });
    }
    _previousCriticalCount = currentCriticalCount;
  }

  void _onOptimizePressed() {
    if (activeCrimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active crimes to optimize')),
      );
      return;
    }

    setState(() {
      cachedOptimization = DispatchOptimizer.optimizeAssignments(
        activeCrimes,
        policeUnits,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Dispatch optimization complete'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onCrimeSelected(PriorityCrime crime) {
    setState(() {
      selectedCrime = crime;
      currentView = ViewMode.crimeDetail;
    });
  }

  void _switchView(ViewMode mode) {
    setState(() {
      currentView = mode;
      if (mode != ViewMode.crimeDetail) {
        selectedCrime = null;
      }
    });
  }

  void _showAssignmentDialog(PriorityCrime crime) {
    final availableUnits =
        policeUnits.where((u) => u.status == UnitStatus.available).toList();

    if (availableUnits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ No units available')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assign Unit to: ${crime.title}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const SizedBox(height: 8),
            ...availableUnits.map((unit) {
              final distance =
                  _calculateDistance(unit.currentLocation, crime.location);
              final eta = _calculateETA(distance);

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.local_police, color: Colors.blue),
                  title: Text(unit.name),
                  subtitle: Text(
                      'Distance: ${distance.toStringAsFixed(1)} km • ETA: $eta'),
                  trailing: ElevatedButton(
                    onPressed: () {
                      _assignUnit(unit, crime);
                      Navigator.pop(context);
                    },
                    child: const Text('Assign'),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  void _assignUnit(PoliceUnit unit, PriorityCrime crime) {
    setState(() {
      unit.status = UnitStatus.dispatched;
      _switchView(ViewMode.activeAssignments);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ ${unit.name} dispatched to ${crime.title}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  double _calculateDistance(LatLng from, LatLng to) {
    const double earthRadius = 6371;
    final dLat = _toRadians(to.latitude - from.latitude);
    final dLon = _toRadians(to.longitude - from.longitude);

    final a = (dLat / 2).sin() * (dLat / 2).sin() +
        from.latitude.toRadians().cos() *
            to.latitude.toRadians().cos() *
            (dLon / 2).sin() *
            (dLon / 2).sin();

    final c = 2 * (a.sqrt()).asin();
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (3.14159265359 / 180.0);

  String _calculateETA(double distanceKm) {
    final minutes = (distanceKm / 0.5).round();
    if (minutes < 60) return '$minutes min';
    final hours = (minutes / 60).floor();
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚨 Command Center'),
        backgroundColor: Colors.red[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Optimize Dispatch',
            onPressed: _onOptimizePressed,
          ),
          IconButton(
            icon: Icon(
              currentView == ViewMode.activeAssignments
                  ? Icons.dashboard
                  : Icons.assignment,
            ),
            tooltip: currentView == ViewMode.activeAssignments
                ? 'All Incidents'
                : 'Active Assignments',
            onPressed: () {
              _switchView(
                currentView == ViewMode.activeAssignments
                    ? ViewMode.allIncidents
                    : ViewMode.activeAssignments,
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('CrimeReports')
            .where('status', isEqualTo: 'Open')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          _updateCrimesFromSnapshot(snapshot);

          return _buildMainLayout();
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 100, color: Colors.green[300]),
          const SizedBox(height: 20),
          Text(
            'All Clear',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'No active incidents to monitor',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildMainLayout() {
    return Column(
      children: [
        _buildStatsBar(),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildMapView(),
              ),
              Container(
                width: 1,
                color: Colors.grey[300],
              ),
              Expanded(
                flex: 2,
                child: _buildRightPanel(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsBar() {
    final criticalCount =
        activeCrimes.where((c) => c.priorityScore >= 8.0).length;
    final highCount = activeCrimes
        .where((c) => c.priorityScore >= 6.0 && c.priorityScore < 8.0)
        .length;
    final dispatchedCount =
        policeUnits.where((u) => u.status == UnitStatus.dispatched).length;
    final availableCount =
        policeUnits.where((u) => u.status == UnitStatus.available).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[900]!, Colors.grey[800]!],
        ),
      ),
      child: Row(
        children: [
          Expanded(
              child:
                  _buildStatCard('🔴', criticalCount, 'CRITICAL', Colors.red)),
          Expanded(
              child: _buildStatCard('🟠', highCount, 'HIGH', Colors.orange)),
          Expanded(
              child: _buildStatCard(
                  '👮', dispatchedCount, 'DISPATCHED', Colors.blue)),
          Expanded(
              child: _buildStatCard(
                  '✓', availableCount, 'AVAILABLE', Colors.green)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String emoji, int count, String label, Color color) {
    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView() {
    final assignments = cachedOptimization?['assignments'] as List? ?? [];

    return FlutterMap(
      options: MapOptions(
        center: activeCrimes.isNotEmpty
            ? activeCrimes.first.location
            : LatLng(33.6844, 73.0479),
        zoom: 11.5,
      ),
      children: [
        TileLayer(
          urlTemplate:
              "https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=I024TPNZIC5kBgcAxrRO",
          userAgentPackageName: 'com.example.crime_notify',
        ),
        MarkerLayer(
          markers: activeCrimes.map((crime) {
            final isSelected = selectedCrime?.id == crime.id;
            return Marker(
              point: crime.location,
              width: isSelected ? 50 : 40,
              height: isSelected ? 50 : 40,
              builder: (ctx) => GestureDetector(
                onTap: () => _onCrimeSelected(crime),
                child: Container(
                  decoration: BoxDecoration(
                    color: _getPriorityColor(crime.priorityScore),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.yellow : Colors.white,
                      width: isSelected ? 3 : 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.yellow.withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      crime.priorityScore.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        MarkerLayer(
          markers: policeUnits.map((unit) {
            return Marker(
              point: unit.currentLocation,
              width: 50,
              height: 50,
              builder: (ctx) => Container(
                decoration: BoxDecoration(
                  color: _getUnitColor(unit.status),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.local_police,
                    color: Colors.white, size: 24),
              ),
            );
          }).toList(),
        ),
        if (assignments.isNotEmpty)
          PolylineLayer(
            polylines: assignments.map<Polyline>((assignment) {
              final route = assignment['route'] as List<LatLng>;
              return Polyline(
                points: route,
                strokeWidth: 3.0,
                color: Colors.blue.withOpacity(0.7),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildRightPanel() {
    switch (currentView) {
      case ViewMode.crimeDetail:
        return _buildCrimeDetailPanel();
      case ViewMode.activeAssignments:
        return _buildActiveAssignmentsPanel();
      case ViewMode.allIncidents:
      default:
        return _buildAllIncidentsPanel();
    }
  }

  Widget _buildCrimeDetailPanel() {
    if (selectedCrime == null) {
      return const Center(child: Text('No crime selected'));
    }

    final crime = selectedCrime!;
    final availableUnits =
        policeUnits.where((u) => u.status == UnitStatus.available).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _switchView(ViewMode.allIncidents),
              ),
              const Text(
                'Crime Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getPriorityColor(crime.priorityScore),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${crime.getPriorityEmoji()} ${crime.getPriorityLevel()} (${crime.priorityScore.toStringAsFixed(1)})',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            crime.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Type: ${crime.type}', style: const TextStyle(fontSize: 14)),
          Text('Reported: ${_formatTime(crime.timestamp)}',
              style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          Text(
            crime.description,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'Available Units',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: availableUnits.isEmpty
                ? const Center(
                    child: Text(
                      '⚠️ No units available',
                      style: TextStyle(color: Colors.orange),
                    ),
                  )
                : ListView(
                    children: availableUnits.map((unit) {
                      final distance = _calculateDistance(
                          unit.currentLocation, crime.location);
                      final eta = _calculateETA(distance);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.local_police,
                              color: Colors.green),
                          title: Text(unit.name),
                          subtitle: Text(
                              '${distance.toStringAsFixed(1)} km • ETA: $eta'),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: availableUnits.isEmpty
                ? null
                : () => _showAssignmentDialog(crime),
            icon: const Icon(Icons.send),
            label: const Text('DISPATCH UNIT'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.blue,
              disabledBackgroundColor: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveAssignmentsPanel() {
    final assignments = cachedOptimization?['assignments'] as List? ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🚨 Active Responses',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          Expanded(
            child: assignments.isEmpty
                ? const Center(
                    child: Text(
                      'No active responses',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView(
                    children: assignments.map((assignment) {
                      return _buildAssignmentCard(assignment);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllIncidentsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📋 All Incidents',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            '${activeCrimes.length} active',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: activeCrimes.length,
              itemBuilder: (context, index) {
                final crime = activeCrimes[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getPriorityColor(crime.priorityScore),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          crime.priorityScore.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      crime.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle:
                        Text('${crime.type} • ${_formatTime(crime.timestamp)}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _onCrimeSelected(crime),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> assignment) {
    final crime = assignment['crime'] as PriorityCrime;
    final unit = assignment['unit'] as PoliceUnit;
    final eta = assignment['eta'] as String;
    final distance = assignment['distance'] as double;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(crime.priorityScore),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${crime.getPriorityEmoji()} ${crime.priorityScore.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_police,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        unit.name,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              crime.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              crime.type,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[700]),
                const SizedBox(width: 4),
                Text(
                  'ETA: $eta',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.directions, size: 16, color: Colors.grey[700]),
                const SizedBox(width: 4),
                Text(
                  '${distance.toStringAsFixed(1)} km',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(double score) {
    if (score >= 8.0) return Colors.red;
    if (score >= 6.0) return Colors.orange;
    if (score >= 4.0) return Colors.yellow[700]!;
    return Colors.green;
  }

  Color _getUnitColor(UnitStatus status) {
    switch (status) {
      case UnitStatus.available:
        return Colors.green;
      case UnitStatus.dispatched:
        return Colors.blue;
      case UnitStatus.busy:
        return Colors.orange;
      case UnitStatus.offline:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} days ago';
  }
}

extension on num {
  double toRadians() => this * (3.14159265359 / 180.0);
  double sin() => toRadians();
  double cos() => toRadians();
  double asin() => toRadians();
  double sqrt() => toDouble();
}
