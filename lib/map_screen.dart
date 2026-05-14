import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart'; // 📍 Ensure geolocator is in pubspec.yaml

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _pickedLocation;
  String _address = "";
  bool _isLocating = false;

  // 📍 Function to fetch current GPS coordinates
  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        LatLng currentLatLng = LatLng(position.latitude, position.longitude);
        
        // Move camera to user's location
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(currentLatLng, 15),
        );

        // Automatically select this spot
        _selectLocation(currentLatLng);
      }
    } catch (e) {
      debugPrint("GPS Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not get location: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _selectLocation(LatLng position) async {
    setState(() => _pickedLocation = position);

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _address = "${place.locality ?? place.subAdministrativeArea}, ${place.country}";
        });
      }
    } catch (e) {
      setState(() => _address = "Selected Location");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          if (_pickedLocation != null)
            IconButton(
              icon: const Icon(Icons.check, size: 30),
              onPressed: () {
                Navigator.pop(context, {
                  'lat': _pickedLocation!.latitude,
                  'lng': _pickedLocation!.longitude,
                  'address': _address,
                });
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(6.9271, 79.8612), // Default Colombo
              zoom: 12.0,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: _selectLocation,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // We use our custom button
            markers: _pickedLocation == null
                ? {}
                : {
                    Marker(
                      markerId: const MarkerId('picked'),
                      position: _pickedLocation!,
                    ),
                  },
          ),
          // 📍 Floating "Use GPS" Button
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton.extended(
              onPressed: _isLocating ? null : _getCurrentLocation,
              backgroundColor: Colors.red,
              icon: _isLocating 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.my_location, color: Colors.white),
              label: const Text("Use GPS", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}