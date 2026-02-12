import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MealCountHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get count of students for a meal on a given date
  static Future<int> getMealCount(String collegeName, String mealName) async {
    try {
      final today = DateFormat("yyyy-MM-dd").format(DateTime.now());

      final snapshot = await _firestore
          .collection("colleges")
          .doc(collegeName)
          .collection(mealName.toLowerCase())
          .doc(today)
          .collection("students")
          .get();

      print("📊 Checking path: colleges/$collegeName/$mealName/$today/students");

      return snapshot.size; // ✅ number of student docs
    } catch (e) {
      print("Error fetching meal count: $e");
      return 0;
    }
  }
}
