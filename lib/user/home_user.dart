import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';


class HomeUser extends StatefulWidget {
  final String collegeName;

  const HomeUser({super.key, required this.collegeName});

  @override
  State<HomeUser> createState() => _HomeUserState();

}

class _HomeUserState extends State<HomeUser> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("admin");
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? studentName;
  String? studentKey;
  String? qrCodeValue;
  bool isLoading = true;

  String? currentMeal;
  String? currentMenu;
  TimeOfDay? currentMealTime;
  bool attendanceOpen = false;
  bool isActive = false;

  bool alreadyRegistered = false;

  bool isRefreshing = false;


  @override
  void initState() {
    super.initState();
    fetchStudentData();
    fetchMealData();
  }

  Future<void> _refreshHome() async {
    if (isRefreshing) return;

    setState(() {
      isRefreshing = true;
      alreadyRegistered = false;
      attendanceOpen = false;
    });

    try {
      await fetchStudentData();
      await fetchMealData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Failed to refresh data")),
      );
    } finally {
      if (mounted) {
        setState(() {
          isRefreshing = false;
        });
      }
    }
  }


  /// 🔹 Fetch student info + QR + Active from RTDB
  Future<void> fetchStudentData() async {
    if (currentUser == null) return;

    final studentRef = _dbRef.child(widget.collegeName).child("students");
    final snapshot = await studentRef.get();

    if (snapshot.exists) {
      for (var student in snapshot.children) {
        final email = student
            .child("email")
            .value
            ?.toString() ?? "";
        if (email == currentUser!.email) {
          final name = student
              .child("name")
              .value
              ?.toString() ?? "Unknown";
          final qrValue = student
              .child("qrCode")
              .value
              ?.toString();
          final activeVal = student
              .child("Active")
              .value;
          final validUntilStr = student
              .child("validUntil")
              .value
              ?.toString();

          bool active = activeVal == true;
          if (validUntilStr != null) {
            final validUntil = DateTime.tryParse(validUntilStr);
            if (validUntil != null && DateTime.now().isAfter(validUntil)) {
              // 🔹 Expired → reset to false in RTDB
              await studentRef.child(student.key!).update({"Active": false});
              active = false;
            }
          }

          setState(() {
            studentName = name;
            studentKey = student.key;
            qrCodeValue = qrValue ?? "";
            isActive = active;
            isLoading = false;
          });

          // If QR missing → generate and save
          if (qrCodeValue == null || qrCodeValue!.isEmpty) {
            final newQr = "${currentUser!.uid}_${Random().nextInt(999999)}";
            await studentRef.child(student.key!).update({
              "qrCode": newQr,
              "Active": false,
            });
            setState(() {
              qrCodeValue = newQr;
            });
          }
          break;
        }
      }
    }
  }


  /// 🔹 Fetch timetable meal info
  Future<void> fetchMealData() async {
    final timetableRef = _dbRef.child(widget.collegeName).child("timetable");
    final snapshot = await timetableRef.get();
    if (!snapshot.exists) return;

    final now = DateTime.now();

    for (var meal in snapshot.children) {
      final mealName = meal.key ?? "";
      final menu = meal
          .child("menu")
          .value
          ?.toString() ?? "";
      final timeStr = meal
          .child("time")
          .value
          ?.toString() ?? "";

      if (timeStr.isEmpty) continue;

      final parts = timeStr.split(":");
      final mealTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );

      final startWindow = mealTime.subtract(const Duration(hours: 3));
      final endWindow = mealTime.add(const Duration(hours: 1, minutes: 30));

      if (now.isAfter(startWindow) && now.isBefore(endWindow)) {
        setState(() {
          currentMeal = mealName;
          currentMenu = menu;
          currentMealTime =
              TimeOfDay(hour: mealTime.hour, minute: mealTime.minute);
          attendanceOpen = true;
        });

        // 🔹 Check Firestore if already registered
        final today = DateFormat("yyyy-MM-dd").format(now);
        final doc = await _firestore
            .collection("colleges")
            .doc(widget.collegeName)
            .collection(mealName)
            .doc(today)
            .collection("students")
            .doc(currentUser!.uid)
            .get();

        if (doc.exists) {
          setState(() {
            alreadyRegistered = true;
          });
        }

        return;
      }
    }

    setState(() {
      attendanceOpen = false;
    });
  }


  /// 🔹 Mark attendance → RTDB (Active) + Firestore (record)
  Future<void> markAttendance() async {
    if (studentKey == null || studentName == null || currentMeal == null)
      return;

    final studentRef = _dbRef.child(widget.collegeName).child("students").child(
        studentKey!);

    setState(() {
      alreadyRegistered = true;
    });

    // ✅ Calculate new expiry time
    final mealTime = DateTime(
      DateTime
          .now()
          .year,
      DateTime
          .now()
          .month,
      DateTime
          .now()
          .day,
      currentMealTime!.hour,
      currentMealTime!.minute,
    );

    final deactivateTime = mealTime.add(const Duration(hours: 1));

    // ✅ Update RTDB with Active + validUntil
    await studentRef.update({
      "Active": true,
      "validUntil": deactivateTime.toIso8601String(),
    });

    setState(() {
      isActive = true;
    });

    // ✅ Save attendance in Firestore
    final today = DateFormat("yyyy-MM-dd").format(DateTime.now());
    await _firestore
        .collection("colleges")
        .doc(widget.collegeName)
        .collection(currentMeal!)
        .doc(today)
        .collection("students")
        .doc(currentUser!.uid)
        .set({
      "name": studentName,
      "email": currentUser!.email,
      "qrCode": qrCodeValue,
      "present": false,
      "timestamp": FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ You has been registered for the $currentMeal")),
    );
  }


  @override
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery
        .of(context)
        .size
        .height;

    return WillPopScope(
        onWillPop: () async {
          SystemNavigator.pop();
          return false;
        },
      child: Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshHome,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.lightBlueAccent, Colors.white70, Colors.white],
            ),
          ),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: height,
              child: Column(
                children: [

                  /// 🔹 Pull to refresh hint (TOP)
                  const Padding(
                    padding: EdgeInsets.only(top: 50),
                    child: Text(
                      "Pull to refresh",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  /// 🔹 Top 50% → QR + Active/Inactive
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          studentName ?? "User",
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.collegeName,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (qrCodeValue != null)
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              QrImageView(
                                data: qrCodeValue!,
                                size: height * 0.25,
                                backgroundColor: Colors.white,
                              ),
                              if (!isActive)
                                Positioned.fill(
                                  child: Container(
                                    alignment: Alignment.center,
                                    color: Colors.white.withOpacity(0.99),
                                    child: const Text(
                                      "DEACTIVE",
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  /// 🔹 Bottom 30% → Meal card
                  SizedBox(
                    height: height * 0.35,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: height * 0.1,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Colors.lightBlueAccent, Colors.white],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: attendanceOpen && currentMeal != null
                                    ? Column(
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ("$currentMeal").toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 6),

                                    Text(
                                      "Menu: ${currentMenu ?? "Not available"}",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    const SizedBox(height: 12),
                                    alreadyRegistered
                                        ? Text(
                                      "You have registered for this $currentMeal",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight:
                                        FontWeight.w500,
                                        color:
                                        Colors.yellowAccent,
                                      ),
                                    )
                                        : ElevatedButton.icon(
                                      onPressed:
                                      markAttendance,
                                      style: ElevatedButton
                                          .styleFrom(
                                        backgroundColor:
                                        Colors.white,
                                        foregroundColor:
                                        Colors.blue,
                                        shape:
                                        RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius
                                              .circular(
                                              12),
                                        ),
                                      ),
                                      label: const Text(
                                          "Mark Attendance"),
                                    ),
                                  ],
                                )
                                    : const Center(
                                  child: Text(
                                    "No active meal right now",
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                            ),

                            /// 🔹 Image
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                              child: Image.asset(
                                "assets/default_food.jpg",
                                width: height * 0.2,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
