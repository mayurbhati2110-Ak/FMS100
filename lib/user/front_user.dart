import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';



import 'home_user.dart';

class FrontUser extends StatefulWidget {
  const FrontUser({super.key});

  @override
  State<FrontUser> createState() => _FrontUserState();
}

class _FrontUserState extends State<FrontUser> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("admin");

  String? selectedCollege;
  List<String> collegeList = [];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchColleges();
  }

  Future<void> fetchColleges() async {
    final snapshot = await _dbRef.get();
    if (snapshot.exists) {
      List<String> colleges = [];
      for (var college in snapshot.children) {
        final collegeName = college.child("collegeName").value?.toString();
        if (collegeName != null) colleges.add(collegeName);
      }
      setState(() {
        collegeList = colleges;
      });
    }
  }

  Future<void> handleLogin() async {
    if (selectedCollege == null ||
        nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // 🔹 Check student exists in RTDB
      final studentRef =
      _dbRef.child(selectedCollege!).child("students");
      final snapshot = await studentRef.get();

      bool found = false;
      if (snapshot.exists) {
        for (var student in snapshot.children) {
          final name = student.child("name").value?.toString() ?? "";
          final email = student.child("email").value?.toString() ?? "";
          final phone = student.child("phone").value?.toString() ?? "";
          final enteredName = nameController.text.trim().toLowerCase();



          if (name.trim().toLowerCase() == enteredName &&
              email == emailController.text.trim() &&
              phone == phoneController.text.trim()) {
            found = true;
            break;
          }
        }
      }

      if (!found) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User not found in student list")),
        );
        setState(() => isLoading = false);
        return;
      }

      // 🔹 Register or Login in Firebase Auth
      UserCredential userCredential;
      try {
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: phoneController.text.trim(), // phone as password
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == "email-already-in-use") {
          userCredential = await _auth.signInWithEmailAndPassword(
            email: emailController.text.trim(),
            password: phoneController.text.trim(),
          );
        } else {
          rethrow;
        }
      }

      if (userCredential.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("userCollegeName", selectedCollege!);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeUser(collegeName: selectedCollege!)),
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

    return Scaffold(
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
                "Welcome User",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                "Enter your credentials to continue",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // 🔹 College Dropdown
              DropdownButtonFormField<String>(
                value: selectedCollege,
                items: collegeList
                    .map((college) => DropdownMenuItem(
                  value: college,
                  child: Text(college),
                ))
                    .toList(),
                onChanged: (val) {
                  setState(() => selectedCollege = val);
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: "Select College",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 🔹 Name
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: "Name",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 🔹 Email
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: "Email",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 🔹 Phone
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: "Phone",
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
                  onPressed: handleLogin,
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
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.lightBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}
