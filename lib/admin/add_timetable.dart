import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AddTimetablePage extends StatefulWidget {
  final String collegeName;

  const AddTimetablePage({super.key, required this.collegeName});

  @override
  State<AddTimetablePage> createState() => _AddTimetablePageState();
}

class _AddTimetablePageState extends State<AddTimetablePage> {
  final _formKey = GlobalKey<FormState>();

  final breakfastTime = TextEditingController();
  final lunchTime = TextEditingController();
  final dinnerTime = TextEditingController();
  final breakfastMenu = TextEditingController();
  final lunchMenu = TextEditingController();
  final dinnerMenu = TextEditingController();

  bool isLoading = true;
  bool isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadExistingTimetable();
  }

  /// 🔹 Load / Refresh timetable
  Future<void> _loadExistingTimetable({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => isRefreshing = true);
    }

    try {
      final dbRef =
      FirebaseDatabase.instance.ref("admin/${widget.collegeName}/timetable");

      final snapshot = await dbRef.get();

      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);

        breakfastTime.text = data["breakfast"]?["time"] ?? "";
        breakfastMenu.text = data["breakfast"]?["menu"] ?? "";

        lunchTime.text = data["lunch"]?["time"] ?? "";
        lunchMenu.text = data["lunch"]?["menu"] ?? "";

        dinnerTime.text = data["dinner"]?["time"] ?? "";
        dinnerMenu.text = data["dinner"]?["menu"] ?? "";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Failed to refresh timetable")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isRefreshing = false;
        });
      }
    }
  }

  /// 🔹 Save or update timetable
  Future<void> saveTimetable() async {
    if (_formKey.currentState!.validate()) {
      final dbRef =
      FirebaseDatabase.instance.ref("admin/${widget.collegeName}/timetable");

      await dbRef.set({
        "breakfast": {"time": breakfastTime.text, "menu": breakfastMenu.text},
        "lunch": {"time": lunchTime.text, "menu": lunchMenu.text},
        "dinner": {"time": dinnerTime.text, "menu": dinnerMenu.text},
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Timetable saved successfully")),
      );

      Navigator.pop(context);
    }
  }

  /// 🔹 Time picker helper
  Future<void> _pickTime(TextEditingController controller) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: now.hour,
        minute: now.minute,
      ),
    );

    if (picked != null) {
      final formatted =
          "${picked.hour.toString().padLeft(2, '0')}:${picked.minute
          .toString()
          .padLeft(2, '0')}";
      setState(() {
        controller.text = formatted;
      });
    }
  }

  /// 🔹 Input builder with optional time picker
  Widget buildInput(String label, TextEditingController controller,
      {bool isTime = false}) {
    return TextFormField(
      controller: controller,
      readOnly: isTime,
      onTap: isTime ? () => _pickTime(controller) : null,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: isTime ? const Icon(Icons.access_time) : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) =>
      value == null || value.isEmpty ? "Required field" : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery
        .of(context)
        .size
        .height;

    return Scaffold(
      appBar: AppBar(
        title: Text("Add Timetable - ${widget.collegeName}"),
        backgroundColor: Colors.lightBlueAccent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Refresh timetable",
            icon: isRefreshing
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.refresh),
            onPressed: isRefreshing
                ? null
                : () => _loadExistingTimetable(),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.lightBlueAccent, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 🔹 Breakfast
                  buildInput("Breakfast Time (HH:MM)", breakfastTime,
                      isTime: true),
                  const SizedBox(height: 12),
                  buildInput("Breakfast Menu", breakfastMenu),
                  const SizedBox(height: 20),

                  // 🔹 Lunch
                  buildInput("Lunch Time (HH:MM)", lunchTime,
                      isTime: true),
                  const SizedBox(height: 12),
                  buildInput("Lunch Menu", lunchMenu),
                  const SizedBox(height: 20),

                  // 🔹 Dinner
                  buildInput("Dinner Time (HH:MM)", dinnerTime,
                      isTime: true),
                  const SizedBox(height: 12),
                  buildInput("Dinner Menu", dinnerMenu),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saveTimetable,
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
                      child: const Text(
                        "💾 Save Timetable",
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  SizedBox(height: height * 0.05),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    breakfastTime.dispose();
    lunchTime.dispose();
    dinnerTime.dispose();
    breakfastMenu.dispose();
    lunchMenu.dispose();
    dinnerMenu.dispose();
    super.dispose();
  }
}