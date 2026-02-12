import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import 'admin/front_admin.dart';
import 'user/front_user.dart';
import 'admin/home_admin.dart';
import 'user/home_user.dart';

import 'apply.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔒 Lock app to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  try {
    print("⚡ Initializing Firebase...");
    await Firebase.initializeApp();
    print("✅ Firebase initialized successfully!");
  } catch (e, stackTrace) {
    print("❌ Firebase initialization failed!");
    print("Error: $e");
    print("StackTrace: $stackTrace");
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  DateTime? _lastBackPressed;

  Future<bool> _onDoubleBackExit(BuildContext context) async {
    final now = DateTime.now();

    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Press back again to exit"),
          duration: Duration(seconds: 2),
        ),
      );
      return false; // ❌ don't exit yet
    }
    return true; // ✅ exit app
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onDoubleBackExit(context),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'FMS System',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const AuthCheck(),
      ),
    );
  }
}

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  String? collegeName;
  String? userCollegeName;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCollegeName();
  }

  Future<void> _loadCollegeName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      collegeName = prefs.getString("collegeName");
      userCollegeName = prefs.getString("userCollegeName");
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      if (collegeName != null) {
        // ✅ Admin logged in
        return HomeAdmin(collegeName: collegeName!);
      } else {
        // ✅ Student logged in
        return HomeUser(collegeName: userCollegeName!);
      }
    } else {
      // ❌ Not logged in
      return const SplashPage();
    }
  }
}
class ScaleTransitionPopup extends StatefulWidget {
  final Widget child;
  const ScaleTransitionPopup({super.key, required this.child});

  @override
  State<ScaleTransitionPopup> createState() => _ScaleTransitionPopupState();
}

class _ScaleTransitionPopupState extends State<ScaleTransitionPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: widget.child,
      ),
    );
  }
}


class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool isNavigating = false;

  Future<void> _navigateWithDelay(Widget page) async {
    if (isNavigating) return;

    setState(() => isNavigating = true);

    // ⏳ small delay for Firebase readiness & smooth UX
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );

    // reset when user comes back
    if (mounted) {
      setState(() => isNavigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.lightBlueAccent, Colors.white70, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Welcome to FMS System",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              "Save Food !!",
              style: TextStyle(fontSize: 16, color: Colors.black),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isNavigating
                          ? null
                          : () => _navigateWithDelay(const FrontAdmin()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.lightBlue,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isNavigating
                          ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text(
                        "Jump in as Admin",
                        style: TextStyle(
                            fontSize: 18, color: Colors.lightBlue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isNavigating
                          ? null
                          : () => _navigateWithDelay(const FrontUser()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.lightBlue,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isNavigating
                          ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text(
                        "Jump in as Student",
                        style: TextStyle(
                            fontSize: 18, color: Colors.lightBlue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),

                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return Center(
                            child: ScaleTransitionPopup(
                              child: const ApplyPage(),
                            ),
                          );
                        },
                      );
                    },
                    child: const Text(
                      "Register Yourself in this Drive of Food Saving System!!!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

