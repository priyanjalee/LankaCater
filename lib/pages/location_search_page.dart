// location_search_page.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart'; // For town name to coordinates
import '../../constants/colors.dart';
import 'customer_home_page.dart';
import 'caterer_details_page.dart';

class LocationSearchPage extends StatefulWidget {
  const LocationSearchPage({super.key});

  @override
  State<LocationSearchPage> createState() => _LocationSearchPageState();
}

class _LocationSearchPageState extends State<LocationSearchPage> {
  final TextEditingController _locationController = TextEditingController();
  GoogleMapController? _mapController;

  // Western Province center (Colombo)
  LatLng _initialPosition = const LatLng(6.9271, 79.8612);
  final double _zoomLevel = 9.0;

  Set<Marker> _markers = {};

  // Load caterers dynamically from town names
  Future<void> _loadCaterers() async {
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('caterers').get();

    Set<Marker> catererMarkers = {};

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final townName = data['townName'] ?? 'Colombo';

      try {
        // Convert town name to latitude/longitude
        List<Location> locations = await locationFromAddress('$townName, Sri Lanka');
        if (locations.isNotEmpty) {
          LatLng position =
              LatLng(locations.first.latitude, locations.first.longitude);

          // Only show markers in Western Province
          if (position.latitude >= 6.5 &&
              position.latitude <= 7.5 &&
              position.longitude >= 79.7 &&
              position.longitude <= 80.2) {
            final name = data['businessName'] ?? "Caterer";

            catererMarkers.add(
              Marker(
                markerId: MarkerId(doc.id),
                position: position,
                infoWindow: InfoWindow(title: name),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CatererDetailsPage(catererId: doc.id),
                    ),
                  );
                },
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error geocoding $townName: $e');
      }
    }

    setState(() {
      _markers = catererMarkers;
    });
  }

  // Search location typed by the user
  void _searchLocation() async {
    String query = _locationController.text.trim();
    if (query.isEmpty) return;

    try {
      List<Location> locations = await locationFromAddress('$query, Sri Lanka');
      if (locations.isNotEmpty) {
        LatLng newPosition =
            LatLng(locations.first.latitude, locations.first.longitude);

        if (newPosition.latitude >= 6.5 &&
            newPosition.latitude <= 7.5 &&
            newPosition.longitude >= 79.7 &&
            newPosition.longitude <= 80.2) {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(newPosition, 12),
          );
          _loadCaterers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location is outside Western Province!")),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location not found!")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCaterers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kMaincolor,
        centerTitle: true,
        title: const Text(
          "Search Location",
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const CustomerHomePage()),
            );
          },
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      hintText: "Enter your location",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _searchLocation,
                  icon: const Icon(Icons.search),
                  color: kMaincolor,
                )
              ],
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition:
                  CameraPosition(target: _initialPosition, zoom: _zoomLevel),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              markers: _markers,
            ),
          ),
        ],
      ),
    );
  }
}
