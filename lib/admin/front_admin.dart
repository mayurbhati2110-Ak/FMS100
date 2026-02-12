import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'home_admin.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FrontAdmin extends StatefulWidget {
  const FrontAdmin({super.key});

  @override
  State<FrontAdmin> createState() => _FrontAdminState();
}

class _FrontAdminState extends State<FrontAdmin> {
  String? selectedCollege;
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool isRefreshing = false;
  List<String> colleges = []; // initially empty

  @override
  void initState() {
    super.initState();
    fetchColleges();
  }

  /// 🔄 Fetch / Refresh colleges
  Future<void> fetchColleges({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => isRefreshing = true);
    }

    try {
      final dbRef = FirebaseDatabase.instance.ref("admin");
      final snapshot = await dbRef.get();

      if (snapshot.exists && snapshot.value is Map) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final List<String> fetchedColleges = [];

        data.forEach((key, value) {
          final adminMap = Map<String, dynamic>.from(value);
          final college = adminMap['collegeName'];

          if (college != null && !fetchedColleges.contains(college)) {
            fetchedColleges.add(college);
          }
        });

        setState(() {
          colleges = fetchedColleges;
          if (!colleges.contains(selectedCollege)) {
            selectedCollege = null;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Failed to refresh colleges")),
      );
    } finally {
      if (mounted) {
        setState(() => isRefreshing = false);
      }
    }
  }

  Future<void> loginAdmin() async {
    if (selectedCollege == null ||
        usernameController.text.isEmpty ||
        passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final dbRef = FirebaseDatabase.instance.ref("admin");
      final snapshot = await dbRef.get();

      bool found = false;

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        data.forEach((key, value) {
          final adminMap = Map<String, dynamic>.from(value);

          if (adminMap['collegeName'] == selectedCollege &&
              adminMap['username'] == usernameController.text &&
              adminMap['password'].toString() == passwordController.text) {
            found = true;
          }
        });
      }

      if (found) {
        await FirebaseAuth.instance.signInAnonymously();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("collegeName", selectedCollege!);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  HomeAdmin(collegeName: selectedCollege!)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid credentials")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return WillPopScope(
        onWillPop: () async => true,
        child: Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.lightBlueAccent, Colors.grey, Colors.white],
              ),
            ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              SizedBox(height: height * 0.1),
              const Text(
                "Welcome Admin",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                "Enter your credentials to continue",
                style: TextStyle(fontSize: 16, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: "Select College",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                value: selectedCollege,
                items: colleges
                    .map((college) => DropdownMenuItem(
                  value: college,
                  child: Text(college),
                ))
                    .toList(),
                onChanged: (val) => setState(() => selectedCollege = val),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: "Username",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: "Password",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loginAdmin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.lightBlue,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Login",
                    style: TextStyle(fontSize: 18, color: Colors.lightBlue),
                  ),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
        ),
    );
  }
}
