import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'police_dashboard.dart';
import 'command_center.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: const FirebaseOptions(
            apiKey: "AIzaSyDDFd_smW_Ak6GICIGPq7PnKq5Mo9WnfbQ",
            authDomain: "crimenotifyapp.firebaseapp.com",
            projectId: "crimenotifyapp",
            storageBucket: "crimenotifyapp.firebasestorage.app",
            messagingSenderId: "683082957817",
            appId: "1:683082957817:web:afcb5784abb9fae0397328",
            measurementId: "G-S314CYR5F3"));
  } else {
    await Firebase.initializeApp();
  }

  runApp(const CrimeNotifyApp());
}

class CrimeNotifyApp extends StatelessWidget {
  const CrimeNotifyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crime Notify',
      theme: ThemeData(
        primaryColor: Colors.deepPurple,
        hintColor: Colors.amber,
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontSize: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontSize: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/witness': (context) => const WitnessScreen(),
        '/police_login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/police_dashboard': (context) => const PoliceDashboard(),
        '/command_center': (context) => const CommandCenter(),
      },
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.purpleAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.network(
                'https://cdn.iconscout.com/icon/premium/png-512-thumb/police-2542655-2134561.png?f=webp&w=512',
                height: 150,
              ),
              const SizedBox(height: 20),
              const Text(
                'Crime Notify',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Report crimes quickly and securely. Your safety, our priority.',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/witness');
                },
                icon: const Icon(Icons.report),
                label: const Text('Enter as Witness'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/police_login');
                },
                icon: const Icon(Icons.security),
                label: const Text('Login as Police'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WitnessScreen extends StatefulWidget {
  const WitnessScreen({Key? key}) : super(key: key);

  @override
  _WitnessScreenState createState() => _WitnessScreenState();
}

class _WitnessScreenState extends State<WitnessScreen> {
  final _formKey = GlobalKey<FormState>(); // Form key
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  LatLng? selectedLocation;
  String? selectedCrimeType;

  // Replace the entire build() method in _WitnessScreenState with this:

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report a Crime'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Stack(
        children: [
          // Existing form content
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ... (keep all existing form fields - title, description, dropdown, etc.)
                  // I'm showing just the structure, keep your existing fields here

                  const Text(
                    'Crime Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Crime Title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter a title' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Crime Description',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter a description' : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField(
                    decoration: const InputDecoration(
                      labelText: 'Select Crime Type',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: selectedCrimeType,
                    items: ['Theft', 'Assault', 'Fraud', 'Other'].map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCrimeType = value as String?;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Please select a crime type' : null,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SelectLocationScreen()),
                      );
                      if (result != null) {
                        setState(() {
                          selectedLocation = result;
                        });
                      }
                    },
                    icon: const Icon(Icons.map),
                    label: Text(
                      selectedLocation == null
                          ? 'Select Location'
                          : 'Location Selected: (${selectedLocation!.latitude.toStringAsFixed(4)}, ${selectedLocation!.longitude.toStringAsFixed(4)})',
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate() &&
                          selectedLocation != null &&
                          selectedCrimeType != null) {
                        try {
                          CollectionReference reports = FirebaseFirestore
                              .instance
                              .collection('CrimeReports');

                          await reports.add({
                            'title': _titleController.text.trim(),
                            'description': _descriptionController.text.trim(),
                            'type': selectedCrimeType,
                            'location': GeoPoint(selectedLocation!.latitude,
                                selectedLocation!.longitude),
                            'status': 'Open',
                            'timestamp': Timestamp.now(),
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text("Report successfully submitted!")),
                          );
                          Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    "Failed to submit report. Try again.")),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  "Please fill all fields and select location.")),
                        );
                      }
                    },
                    child: const Text('Submit Report'),
                  ),
                  const SizedBox(height: 100), // Space for SOS button
                ],
              ),
            ),
          ),

          // EMERGENCY SOS BUTTON (NEW)
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton.extended(
              onPressed: () async {
                // Get current location
                try {
                  Position position = await Geolocator.getCurrentPosition(
                    desiredAccuracy: LocationAccuracy.high,
                  );

                  // Send emergency alert to Firestore
                  await FirebaseFirestore.instance
                      .collection('CrimeReports')
                      .add({
                    'title': '🚨 EMERGENCY SOS ALERT',
                    'description': 'Emergency distress signal sent by witness',
                    'type': 'Emergency',
                    'location': GeoPoint(position.latitude, position.longitude),
                    'status': 'Open',
                    'timestamp': Timestamp.now(),
                    'isEmergency': true,
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🚨 Emergency SOS sent to police!'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 3),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to send SOS. Enable location.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.warning, size: 28),
              label: const Text(
                'EMERGENCY SOS',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SelectLocationScreen extends StatefulWidget {
  const SelectLocationScreen({Key? key}) : super(key: key);

  @override
  _SelectLocationScreenState createState() => _SelectLocationScreenState();
}

// ignore: non_constant_identifier_names
class _SelectLocationScreenState extends State<SelectLocationScreen> {
  LatLng? selectedLocation;
  LatLng? currentLocation;
  final String mapTilerKey = 'PDwG5ahmvqz3dsg7qoSG';
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  bool isLoadingSearch = false;

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enable location services.")),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Location permissions are permanently denied.")),
        );
        return;
      }

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permissions are denied.")),
          );
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        // ignore: deprecated_member_use
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
        selectedLocation = currentLocation;
      });

      // Move the map to the current location
      _mapController.move(currentLocation!, 15.0);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please wait, the map is loading.")),
      );
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;

    setState(() {
      isLoadingSearch = true;
    });

    final url = Uri.parse(
        'https://api.maptiler.com/geocoding/$query.json?key=$mapTilerKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'] != null && data['features'].isNotEmpty) {
          final location = data['features'][0]['geometry']['coordinates'];
          final latitude = location[1];
          final longitude = location[0];

          setState(() {
            selectedLocation = LatLng(latitude, longitude);
            isLoadingSearch = false;
          });

          // Move the map center to the searched location
          _mapController.move(selectedLocation!, 15.0);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location found!")),
          );
        } else {
          setState(() {
            isLoadingSearch = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No results found.")),
          );
        }
      } else {
        throw Exception("Failed to fetch location data");
      }
    } catch (e) {
      setState(() {
        isLoadingSearch = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to fetch location data.")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Location')),
      body: currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: currentLocation,
                    zoom: 15.0,
                    onTap: (tapPosition, point) {
                      setState(() {
                        selectedLocation = point;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          "https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=$mapTilerKey",
                      userAgentPackageName: 'com.example.crime_notify',
                    ),
                    if (selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: selectedLocation!,
                            builder: (ctx) => const Icon(Icons.location_pin,
                                color: Colors.red, size: 40),
                          ),
                        ],
                      ),
                  ],
                ),
                // Search Bar
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: "Search location",
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            onSubmitted: (query) {
                              _searchLocation(query);
                            },
                          ),
                        ),
                        if (isLoadingSearch)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        if (!isLoadingSearch)
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () {
                              _searchLocation(_searchController.text);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                // Action Buttons
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            selectedLocation = currentLocation;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Current location selected.")),
                          );
                        },
                        child: const Text('Select My Current Location'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(
                              context, selectedLocation ?? currentLocation);
                        },
                        child: Text(
                          selectedLocation != null
                              ? 'Confirm Selected Location'
                              : 'Confirm Current Location',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
