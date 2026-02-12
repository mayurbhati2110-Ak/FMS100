import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:firebase_database/firebase_database.dart';

/// 🔹 UploadHelper reads Excel and saves entries into RTDB.
class UploadHelper {
  static Future<void> pickExcelFile(BuildContext context, String collegeName) async {
    try {
      // Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xls', 'xlsx'],
      );

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No file selected")),
        );
        return;
      }

      File file = File(result.files.single.path!);
      final bytes = file.readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      // Assuming first sheet
      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null || sheet.rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Excel file is empty")),
        );
        return;
      }

      // 🔹 Prepare student list
      // Assuming Excel has columns like: Name | Email | RollNo
      List<Map<String, dynamic>> students = [];

      // Skip header row → start from row 1
      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];

        if (row.isEmpty || row[0] == null) continue;

        // Handle phone number cleanly
        String phone = "";
        if (row.length > 2 && row[2] != null) {
          var val = row[2]!.value;
          if (val is double) {
            phone = val.toInt().toString(); // remove .0
          } else {
            phone = val.toString().trim();
          }
        }

        students.add({
          "name": row[0]?.value.toString().trim() ?? "",
          "email": row.length > 1 ? row[1]?.value.toString().trim() ?? "" : "",
          "phone": phone,
        });
      }


      if (students.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No student data found in file")),
        );
        return;
      }

      // 🔹 Save into RTDB
      final dbRef = FirebaseDatabase.instance.ref("admin/$collegeName/students");
      await dbRef.set(students);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Student list uploaded successfully ✅")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }
}
