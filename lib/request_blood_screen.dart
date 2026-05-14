import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'notification_v1.dart';

class RequestBloodScreen extends StatefulWidget {
  const RequestBloodScreen({super.key});

  @override
  State<RequestBloodScreen> createState() => _RequestBloodScreenState();
}

class _RequestBloodScreenState extends State<RequestBloodScreen> {
  String selectedBloodType = 'A+';
  final List<String> bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  final TextEditingController _unitsController = TextEditingController(text: "1");
  final TextEditingController _locationController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLocating = false;

  @override
  void dispose() {
    _unitsController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // 📍 GPS LOCATE LOGIC
  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _locationController.text = "${place.locality}, ${place.country}";
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("GPS Error: $e")));
    } finally {
      setState(() => _isLocating = false);
    }
  }

  // 📍 UPDATED SEND REQUEST LOGIC
  Future<void> _sendRequest() async {
    if (_unitsController.text.isEmpty || _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill in units and location")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      var userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      var userData = userDoc.data();

      // 1. Save request to Firestore
      DocumentReference requestRef = await FirebaseFirestore.instance.collection('requests').add({
        'requesterId': user.uid,
        'requesterName': userData?['name'] ?? "Someone",
        'requestedBloodType': selectedBloodType,
        'unitsNeeded': _unitsController.text,
        'locationName': _locationController.text,
        'lat': userData?['lat'],
        'lng': userData?['lng'],
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. 📍 TRIGGER BROADCAST NOTIFICATION
      // This sends a notification to the 'blood_alerts' topic via FCM
      await NotificationV1.sendBroadcast(
        requestRef.id, 
        selectedBloodType, 
        userData?['name'] ?? "Someone"
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request Posted Successfully!"), backgroundColor: Colors.green)
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Request Blood", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Emergency Request", 
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 30),

            const Text("Required Blood Type", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildDropdown(),

            const SizedBox(height: 25),

            const Text("Units Needed", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildTextField(_unitsController, "e.g. 2", Icons.opacity),

            const SizedBox(height: 25),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Location / Hospital Name", style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _isLocating ? null : _getCurrentLocation,
                  icon: _isLocating
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location, size: 18, color: Colors.blue),
                  label: const Text("Use Current", style: TextStyle(color: Colors.blue, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 5),
            _buildTextField(_locationController, "e.g. Colombo National Hospital", Icons.location_city),

            const SizedBox(height: 50),

            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300), 
        borderRadius: BorderRadius.circular(12)
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedBloodType,
          isExpanded: true,
          items: bloodTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (val) => setState(() => selectedBloodType = val!),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, color: Colors.red),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: BorderSide(color: Colors.grey.shade300)
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _sendRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 2,
        ),
        child: _isSubmitting
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text("POST EMERGENCY", 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}