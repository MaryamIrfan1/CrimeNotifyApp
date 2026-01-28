import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class CrimeReportDetails extends StatelessWidget {
  final QueryDocumentSnapshot report;

  const CrimeReportDetails({Key? key, required this.report}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final title = report['title'] ?? 'No Title';
    final description = report['description'] ?? 'No Description';
    final type = report['type'] ?? 'Unknown';
    final geoPoint = report['location'] as GeoPoint?;
    final timestamp = report['timestamp'] as Timestamp?;
    final dateTime = timestamp?.toDate();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crime Report Details'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Type: $type',
                style: const TextStyle(fontSize: 18, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              Text(
                'Date: ${dateTime?.toLocal().toString().split(" ")[0] ?? "Unknown"}',
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              const Text(
                'Description:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              const Text(
                'Location:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 300,
                child: FlutterMap(
                  options: MapOptions(
                    center: geoPoint != null
                        ? LatLng(geoPoint.latitude, geoPoint.longitude)
                        : LatLng(20.5937, 78.9629), // Default center
                    zoom: 14.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: "https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=I024TPNZIC5kBgcAxrRO",
                      userAgentPackageName: 'com.example.crime_notify',
                    ),
                    if (geoPoint != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(geoPoint.latitude, geoPoint.longitude),
                            builder: (ctx) => const Icon(Icons.location_pin, color: Colors.red, size: 30),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
