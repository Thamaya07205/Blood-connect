import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng _pickedLocation = const LatLng(6.9271, 79.8612); // Default: Colombo

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pick Your Location"),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => Navigator.pop(context, _pickedLocation),
          )
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: _pickedLocation, zoom: 14),
        onTap: (position) {
          setState(() => _pickedLocation = position);
        },
        markers: {
          Marker(markerId: const MarkerId("picked"), position: _pickedLocation),
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context, _pickedLocation),
        label: const Text("Confirm Location"),
        icon: const Icon(Icons.location_on),
        backgroundColor: Colors.red,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}