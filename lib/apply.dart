import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ApplyPage extends StatefulWidget {
  const ApplyPage({super.key});

  @override
  State<ApplyPage> createState() => _ApplyPageState();
}

class _ApplyPageState extends State<ApplyPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController collegeController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  bool isLoading = false;

  Future<void> _submitDetails() async {
    if (!_formKey.currentState!.validate()) return;

    final college = collegeController.text.trim();
    final mobile = mobileController.text.trim();
    final email = emailController.text.trim();

    final subject = Uri.encodeComponent("New Application for Food Saving System");
    final body = Uri.encodeComponent(
        "College Name: $college\nMobile Number: $mobile\nEmail: $email\n");

    final mailtoUrl = "mailto:mayurbhati519@gmail.com?subject=$subject&body=$body";

    if (await canLaunchUrl(Uri.parse(mailtoUrl))) {
      await launchUrl(Uri.parse(mailtoUrl));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open email app")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            const Text(
              "Apply",
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 10),
            const Text(
              "Give these details and our team will contact you for further processing",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // 🔹 College Name
                  TextFormField(
                    controller: collegeController,
                    decoration: InputDecoration(
                      labelText: "College Name",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Please enter college name";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // 🔹 Mobile Number
                  TextFormField(
                    controller: mobileController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Mobile Number",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Please enter mobile number";
                      }
                      if (!RegExp(r'^\d{10}$').hasMatch(value.trim())) {
                        return "Mobile number must be 10 digits";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // 🔹 Email
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: "Email",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Please enter email";
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$')
                          .hasMatch(value.trim())) {
                        return "Enter a valid email";
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.lightBlue,
                  padding:
                  const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Submit Details",
                  style: TextStyle(fontSize: 18, color: Colors.lightBlue),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
