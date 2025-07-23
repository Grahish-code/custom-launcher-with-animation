// Import core Dart libraries
import 'dart:async'; // For Timer
import 'dart:math'; // For random number generation

// Import Flutter UI libraries
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For loading assets

// Import Rive animation library
import 'package:rive/rive.dart';

// Your custom drawer widget (swipe-up launcher menu)
import 'app_drawer.dart'; // <-- Make sure this file exists

// Entry point of the Flutter app
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensures Flutter binding is set before any async code
  await RiveFile.initialize(); // Initializes Rive for proper setup
  runApp(const PetLauncherApp()); // Launch the main app
}

// Stateless wrapper for the root MaterialApp
class PetLauncherApp extends StatelessWidget {
  const PetLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false, // Removes debug banner
      home: HomeScreen(), // Sets the main screen
    );
  }
}

// Main widget containing the animation and logic
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// State class for HomeScreen
class _HomeScreenState extends State<HomeScreen> {
  Artboard? _artboard; // Holds the Rive artboard (canvas for animation)
  StateMachineController? _controller; // Controls the Rive state machine
  final Map<String, SMIBool> _boolInputs = {}; // Stores boolean inputs to control different actions

  Timer? _autoActionTimer; // Timer for auto-triggering random actions
  bool _isUserInterrupted = false; // Used to temporarily stop auto mode if user taps
  String? _currentAction; // Holds the current action's input name (e.g. Switch_01Action_Sitting)

  // A mapping of user-friendly labels to Rive boolean input names
  final Map<String, String> _inputMap = {
    'Sit': 'Switch_01Action_Sitting',
    'Eat': 'Switch_02Action_Eating',
    'Play': 'Switch_03Action_Play',
    'Sleep': 'Switch_04Action_Sleep',
  };

  @override
  void initState() {
    super.initState();
    _loadRiveFile().then((_) {
      _startAutoActionsLoop(); // Start looping random pet actions
    });
  }

  // Loads and sets up the Rive animation
  Future<void> _loadRiveFile() async {
    final data = await rootBundle.load('assets/cat_01.riv'); // Load the binary Rive file from assets
    final file = RiveFile.import(data); // Convert to usable Rive file

    // Try to get artboard named 'main', else fallback to default main artboard
    final artboard = file.artboardByName('main') ?? file.mainArtboard;

    // Try to attach the state machine controller named 'Big Cat'
    final controller = StateMachineController.fromArtboard(artboard, 'Big Cat');

    if (controller != null) {
      artboard.addController(controller); // Attach controller to artboard

      // Loop through the input names and find the corresponding SMIBool inputs
      for (final name in _inputMap.values) {
        final input = controller.findInput<bool>(name);
        if (input is SMIBool) {
          _boolInputs[name] = input; // Store in map for later control
        }
      }
    }

    // Update UI state
    setState(() {
      _artboard = artboard;
      _controller = controller;
    });
  }

  // Starts looping random actions automatically
  void _startAutoActionsLoop() {
    _scheduleNextAutoAction();
  }

  // Schedules the next random action after 5–10 seconds
  void _scheduleNextAutoAction() {
    _autoActionTimer?.cancel(); // Cancel any existing timer

    _autoActionTimer = Timer(Duration(seconds: 5 + Random().nextInt(5)), () async {
      if (!_isUserInterrupted) {
        await _playRandomAction();
        _scheduleNextAutoAction(); // Keep looping
      }
    });
  }

  // Picks a random action different from the current one
  Future<void> _playRandomAction() async {
    if (_boolInputs.isEmpty) return;

    // Get all inputs except the current one
    final available = _inputMap.values.where((a) => a != _currentAction).toList();
    available.shuffle(); // Shuffle the list randomly
    final next = available.first;

    await _setExclusiveByName(next); // Trigger the selected one
  }

  // Sets a single action active (exclusively), turns all others off
  Future<void> _setExclusiveByName(String inputName) async {
    for (final input in _boolInputs.values) {
      input.value = false; // Turn off all actions
    }

    await Future.delayed(const Duration(milliseconds: 50)); // Let Rive settle

    _boolInputs[inputName]?.value = true; // Activate the chosen action
    _currentAction = inputName; // Track it
  }

  // Called when user taps on the pet
  Future<void> _onUserTap() async {
    _isUserInterrupted = true; // Pause auto loop
    _autoActionTimer?.cancel(); // Stop current timer

    await _playRandomAction(); // Trigger new random action

    _isUserInterrupted = false; // Resume auto
    _scheduleNextAutoAction();
  }

  @override
  void dispose() {
    _autoActionTimer?.cancel(); // Clean up timer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta! < -20) {
          // Swipe-up detected
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AppDrawer()),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Center(
              child: _artboard == null
                  ? const CircularProgressIndicator() // While loading animation
                  : GestureDetector(
                onTap: _onUserTap, // Tapping the cat triggers random action
                child: Rive(
                  artboard: _artboard!,
                  fit: BoxFit.contain, // Keeps aspect ratio
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
