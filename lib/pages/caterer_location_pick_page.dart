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
  String? selectedAddress;
  String? displayAddress;
  final MapController _mapController = MapController();
  final LatLng westernProvinceCenter = LatLng(6.9271, 79.8612);
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  // Search using OpenStreetMap Nominatim
  Future<void> _searchLocation() async {
    if (_searchController.text.trim().isEmpty) {
      _showSnackBar("Please enter a location to search");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final query = Uri.encodeComponent(_searchController.text.trim());
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1&addressdetails=1');

      final response = await http.get(url, headers: {
        'User-Agent': 'LankaCater/1.0',
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        final results = jsonDecode(response.body) as List<dynamic>;
        if (results.isNotEmpty) {
          final result = results[0];
          final lat = double.parse(result['lat']);
          final lon = double.parse(result['lon']);
          final newLocation = LatLng(lat, lon);

          // Get the formatted address
          String formattedAddress = result['display_name'] ?? _searchController.text;
          
          setState(() {
            selectedLocation = newLocation;
            selectedAddress = _searchController.text.trim();
            displayAddress = formattedAddress;
          });

          _mapController.move(newLocation, 15);
          FocusScope.of(context).unfocus(); // Hide keyboard
        } else {
          _showSnackBar("Location not found. Please try a different search term.");
        }
      } else {
        _showSnackBar("Failed to search location. Please try again.");
      }
    } catch (e) {
      _showSnackBar("Error occurred while searching. Please check your internet connection.");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Reverse geocoding to get address from coordinates
  Future<void> _getAddressFromCoordinates(LatLng location) async {
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=${location.latitude}&lon=${location.longitude}&format=json');

      final response = await http.get(url, headers: {
        'User-Agent': 'LankaCater/1.0',
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        String address = result['display_name'] ?? 'Selected Location';
        
        setState(() {
          displayAddress = address;
          selectedAddress = address;
        });
      }
    } catch (e) {
      setState(() {
        displayAddress = 'Selected Location (${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)})';
        selectedAddress = displayAddress;
      });
    }
  }

  Future<void> _saveLocation() async {
    if (selectedLocation == null || selectedAddress == null) {
      _showSnackBar("Please select a location first");
      return;
    }

    // Show confirmation dialog
    bool? confirmSave = await _showConfirmationDialog();
    if (confirmSave != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('caterers')
          .doc(widget.userId)
          .set({
        'location': {
          'lat': selectedLocation!.latitude,
          'lng': selectedLocation!.longitude,
          'address': selectedAddress,
          'displayAddress': displayAddress,
          'updatedAt': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));

      if (mounted) {
        _showSnackBar("Location saved successfully!", isSuccess: true);
        
        // Delay navigation to show success message
        await Future.delayed(const Duration(seconds: 1));
        
        Navigator.pop(context, {
          'lat': selectedLocation!.latitude,
          'lng': selectedLocation!.longitude,
          'address': selectedAddress,
          'displayAddress': displayAddress,
        });
      }
    } catch (e) {
      _showSnackBar("Failed to save location. Please try again.");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool?> _showConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Location'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Save this location as your catering service area?'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Address:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayAddress ?? 'Selected Location',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Coordinates: ${selectedLocation!.latitude.toStringAsFixed(6)}, ${selectedLocation!.longitude.toStringAsFixed(6)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: kMaincolor),
              child: const Text('Save Location', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isSuccess ? Colors.green : null,
          duration: Duration(seconds: isSuccess ? 2 : 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kMaincolor,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Pick Your Location",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // Search Section
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: "Enter your business address...",
                          prefixIcon: const Icon(Icons.location_searching, color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: kMaincolor, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        onSubmitted: (_) => _searchLocation(),
                        textInputAction: TextInputAction.search,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: kMaincolor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: _isLoading 
                            ? const SizedBox(
                                width: 20, 
                                height: 20, 
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, 
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white)
                                )
                              )
                            : const Icon(Icons.search, color: Colors.white),
                        onPressed: _isLoading ? null : _searchLocation,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Selected Address Display
          if (selectedLocation != null && displayAddress != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Selected Location:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    displayAddress!,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lat: ${selectedLocation!.latitude.toStringAsFixed(6)}, Lng: ${selectedLocation!.longitude.toStringAsFixed(6)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

          // Map Section
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: westernProvinceCenter,
                    initialZoom: 10,
                    minZoom: 8,
                    maxZoom: 18,
                    onTap: (tapPosition, LatLng point) {
                      setState(() {
                        selectedLocation = point;
                      });
                      _getAddressFromCoordinates(point);
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
                            width: 50,
                            height: 50,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 50,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom instruction
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              "Tap on the map to select your exact location or search for your address above",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
      floatingActionButton: selectedLocation == null 
          ? null 
          : FloatingActionButton.extended(
              onPressed: _isLoading ? null : _saveLocation,
              icon: _isLoading 
                  ? const SizedBox(
                      width: 16, 
                      height: 16, 
                      child: CircularProgressIndicator(
                        strokeWidth: 2, 
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white)
                      )
                    )
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(
                _isLoading ? "Saving..." : "Save Location",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              backgroundColor: kMaincolor,
              elevation: 4,
            ),
    );
  }
}