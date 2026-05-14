import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' show cos, sqrt, asin;

class SearchScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const SearchScreen({super.key, required this.userData});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String selectedFilter = 'All';
  final List<String> filterOptions = ['All', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  User? currentUser = FirebaseAuth.instance.currentUser;

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((lat2 - lat1) * p) / 2 + c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFD32F2F),
        title: const Text("Find Donors", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            color: const Color(0xFFD32F2F),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: filterOptions.map((f) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                                      label: Text(
                                        f, 
                                        style: TextStyle(
                                          // This ensures text is red when selected, and grey when NOT selected
                                          color: selectedFilter == f ? const Color(0xFFD32F2F) : Colors.black54, 
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      selected: selectedFilter == f,
                                      selectedColor: Colors.white, // Chip background when clicked
                                      backgroundColor: Colors.white.withOpacity(0.3), // Chip background when NOT clicked (semi-transparent looks better on red)
                                      checkmarkColor: const Color(0xFFD32F2F), // Color of the little check icon
                                      onSelected: (s) => setState(() => selectedFilter = f),
                                    )
                )).toList(),
              ),
            ),
          ),
          
          // Results List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: selectedFilter == 'All' 
                  ? FirebaseFirestore.instance.collection('users').snapshots() 
                  : FirebaseFirestore.instance.collection('users').where('bloodGroup', isEqualTo: selectedFilter).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                var donorDocs = snapshot.data!.docs.where((doc) => doc.id != currentUser?.uid).toList();

                // Sort by distance if user location is available
                if (widget.userData['lat'] != null) {
                  donorDocs.sort((a, b) {
                    var d1 = a.data() as Map<String, dynamic>;
                    var d2 = b.data() as Map<String, dynamic>;
                    double dist1 = (d1['lat'] != null) ? _calculateDistance(widget.userData['lat'], widget.userData['lng'], d1['lat'], d1['lng']) : 9999.0;
                    double dist2 = (d2['lat'] != null) ? _calculateDistance(widget.userData['lat'], widget.userData['lng'], d2['lat'], d2['lng']) : 9999.0;
                    return dist1.compareTo(dist2);
                  });
                }

                if (donorDocs.isEmpty) return const Center(child: Text("No donors found for this group."));

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: donorDocs.length,
                  itemBuilder: (context, index) {
                    var donor = donorDocs[index].data() as Map<String, dynamic>;
                    double? dist;
                    if (widget.userData['lat'] != null && donor['lat'] != null) {
                      dist = _calculateDistance(widget.userData['lat'], widget.userData['lng'], donor['lat'], donor['lng']);
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFFFEBEE),
                          child: Text(donor['bloodGroup'] ?? "?", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(donor['name'] ?? "User", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(dist != null ? "${dist.toStringAsFixed(1)} km away" : "Location unknown"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.phone, color: Colors.green), 
                              onPressed: () => launchUrl(Uri(scheme: 'tel', path: donor['phone']))
                            ),
                            IconButton(
                              icon: const Icon(Icons.email, color: Colors.red), 
                              onPressed: () => launchUrl(Uri(scheme: 'mailto', path: donor['email']))
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}