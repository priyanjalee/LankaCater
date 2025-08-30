// location_search_page.dart - FULLY CORRECTED VERSION
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/colors.dart';

import 'caterer_details_page.dart';

class LocationSearchPage extends StatefulWidget {
  const LocationSearchPage({super.key});

  @override
  State<LocationSearchPage> createState() => _LocationSearchPageState();
}

class _LocationSearchPageState extends State<LocationSearchPage> {
  final MapController _mapController = MapController();
  LatLng? selectedLocation;
  final TextEditingController _searchController = TextEditingController();
  List<Marker> catererMarkers = [];
  bool isLoading = false;

  final LatLng westernProvinceCenter = LatLng(6.9271, 79.8612);
  final LatLng southWest = LatLng(6.6400, 79.7500);
  final LatLng northEast = LatLng(7.2900, 80.1000);

  final Distance distance = Distance();

  bool _isInsideWesternProvince(LatLng point) {
    return point.latitude >= southWest.latitude &&
        point.latitude <= northEast.latitude &&
        point.longitude >= southWest.longitude &&
        point.longitude <= northEast.longitude;
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      isLoading = true;
    });

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final point = LatLng(loc.latitude, loc.longitude);

        if (_isInsideWesternProvince(point)) {
          setState(() {
            selectedLocation = point;
            catererMarkers = [];
          });
          _mapController.move(point, 12);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location found! Tap "Find Nearby Caterers" to search for caterers.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a location within Western Province.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No location found for your search.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location not found. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Better method to get caterer business name
  String _getCatererName(Map<String, dynamic> data) {
    // Priority order for name fields - businessName first
    return data['businessName']?.toString().trim() ?? 
           data['name']?.toString().trim() ?? 
           data['catererName']?.toString().trim() ??
           data['companyName']?.toString().trim() ??
           data['shopName']?.toString().trim() ??
           'Unknown Business';
  }

  // Safe method to extract coordinates from Firestore data
  Map<String, double?> _extractCoordinates(Map<String, dynamic> data) {
    double? lat, lng;
    
    try {
      // Method 1: Check if location object exists with lat/lng
      if (data['location'] != null) {
        final locationValue = data['location'];
        
        // Check if location is a Map (GeoPoint or custom object)
        if (locationValue is Map<String, dynamic>) {
          lat = locationValue['lat'] as double? ?? locationValue['latitude'] as double?;
          lng = locationValue['lng'] as double? ?? locationValue['longitude'] as double?;
        }
        // Check if location is a GeoPoint
        else if (locationValue is GeoPoint) {
          lat = locationValue.latitude;
          lng = locationValue.longitude;
        }
        // If location is a string, skip it (can't extract coordinates from string address)
        else if (locationValue is String) {
          print('DEBUG: Location field contains string: $locationValue');
        }
      }
      
      // Method 2: Check for direct latitude/longitude fields
      if (lat == null || lng == null) {
        lat = lat ?? (data['latitude'] as double?);
        lng = lng ?? (data['longitude'] as double?);
      }
      
      // Method 3: Check for direct lat/lng fields
      if (lat == null || lng == null) {
        lat = lat ?? (data['lat'] as double?);
        lng = lng ?? (data['lng'] as double?);
      }
      
      // Method 4: Check for GeoPoint field
      if (lat == null || lng == null) {
        final geoPoint = data['geoPoint'] as GeoPoint?;
        if (geoPoint != null) {
          lat = geoPoint.latitude;
          lng = geoPoint.longitude;
        }
      }
      
    } catch (e) {
      print('DEBUG: Error extracting coordinates: $e');
      print('DEBUG: Data structure: $data');
    }
    
    return {'lat': lat, 'lng': lng};
  }

  Future<void> _loadNearbyCaterers() async {
    if (selectedLocation == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      print('DEBUG: Selected location: ${selectedLocation!.latitude}, ${selectedLocation!.longitude}');
      
      final snapshot = await FirebaseFirestore.instance
          .collection('caterers')
          .get();
      
      print('DEBUG: Total caterers in database: ${snapshot.docs.length}');
      
      final List<Marker> nearby = [];
      final List<Map<String, dynamic>> debugInfo = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        print('DEBUG: Document ${doc.id}: $data');
        
        // Use the safe coordinate extraction method
        final coordinates = _extractCoordinates(data);
        final lat = coordinates['lat'];
        final lng = coordinates['lng'];
        
        // Use the improved name getter
        final businessName = _getCatererName(data);
        final catererDocId = doc.id;
        
        print('DEBUG: Business $businessName - final lat: $lat, lng: $lng');
        
        if (lat != null && lng != null) {
          final catererPoint = LatLng(lat, lng);
          
          // Calculate distance using the working method
          final km = distance(selectedLocation!, catererPoint) / 1000;
          
          print('DEBUG: Distance to $businessName: ${km.toStringAsFixed(2)} km');
          
          // Store debug info
          debugInfo.add({
            'name': businessName,
            'lat': lat,
            'lng': lng,
            'distance': km,
            'withinRange': km <= 5,
          });
          
          // Show caterers within 10km for debugging (5km for actual use)
          if (km <= 10) {
            nearby.add(
              Marker(
                point: catererPoint,
                width: 70,
                height: 70,
                child: GestureDetector(
                  onTap: () => _onCatererTapped(catererDocId, data, businessName, km),
                  child: Column(
                    children: [
                      // Business name label
                      Container(
                        constraints: const BoxConstraints(maxWidth: 120),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                          border: Border.all(
                            color: km <= 5 ? Colors.blue : Colors.orange,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          businessName,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: km <= 5 ? Colors.blue : Colors.orange,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Restaurant icon
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: km <= 5 ? Colors.blue : Colors.orange,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.restaurant,
                          color: km <= 5 ? Colors.blue : Colors.orange,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        } else {
          print('DEBUG: Invalid coordinates for caterer $businessName - lat: $lat, lng: $lng');
          print('DEBUG: Available fields in document: ${data.keys.toList()}');
        }
      }

      setState(() {
        catererMarkers = nearby;
      });
      
      print('DEBUG: Found ${nearby.length} caterers within 10km');
      print('DEBUG: All distances: $debugInfo');
      
      // Show result message
      if (nearby.isNotEmpty) {
        final within5km = debugInfo.where((c) => c['withinRange'] == true).length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${nearby.length} caterers within 10km ($within5km within 5km)\nTap on any caterer to view details!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No caterers found nearby. Try a different location.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error loading caterers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading caterers: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // CORRECTED: Direct navigation to caterer detail page
  void _onCatererTapped(String catererDocId, Map<String, dynamic> data, String businessName, double km) {
    try {
      // Direct navigation - this will work immediately
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CatererDetailsPage(
            catererId: catererDocId,
            // Pass all the data the detail page might need
            initialData: {
              'businessName': businessName,
              'distance': km,
              'catererData': data,
              'location': selectedLocation,
            }, customerId: '',
          ),
        ),
      );
      
      print('DEBUG: Navigating to caterer detail for: $businessName (ID: $catererDocId)');
    } catch (e) {
      print('DEBUG: Navigation error: $e');
      // Fallback: Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open $businessName details. Error: $e'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _onCatererTapped(catererDocId, data, businessName, km),
          ),
        ),
      );
    }
  }

  void _onConfirmLocation() async {
    if (selectedLocation != null) {
      await _loadNearbyCaterers();
      _mapController.move(selectedLocation!, 12);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a location on the map first.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _clearSearch() {
    setState(() {
      selectedLocation = null;
      catererMarkers = [];
      _searchController.clear();
    });
    _mapController.move(westernProvinceCenter, 10);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Search cleared'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 1),
      ),
    );
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Find Nearby Caterers',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: kMaincolor,
        actions: [
          if (selectedLocation != null || catererMarkers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.white),
              onPressed: _clearSearch,
              tooltip: 'Clear search',
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search Section
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Search for a location in Western Province:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Enter location (e.g., Colombo, Gampaha)...',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide.none,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  isLoading ? Icons.hourglass_empty : Icons.search,
                                  color: kMaincolor,
                                ),
                                onPressed: isLoading ? null : _searchLocation,
                              ),
                            ),
                            onSubmitted: (_) => isLoading ? null : _searchLocation(),
                            enabled: !isLoading,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Map Section
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: westernProvinceCenter,
                    initialZoom: 10.0,
                    minZoom: 9.0,
                    maxZoom: 18.0,
                    onTap: (tapPosition, point) {
                      if (isLoading) return;
                      
                      if (_isInsideWesternProvince(point)) {
                        setState(() {
                          selectedLocation = point;
                          catererMarkers = []; // Clear previous caterer markers
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Location selected! Tap "Find Nearby Caterers" to search.'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a location within Western Province.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                      userAgentPackageName: "com.example.lankacater",
                    ),
                    
                    // Selected location marker
                    if (selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: selectedLocation!,
                            width: 50,
                            height: 50,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                    ),
                                ],
                                border: Border.all(
                                  color: Colors.red,
                                  width: 3,
                                ),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 30,
                              ),
                            ),
                          ),
                        ],
                      ),
                    
                    // Caterer markers
                    if (catererMarkers.isNotEmpty)
                      MarkerLayer(
                        markers: catererMarkers,
                      ),
                  ],
                ),
              ),
            ],
          ),
          
          // Loading overlay
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Searching...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      
      // Bottom action button
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kMaincolor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            elevation: 4,
          ),
          onPressed: isLoading ? null : _onConfirmLocation,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                const Icon(Icons.search_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                isLoading ? "Searching..." : "Find Nearby Caterers",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}