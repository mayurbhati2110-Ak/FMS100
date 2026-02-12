import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanCard extends StatefulWidget {
  final String collegeName;
  final String currentMeal;

  const ScanCard({
    super.key,
    required this.collegeName,
    required this.currentMeal,
  });

  @override
  State<ScanCard> createState() => _ScanCardState();
}

class _ScanCardState extends State<ScanCard> {
  bool isScanning = false;

  // 🔹 Get today’s date
  String get today =>
      "${DateTime
          .now()
          .year}-${DateTime
          .now()
          .month
          .toString()
          .padLeft(2, '0')}-${DateTime
          .now()
          .day
          .toString()
          .padLeft(2, '0')}";

  // 🔹 Attendance Stream
  Stream<QuerySnapshot>? get presentStream {
    if (widget.currentMeal == "No active meal right now" ||
        widget.currentMeal == "Loading...") {
      return null;
    }
    return FirebaseFirestore.instance
        .collection("colleges")
        .doc(widget.collegeName)
        .collection(widget.currentMeal.toLowerCase())
        .doc(today)
        .collection("students")
        .where("present", isEqualTo: true)
        .snapshots();
  }

  // 🔹 Open QR scanner
  Future<void> scanAndMarkPresent() async {
    if (widget.currentMeal == "No active meal right now") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No active meal right now")),
      );
      return;
    }

    setState(() => isScanning = true);

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            height: 400,
            child: MobileScanner(
              onDetect: (capture) async {
                final barcodes = capture.barcodes;
                if (barcodes.isEmpty) return;

                final scannedCode = barcodes.first.rawValue ?? "";

                Navigator.of(context).pop(); // close scanner
                await handleScannedCode(scannedCode);
              },
            ),
          ),
        );
      },
    );

    setState(() => isScanning = false);
  }

  Future<void> handleScannedCode(String scannedCode) async {
    try {
      final ref = FirebaseFirestore.instance
          .collection("colleges")
          .doc(widget.collegeName)
          .collection(widget.currentMeal.toLowerCase())
          .doc(today)
          .collection("students");

      final snapshot =
      await ref.where("qrCode", isEqualTo: scannedCode).limit(1).get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final docId = doc.id;

        if (doc["present"] == true) {
          // ✅ Already marked
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Attendance already marked 🟡")),
          );
        } else {
          // ✅ Mark present now
          await ref.doc(docId).update({"present": true});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Attendance marked ✅")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Not registered for this meal")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery
        .of(context)
        .size
        .width;
    final height = MediaQuery
        .of(context)
        .size
        .height;

    return Container(
      height: height * 0.2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Colors.lightBlueAccent, Colors.white],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 🔹 Scan Button
          GestureDetector(
            onTap: scanAndMarkPresent,
            child: Container(
              width: width * 0.45,
              height: height * 0.15,
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: isScanning
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  "Scan for Current Meal",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 20),

          // 🔹 Right Side Content (meal-aware)
          Expanded(
            child: Builder(
              builder: (context) {
                // 🟡 No active meal → no loader
                if (widget.currentMeal == "No active meal right now") {
                  return const Center(
                    child: Text(
                      "Wait for the Meal",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                // 🔵 Meal still loading
                if (widget.currentMeal == "Loading...") {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                // 🟢 Active meal → live Firestore count
                return StreamBuilder<QuerySnapshot>(
                  stream: presentStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }

                    final count = snapshot.data!.docs.length;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Present Students",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "$count",
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
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
