import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' show cos, sqrt, asin;

class ResponseListScreen extends StatelessWidget {
  final String requestId;

  const ResponseListScreen({super.key, required this.requestId});

  // 📍 Matching Algorithm: Calculate distance between requester and donor
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Potential Donors"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 📍 Real-time listener for responses to this specific request
        stream: FirebaseFirestore.instance
            .collection('responses')
            .where('requestId', isEqualTo: requestId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.hourglass_empty, size: 60, color: Colors.grey),
                  SizedBox(height: 20),
                  Text("Waiting for donors to respond...",
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          // 📍 Get requester's location to perform the distance sort
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('requests').doc(requestId).get(),
            builder: (context, requestSnapshot) {
              if (!requestSnapshot.hasData) return const SizedBox();

              var requestData = requestSnapshot.data!.data() as Map<String, dynamic>;
              double reqLat = (requestData['lat'] ?? 0.0).toDouble();
              double reqLng = (requestData['lng'] ?? 0.0).toDouble();

              var donorResponses = snapshot.data!.docs.toList();

              // 📍 SAFE SORTING: Handled null current user location
              donorResponses.sort((a, b) {
                var dataA = a.data() as Map<String, dynamic>;
                var dataB = b.data() as Map<String, dynamic>;

                double distA = (dataA['lat'] != null && dataA['lng'] != null)
                    ? _calculateDistance(reqLat, reqLng, dataA['lat'].toDouble(), dataA['lng'].toDouble())
                    : 999999.0;

                double distB = (dataB['lat'] != null && dataB['lng'] != null)
                    ? _calculateDistance(reqLat, reqLng, dataB['lat'].toDouble(), dataB['lng'].toDouble())
                    : 999999.0;

                return distA.compareTo(distB);
              });

              return ListView.builder(
                padding: const EdgeInsets.all(15),
                itemCount: donorResponses.length,
                itemBuilder: (context, index) {
                  var donor = donorResponses[index].data() as Map<String, dynamic>;
                  
                  // 📍 SAFE DISTANCE CALCULATION
                  double? distance;
                  if (donor['lat'] != null && donor['lng'] != null) {
                    distance = _calculateDistance(reqLat, reqLng, donor['lat'].toDouble(), donor['lng'].toDouble());
                  }

                  // 📍 DISPLAY AGE AND GENDER
                  // These keys must match what you save in home_screen.dart (_acceptDonationRequest)
                  String gender = donor['donorGender'] ?? "N/A";
                  String age = donor['donorAge'] ?? "N/A";

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      leading: const CircleAvatar(
                        backgroundColor: Colors.red,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(donor['donorName'] ?? "Hero Donor",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      
                      // 📍 UPDATED SUBTITLE: Shows Age, Gender, and Distance
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text("$gender • $age Years Old", 
                              style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(
                            distance != null ? "${distance.toStringAsFixed(1)} km away" : "Location unknown",
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.phone, color: Colors.green, size: 30),
                        onPressed: () {
                          if (donor['donorPhone'] != null) {
                            launchUrl(Uri(scheme: 'tel', path: donor['donorPhone']));
                          }
                        },
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}