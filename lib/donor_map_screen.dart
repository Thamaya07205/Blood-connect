import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart'; // 📍 Ensure this is in your pubspec.yaml

class DonorMapScreen extends StatefulWidget {
  const DonorMapScreen({super.key});

  @override
  State<DonorMapScreen> createState() => _DonorMapScreenState();
}

class _DonorMapScreenState extends State<DonorMapScreen> {
  late GoogleMapController _mapController;
  Set<Marker> _markers = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDonorsOnMap();
  }

  // Logic to search for a place in Sri Lanka
  Future<void> _searchAndMoveToLocation(String address) async {
    if (address.isEmpty) return;

    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        Location result = locations.first;
        _mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(result.latitude, result.longitude),
              zoom: 14,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location not found. Try adding ', Sri Lanka'")),
        );
      }
    }
  }

  void _loadDonorsOnMap() async {
    try {
      var snapshot = await FirebaseFirestore.instance.collection('users').get();
      setState(() {
        _markers = snapshot.docs
            .where((doc) => doc.data().containsKey('lat') && doc.data().containsKey('lng'))
            .map((doc) {
          var data = doc.data();
          return Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(
              (data['lat']).toDouble(),
              (data['lng']).toDouble(),
            ),
            infoWindow: InfoWindow(
              title: data['name'] ?? "Donor",
              snippet: "Blood Type: ${data['bloodGroup'] ?? 'Unknown'}",
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          );
        }).toSet();
      });
    } catch (e) {
      debugPrint("Error loading markers: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Donor Map"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // 🗺️ The Map
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(6.9271, 79.8612), // Centers on Colombo
              zoom: 12,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onMapCreated: (controller) => _mapController = controller,
          ),

          // 🔍 The Search Bar UI
          Positioned(
            top: 15,
            left: 15,
            right: 15,
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search hospital or city...",
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Colors.red),
                    onPressed: () => _searchAndMoveToLocation(_searchController.text),
                  ),
                ),
                onSubmitted: (value) => _searchAndMoveToLocation(value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}