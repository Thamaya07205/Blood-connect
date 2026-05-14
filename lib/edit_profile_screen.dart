import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart'; 
import 'map_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> currentData;

  const EditProfileScreen({super.key, required this.currentData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController phoneController;
  late TextEditingController ageController;
  
  late String selectedBloodGroup;
  String? selectedGender;
  bool isLoading = false;

  final List<String> bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> genders = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.currentData['name']);
    phoneController = TextEditingController(text: widget.currentData['phone'] ?? "");
    ageController = TextEditingController(text: widget.currentData['age'] ?? "");
    selectedBloodGroup = widget.currentData['bloodGroup'] ?? 'A+'; 
    selectedGender = widget.currentData['gender'];
  }

  // --- LOGOUT LOGIC ---
  Future<void> _handleLogout() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  // --- UPDATE PROFILE LOGIC ---
  Future<void> updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      // Capture new values
      String newName = nameController.text.trim();
      String newPhone = phoneController.text.trim();
      String newAge = ageController.text.trim();

      // Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': newName,
        'phone': newPhone,
        'age': newAge,
        'gender': selectedGender,
        'bloodGroup': selectedBloodGroup,
        'locationName': widget.currentData['locationName'],
        'lat': widget.currentData['lat'],
        'lng': widget.currentData['lng'],
      });

      // 📍 KEY FIX: Update local widget state so the UI (Header) reflects changes immediately
      setState(() {
        widget.currentData['name'] = newName;
        widget.currentData['phone'] = newPhone;
        widget.currentData['age'] = newAge;
        widget.currentData['gender'] = selectedGender;
        widget.currentData['bloodGroup'] = selectedBloodGroup;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile Updated!"), backgroundColor: Colors.green)
      );
      
      // Return to home screen
      Navigator.pop(context);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- DELETE ACCOUNT LOGIC ---
  Future<void> deleteAccount() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account?"),
        content: const Text("This action cannot be undone. You will lose your data permanently."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;
    setState(() => isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
      await user.delete();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed: Re-authentication required. Logout and login again.")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Profile Settings", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 40, top: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFD32F2F),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, color: Colors.white, size: 50),
                  ),
                  const SizedBox(height: 15),
                  Text(widget.currentData['name'] ?? "User", 
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(FirebaseAuth.instance.currentUser?.email ?? "", 
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle("Personal Details"),
                    _buildCard([
                      _buildInputField(nameController, "Full Name", Icons.person_outline),
                      const Divider(height: 1),
                      _buildInputField(phoneController, "Phone Number", Icons.phone_android_outlined, keyboard: TextInputType.phone),
                    ]),

                    const SizedBox(height: 25),
                    _buildSectionTitle("Health Information"),
                    _buildCard([
                      _buildDropdownField("Blood Group", Icons.bloodtype_outlined, selectedBloodGroup, bloodGroups, (val) => setState(() => selectedBloodGroup = val!)),
                      const Divider(height: 1),
                      _buildInputField(ageController, "Age", Icons.cake_outlined, keyboard: TextInputType.number),
                    ]),

                    const SizedBox(height: 25),
                    _buildSectionTitle("Location"),
                    _buildLocationCard(),

                    const SizedBox(height: 40),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD32F2F),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 2,
                        ),
                        child: isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("SAVE CHANGES", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),

                    const SizedBox(height: 25),
                    const Divider(),
                    const SizedBox(height: 15),

                    _buildLogoutButton(),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: isLoading ? null : deleteAccount,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("DELETE ACCOUNT", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 10),
      child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black54)),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label, IconData icon, {TextInputType keyboard = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFD32F2F)),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      ),
    );
  }

  Widget _buildDropdownField(String label, IconData icon, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: const Color(0xFFD32F2F)), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 15)),
      items: items.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildLocationCard() {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => const MapScreen())
        );
        if (result != null) {
          setState(() {
            widget.currentData['locationName'] = result['address'];
            widget.currentData['lat'] = result['lat'];
            widget.currentData['lng'] = result['lng'];
          });
        }
      },
      borderRadius: BorderRadius.circular(15),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            const CircleAvatar(backgroundColor: Color(0xFFFFEBEE), child: Icon(Icons.location_on, color: Color(0xFFD32F2F))),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Home Location", style: TextStyle(color: Colors.grey, fontSize: 11)),
                  Text(widget.currentData['locationName'] ?? "Not set", 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                ],
              ),
            ),
            const Icon(Icons.map_outlined, color: Color(0xFFD32F2F)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return InkWell(
      onTap: _handleLogout,
      borderRadius: BorderRadius.circular(15),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: const [
            Icon(Icons.logout_rounded, color: Colors.red),
            SizedBox(width: 15),
            Text("Logout", style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
            Spacer(),
            Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }
}