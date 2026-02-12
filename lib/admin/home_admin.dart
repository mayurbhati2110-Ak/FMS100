import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'add_timetable.dart';
import 'upload.dart';
import 'meal_helper.dart';
import 'scan_card.dart';
import 'package:flutter/services.dart';
import 'admin_student.dart';




class HomeAdmin extends StatefulWidget {
  final String collegeName;

  const HomeAdmin({super.key, required this.collegeName});

  @override
  State<HomeAdmin> createState() => _HomeAdminState();
}

class _HomeAdminState extends State<HomeAdmin> {
  String currentMeal = "Loading...";
  int mealCount = 0;
  bool hasTimetable = false;
  bool hasStudents = false;
  bool isRefreshing = false;




  @override
  void initState() {
    super.initState();
    determineMeal();
    fetchData();
  }

  Future<void> determineMeal({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => isRefreshing = true);
    }
    try {
      final dbRef =
      FirebaseDatabase.instance.ref("admin/${widget.collegeName}/timetable");
      final snapshot = await dbRef.get();

      if (!snapshot.exists) {
        setState(() {
          currentMeal = "No timetable found";
        });
        return;
      }

      final timetable = Map<String, dynamic>.from(snapshot.value as Map);

      final now = DateTime.now();
      final breakfastTime = _parseTime(timetable["breakfast"]["time"]);
      final lunchTime = _parseTime(timetable["lunch"]["time"]);
      final dinnerTime = _parseTime(timetable["dinner"]["time"]);

      if (now.isAfter(breakfastTime.subtract(const Duration(hours: 3))) &&
          now.isBefore(breakfastTime.add(const Duration(hours: 1)))) {
        currentMeal = "Breakfast";
      } else if (now.isAfter(lunchTime.subtract(const Duration(hours: 3))) &&
          now.isBefore(lunchTime.add(const Duration(hours: 1)))) {
        currentMeal = "Lunch";
      } else if (now.isAfter(dinnerTime.subtract(const Duration(hours: 3))) &&
          now.isBefore(dinnerTime.add(const Duration(hours: 1)))) {
        currentMeal = "Dinner";
      } else {
        currentMeal = "No active meal right now";
      }

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Failed to fetch current meal")),
      );
    } finally {
      if (mounted) {
        setState(() => isRefreshing = false);
      }
    }
  }

  DateTime _parseTime(String timeString) {
    final parts = timeString.split(":");
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  Future<void> fetchData() async {
    try {
      final dbRef =
      FirebaseDatabase.instance.ref("admin/${widget.collegeName}");
      final snapshot = await dbRef.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        hasTimetable = data["timetable"] != null;
        hasStudents = data["students"] != null;

        if (currentMeal != "Loading..." &&
            currentMeal != "No active meal right now") {
          mealCount =
          await MealCountHelper.getMealCount(widget.collegeName, currentMeal);
        }

        setState(() {});
      }
    } catch (e) {
      print("Error fetching data: $e");
    }
  }
  Future<void> _refreshHome() async {
    if (isRefreshing) return;

    setState(() {
      isRefreshing = true;
    });

    try {
      // 🔄 Recalculate current meal
      await determineMeal(showLoader: false);

      // 🔄 Reload timetable + student status + meal count
      await fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Failed to refresh data")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isRefreshing = false;
        });
      }
    }
  }




  @override
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery
        .of(context)
        .size
        .height;
    final width = MediaQuery
        .of(context)
        .size
        .width;

    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.lightBlueAccent,
          elevation: 0,
          title: Text(
            widget.collegeName,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: RefreshIndicator(
          onRefresh: _refreshHome, // 🔄 SAME refresh function
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.lightBlueAccent, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: height,
                child: Column(
                  children: [

                    /// 🔹 Pull to refresh hint
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        "Pull to refresh",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // 🔹 Top Card (30% height)
                    Container(
                      height: height * 0.25,
                      margin: const EdgeInsets.all(16),
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
                          Expanded(
                            child: hasTimetable
                                ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Current Meal: $currentMeal",
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "$mealCount users want to eat",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    color: Colors.black87,
                                  ),
                                ),
                                const Spacer(),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AddTimetablePage(
                                              collegeName: widget.collegeName,
                                            ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(12),
                                    ),
                                  ),
                                  child:
                                  const Text("Edit Your Time & Menu"),
                                ),
                              ],
                            )
                                : GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AddTimetablePage(
                                            collegeName:
                                            widget.collegeName),
                                  ),
                                );
                              },
                              child: const Center(
                                child: Text(
                                  "Add Menu and Time Table for your College Mess",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),

                          // 🔹 Right image
                          Container(
                            margin: const EdgeInsets.only(left: 16),
                            width: width * 0.25,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey.shade200,
                              image: const DecorationImage(
                                image:
                                AssetImage("assets/default_food.jpg"),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    ScanCard(
                      collegeName: widget.collegeName,
                      currentMeal: currentMeal,
                    ),

                    const Spacer(),

                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminStudentPage(
                                collegeName: widget.collegeName,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 5,
                        ),
                        child: const Text(
                          "Students Attendance History",
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),

                    Padding(
                      padding: EdgeInsets.only(bottom: height * 0.15),
                      child: ElevatedButton(
                        onPressed: () async {
                          await UploadHelper.pickExcelFile(
                              context, widget.collegeName);
                          setState(() {
                            hasStudents = true;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 28),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 5,
                        ),
                        child: Text(
                          hasStudents
                              ? "Update Student List"
                              : "Upload Student List",
                          style: const TextStyle(fontSize: 18),
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

