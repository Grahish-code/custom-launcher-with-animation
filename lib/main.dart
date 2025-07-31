// main.dart - Application Entry Point
// This file only handles app initialization and routing to HomeScreen

import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;
import 'home_screen.dart';

void main() async {
  // Ensure Flutter bindings are initialized before any async operations
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Rive animation system
  await rive.RiveFile.initialize();

  // Launch the app
  runApp(const PetLauncherApp());
}

/// Main application widget - keeps it simple and clean
class PetLauncherApp extends StatelessWidget {
  const PetLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Virtual Pet Launcher',
      home: HomeScreen(),
    );
  }
}