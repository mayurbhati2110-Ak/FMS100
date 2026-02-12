import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminStudentPage extends StatefulWidget {
  final String collegeName;

  const AdminStudentPage({super.key, required this.collegeName});

  @override
  State<AdminStudentPage> createState() => _AdminStudentPageState();
}

class _AdminStudentPageState extends State<AdminStudentPage> {
  final List<String> meals = ["lunch", "dinner"];
  final Map<String, List<String>> dateMealMap = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  /// Load attendance history: last 7 days
  Future<void> _loadHistory() async {
    final firestore = FirebaseFirestore.instance;

    for (int i = 0; i < 7; i++) {
      final date = DateFormat("yyyy-MM-dd")
          .format(DateTime.now().subtract(Duration(days: i)));

      for (final meal in meals) {
        final snap = await firestore
            .collection("colleges")
            .doc(widget.collegeName)
            .collection(meal)
            .doc(date)
            .collection("students")
            .get();

        if (snap.docs.isNotEmpty) {
          dateMealMap.putIfAbsent(date, () => []);
          dateMealMap[date]!.add(meal);
        }
      }
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Students Attendance History"),
        backgroundColor: Colors.lightBlueAccent,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : dateMealMap.isEmpty
          ? const Center(child: Text("No data available"))
          : ListView(
        padding: const EdgeInsets.all(12),
        children: dateMealMap.entries.map((entry) {
          final date = entry.key;
          final meals = entry.value;

          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ExpansionTile(
              title: Text(
                "📅 $date",
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              children: meals.map((meal) {
                return ListTile(
                  title: Text(meal.toUpperCase()),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MealDetailPage(
                          collegeName: widget.collegeName,
                          meal: meal,
                          date: date,
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class MealDetailPage extends StatelessWidget {
  final String collegeName;
  final String meal;
  final String date;

  const MealDetailPage({
    super.key,
    required this.collegeName,
    required this.meal,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${meal.toUpperCase()} • $date"),
        backgroundColor: Colors.lightBlue,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("colleges")
            .doc(collegeName)
            .collection(meal)
            .doc(date)
            .collection("students")
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final students = snapshot.data!.docs;

          if (students.isEmpty) {
            return const Center(child: Text("No students recorded"));
          }

          final present =
          students.where((d) => d["present"] == true).toList();
          final absent =
          students.where((d) => d["present"] == false).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section("✅ Present", present),
                const SizedBox(height: 20),
                _section("❌ Absent", absent),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _section(String title, List<QueryDocumentSnapshot> docs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$title (${docs.length})",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...docs.map((doc) => Card(
          child: ListTile(
            title: Text(doc["name"]),
            subtitle: Text(doc["email"]),
            trailing: Text(
              doc["timestamp"].toDate().toString().substring(11, 16),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        )),
      ],
    );
  }
}
