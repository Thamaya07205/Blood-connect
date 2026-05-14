import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:carousel_slider/carousel_slider.dart';

// --- PROJECT IMPORTS ---
import 'edit_profile_screen.dart';
import 'ai_chat_screen.dart';
import 'donor_map_screen.dart';
import 'request_blood_screen.dart';
import 'search_screen.dart';
import 'response_list_screen.dart'; 
import 'notification_v1.dart'; 
import 'main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  final List<Map<String, String>> motivationalAds = [
    {
      "title": "Save Lives Today",
      "subtitle": "One donation can save up to 3 lives",
      "image": "https://t3.ftcdn.net/jpg/03/09/20/22/360_F_309202280_CgsWoCAdLBe9INBvdwBKUkpaLEP4XNLa.jpg"
    },
    {
      "title": "Be a Hero",
      "subtitle": "Your blood donation is a gift of life",
      "image": "https://newsroompanama.com/wp-content/uploads/2024/08/blood.jpg"
    },
    {
      "title": "Emergency Ready",
      "subtitle": "Stay updated with urgent requests near you",
      "image": "https://marvel-b1-cdn.bc0a.com/f00000000290269/www.riversideonline.com/-/media/patients-and-visitors/healthy-you/blood-donation.png"
    },
  ];

  @override
  void initState() {
    super.initState();
    _setupNotificationInteractions();
  }

  void _setupNotificationInteractions() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _processMessage(initialMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_processMessage);
  }

  void _processMessage(RemoteMessage message) {
    if (message.data['type'] == 'blood_request') {
      debugPrint("User interacted with blood request: ${message.data['requestId']}");
    }
  }

  // 📍 UPDATED: Sends notification to the original requester
  Future<void> _acceptDonationRequest(String requestId, Map<String, dynamic> myData) async {
    try {
      // 1. Add response to Firestore
      await FirebaseFirestore.instance.collection('responses').add({
        'requestId': requestId,
        'donorId': currentUser!.uid,
        'donorName': myData['name'] ?? "Anonymous",
        'donorPhone': myData['phone'] ?? "",
        'donorGender': myData['gender'] ?? "N/A",
        'donorAge': myData['age'] ?? "N/A",
        'acceptedAt': FieldValue.serverTimestamp(),
        'lat': myData['lat'],
        'lng': myData['lng'],
      });

      // 2. Fetch the original request to find the requester
      DocumentSnapshot requestDoc = await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .get();
      
      if (requestDoc.exists) {
        String requesterId = requestDoc.get('requesterId');
        String bloodType = requestDoc.get('requestedBloodType');

        // 3. Get the requester's FCM Token
        DocumentSnapshot requesterUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(requesterId)
            .get();

        if (requesterUserDoc.exists) {
          String? targetToken = requesterUserDoc.get('fcmToken');

          if (targetToken != null) {
            // 4. Send the targeted notification
            await NotificationV1.sendResponseNotification(
              targetToken: targetToken,
              donorName: myData['name'] ?? "A donor",
              bloodType: bloodType,
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Success! Your contact info was sent."), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _onNavTap(int index, Map<String, dynamic> myData) {
    if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => SearchScreen(userData: myData)));
    } else if (index == 3) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const DonorMapScreen()));
    } else if (index == 2) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const RequestBloodScreen()));
    }
  }

  Future<void> _deletePost(String docId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Request"),
        content: const Text("Are you sure you want to remove this blood request?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('requests').doc(docId).delete();
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserData() async {
    return await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: getUserData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        var myData = snapshot.data?.data();
        if (myData == null) return const Scaffold(body: Center(child: Text("Complete your profile")));

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFFD32F2F),
            unselectedItemColor: Colors.grey,
            currentIndex: 0,
            onTap: (index) => _onNavTap(index, myData),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.water_drop), label: "Home"),
              BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
              BottomNavigationBarItem(icon: Icon(Icons.help_outline), label: "Request"),
              BottomNavigationBarItem(icon: Icon(Icons.location_on_outlined), label: "Near Me"),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFFE91E63),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AIChatScreen())),
            child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD32F2F),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.water_drop, color: Colors.white, size: 32),
                              const SizedBox(width: 10),
                              const Text(
                                "BloodConnect",
                                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfileScreen(currentData: myData))),
                            child: const CircleAvatar(
                              radius: 28, 
                              backgroundColor: Colors.white24,
                              child: Icon(Icons.person, color: Colors.white, size: 30),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Connecting donors, saving lives",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                CarouselSlider(
                  options: CarouselOptions(
                    height: 200,
                    autoPlay: true,
                    viewportFraction: 0.92,
                    enlargeCenterPage: true,
                    autoPlayInterval: const Duration(seconds: 5),
                  ),
                  items: motivationalAds.map((ad) {
                    return Builder(
                      builder: (BuildContext context) {
                        return Container(
                          width: MediaQuery.of(context).size.width,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            image: DecorationImage(
                              image: NetworkImage(ad['image']!),
                              fit: BoxFit.cover,
                              colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ad['title']!, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(ad['subtitle']!, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("What would you like to do?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 20),
                      _buildActionCard(
                        title: "Find Donors",
                        subtitle: "Search for blood donors nearby",
                        icon: Icons.search,
                        iconColor: const Color(0xFFD32F2F),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SearchScreen(userData: myData))),
                      ),
                      const SizedBox(height: 15),
                      _buildActionCard(
                        title: "Request Blood",
                        subtitle: "Submit urgent blood request",
                        icon: Icons.help_outline,
                        iconColor: Colors.white,
                        cardColor: const Color(0xFFD32F2F),
                        textColor: Colors.white,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RequestBloodScreen())),
                      ),
                      const SizedBox(height: 35),
                      const Text("Recent Blood Requests", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('requests').orderBy('createdAt', descending: true).limit(10).snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                          var docs = snapshot.data!.docs;
                          if (docs.isEmpty) return const Text("No requests found.", style: TextStyle(color: Colors.grey));
                          return Column(
                            children: docs.map((doc) => _buildRequestCard(doc.id, doc.data() as Map<String, dynamic>, myData)).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestCard(String docId, Map<String, dynamic> data, Map<String, dynamic> myData) {
    bool isMyPost = data['requesterId'] == currentUser?.uid; 

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(backgroundColor: const Color(0xFFE91E63), radius: 28, child: Text(data['requestedBloodType'] ?? "?", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['requesterName'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0D47A1))),
                      Row(
                        children: const [
                          Icon(Icons.access_time, size: 14, color: Colors.grey),
                          SizedBox(width: 4),
                          Text("Recently added", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFFCDD2))),
                child: const Text("URGENT", style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(height: 15),
              Row(children: [const Icon(Icons.water_drop_outlined, size: 18, color: Color(0xFFD32F2F)), const SizedBox(width: 8), Text("${data['unitsNeeded'] ?? '1'} units needed", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF37474F)))]),
              const SizedBox(height: 8),
              Row(children: [const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey), const SizedBox(width: 8), Expanded(child: Text(data['locationName'] ?? "Nearby Location", style: const TextStyle(fontSize: 14, color: Color(0xFF546E7A)), overflow: TextOverflow.ellipsis))]),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (isMyPost)
                    InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ResponseListScreen(requestId: docId))),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: const [
                            Icon(Icons.list_alt, color: Color(0xFF388E3C), size: 18),
                            SizedBox(width: 6),
                            Text("Volunteers", style: TextStyle(color: Color(0xFF388E3C), fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: isMyPost ? null : () => _acceptDonationRequest(docId, myData),
                    child: Text(
                      isMyPost ? "MY REQUEST" : "I CAN HELP",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isMyPost)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(color: Color(0xFFF5F5F5), shape: BoxShape.circle),
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFD32F2F), size: 20),
                  onPressed: () => _deletePost(docId),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionCard({required String title, required String subtitle, required IconData icon, required Color iconColor, required VoidCallback onTap, Color cardColor = Colors.white, Color textColor = Colors.black87}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: cardColor == Colors.white ? const Color(0xFFFFEBEE) : Colors.white24, shape: BoxShape.circle), child: Icon(icon, color: iconColor)),
            const SizedBox(width: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.7)))]))
          ],
        ),
      ),
    );
  }
}