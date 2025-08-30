import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../../constants/colors.dart';

class CatererLocationPickPage extends StatefulWidget {
  final String userId;
  const CatererLocationPickPage({super.key, required this.userId});

  @override
  State<CatererLocationPickPage> createState() =>
      _CatererLocationPickPageState();
}

class _CatererLocationPickPageState extends State<CatererLocationPickPage> {
  LatLng? selectedLocation;
  final MapController _mapController = MapController();
  final LatLng westernProvinceCenter = LatLng(6.9271, 79.8612);

  final TextEditingController _searchController = TextEditingController();

  // Search using OpenStreetMap Nominatim
  Future<void> _searchLocation() async {
    if (_searchController.text.isEmpty) return;

    final query = _searchController.text;
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1');

    final response = await http.get(url, headers: {'User-Agent': 'FlutterApp'});
    if (response.statusCode == 200) {
      final results = jsonDecode(response.body) as List<dynamic>;
      if (results.isNotEmpty) {
        final lat = double.parse(results[0]['lat']);
        final lon = double.parse(results[0]['lon']);
        final newLocation = LatLng(lat, lon);

        setState(() {
          selectedLocation = newLocation;
        });

        _mapController.move(newLocation, 15);
      }
    }
  }

  Future<void> _saveLocation() async {
    if (selectedLocation == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('caterers')
          .doc(widget.userId)
          .set({
        'location': {
          'lat': selectedLocation!.latitude,
          'lng': selectedLocation!.longitude,
        }
      }, SetOptions(merge: true));

      // Show SnackBar in this page
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location updated!")),
        );
      }

      Navigator.pop(context, {
        'lat': selectedLocation!.latitude,
        'lng': selectedLocation!.longitude,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update location")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kMaincolor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Pick Your Location",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Enter location",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchLocation,
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: westernProvinceCenter,
                initialZoom: 10,
                minZoom: 9,
                maxZoom: 18,
                onTap: (tapPosition, LatLng point) {
                  setState(() {
                    selectedLocation = point;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: "com.example.lankacater",
                ),
                if (selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: selectedLocation!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: selectedLocation == null ? null : _saveLocation,
        icon: const Icon(Icons.save),
        label: const Text("Save Location"),
        backgroundColor: kMaincolor,
      ),
    );
  }
}
