// pet_animation.dart - Rive Animation Handler
// Handles all pet animation logic, state management, and user interactions

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' as rive;

class PetAnimation extends StatefulWidget {
  /// Whether the current wallpaper is dark (affects pet visibility)
  final bool isDarkWallpaper;

  const PetAnimation({
    super.key,
    required this.isDarkWallpaper,
  });

  @override
  State<PetAnimation> createState() => _PetAnimationState();
}

class _PetAnimationState extends State<PetAnimation>
    with SingleTickerProviderStateMixin {

  // ==================== RIVE ANIMATION PROPERTIES ====================

  /// Main Rive artboard containing the pet
  rive.Artboard? _artboard;

  /// State machine controller for managing animations
  rive.StateMachineController? _controller;

  /// Map of boolean inputs for controlling animation states
  final Map<String, rive.SMIBool> _boolInputs = {};

  /// Mapping of user-friendly action names to Rive input names
  final Map<String, String> _inputMap = {
    'Sit': 'Switch_01Action_Sitting',
    'Eat': 'Switch_02Action_Eating',
    'Play': 'Switch_03Action_Play',
    'Sleep': 'Switch_04Action_Sleep',
  };

  // ==================== ANIMATION STATE MANAGEMENT ====================

  /// Current position of the pet on screen
  Offset _petPosition = const Offset(150, 300);

  /// Ticker for automatic animation switching
  Ticker? _animationTicker;

  /// Time when the last animation switch occurred
  Duration _lastAnimationSwitch = Duration.zero;

  /// Random interval between automatic animation switches
  Duration _switchInterval = Duration(seconds: 6 + Random().nextInt(5));

  /// Flag to prevent automatic animations during user interaction
  bool _isUserInteracting = false;

  /// Currently playing animation action
  String? _currentAction;

  // ==================== LIFECYCLE METHODS ====================

  @override
  void initState() {
    super.initState();
    _initializePetAnimation();
  }

  /// Initialize all animation components
  Future<void> _initializePetAnimation() async {
    await _loadRiveFile();
    _startAutomaticAnimations();
  }

  @override
  void dispose() {
    _animationTicker?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  // ==================== RIVE FILE LOADING ====================

  /// Load and initialize the Rive animation file
  Future<void> _loadRiveFile() async {
    try {
      // Load the Rive file from assets
      final data = await rootBundle.load('assets/cat_01.riv');
      final file = rive.RiveFile.import(data);

      // Get the main artboard (or fallback to first available)
      final artboard = file.artboardByName('main') ?? file.mainArtboard;

      // Create state machine controller
      final controller = rive.StateMachineController.fromArtboard(
        artboard,
        'Big Cat', // Name of the state machine in your Rive file
      );

      if (controller != null) {
        // Add controller to artboard
        artboard.addController(controller);

        // Map all boolean inputs for easy access
        for (final inputName in _inputMap.values) {
          final input = controller.findInput<bool>(inputName);
          if (input is rive.SMIBool) {
            _boolInputs[inputName] = input;
          }
        }

        debugPrint('✅ Rive animation loaded successfully');
        debugPrint('📝 Available inputs: ${_boolInputs.keys.toList()}');
      } else {
        debugPrint('❌ Failed to create state machine controller');
      }

      // Update state
      setState(() {
        _artboard = artboard;
        _controller = controller;
      });
    } catch (e) {
      debugPrint('❌ Error loading Rive animation: $e');
    }
  }

  // ==================== AUTOMATIC ANIMATION SYSTEM ====================

  /// Start the ticker for automatic animation switching
  void _startAutomaticAnimations() {
    _animationTicker = createTicker((elapsed) {
      // Skip if no animation loaded or user is interacting
      if (_artboard == null || _isUserInteracting) return;

      // Check if it's time to switch animations
      final timeSinceLastSwitch = elapsed - _lastAnimationSwitch;
      if (timeSinceLastSwitch > _switchInterval) {
        _playRandomAnimation();
        _lastAnimationSwitch = elapsed;
        // Set random interval for next switch (6-10 seconds)
        _switchInterval = Duration(seconds: 6 + Random().nextInt(5));
      }
    });

    _animationTicker?.start();
    debugPrint('🎬 Automatic animation system started');
  }

  /// Play a random animation (excluding current one)
  Future<void> _playRandomAnimation() async {
    if (_boolInputs.isEmpty) return;

    // Get all available actions except the current one
    final availableActions = _inputMap.values
        .where((action) => action != _currentAction)
        .toList();

    if (availableActions.isEmpty) return;

    // Shuffle and pick first one for randomness
    availableActions.shuffle();
    final nextAction = availableActions.first;

    await _playSpecificAnimation(nextAction);

    debugPrint('🎭 Random animation: ${_getActionNameFromInput(nextAction)}');
  }

  /// Get user-friendly action name from Rive input name
  String _getActionNameFromInput(String inputName) {
    return _inputMap.entries
        .firstWhere((entry) => entry.value == inputName,
        orElse: () => const MapEntry('Unknown', ''))
        .key;
  }

  // ==================== ANIMATION CONTROL ====================

  /// Play a specific animation by setting it exclusively
  Future<void> _playSpecificAnimation(String inputName) async {
    // Turn off all animations first
    for (final input in _boolInputs.values) {
      input.value = false;
    }

    // Small delay to ensure clean transition
    await Future.delayed(const Duration(milliseconds: 60));

    // Turn on the desired animation
    _boolInputs[inputName]?.value = true;
    _currentAction = inputName;
  }

  // ==================== USER INTERACTION HANDLERS ====================

  /// Handle user tap on the pet
  Future<void> _handlePetTap() async {
    _isUserInteracting = true;

    // Play a random animation when tapped
    await _playRandomAnimation();

    // Allow automatic animations to resume after a brief pause
    Future.delayed(const Duration(milliseconds: 500), () {
      _isUserInteracting = false;
    });

    debugPrint('👆 Pet tapped - playing interaction animation');
  }

  /// Handle start of pet dragging
  void _handleDragStart(DragStartDetails details) {
    _isUserInteracting = true;
    debugPrint('🤏 Pet drag started');
  }

  /// Handle pet position updates during dragging
  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      final newPosition = _petPosition + details.delta;
      final screenSize = MediaQuery.of(context).size;

      // Constrain pet position within screen boundaries
      _petPosition = Offset(
        newPosition.dx.clamp(0, screenSize.width - 150),
        newPosition.dy.clamp(0, screenSize.height - 200), // Leave space for bottom dock
      );
    });
  }

  /// Handle end of pet dragging
  void _handleDragEnd(DragEndDetails details) {
    // Resume automatic animations after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      _isUserInteracting = false;
    });

    debugPrint('🤲 Pet drag ended at position: $_petPosition');
  }

  // ==================== UI BUILDERS ====================

  /// Build the pet animation widget with loading state
  Widget _buildPetWidget() {
    if (_artboard == null) {
      return _buildLoadingIndicator();
    }

    return rive.Rive(
      artboard: _artboard!,
      fit: BoxFit.contain,
    );
  }

  /// Build loading indicator while Rive file loads
  Widget _buildLoadingIndicator() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(
          widget.isDarkWallpaper ? Colors.white : Colors.black54,
        ),
        strokeWidth: 2,
      ),
    );
  }

  /// Build debug animation info (development only)
  // Widget _buildDebugInfo() {
  //   if (!const bool.fromEnvironment('dart.vm.product')) {
  //     return Positioned(
  //       bottom: 10,
  //       left: 10,
  //       child: Container(
  //         padding: const EdgeInsets.all(6),
  //         decoration: BoxDecoration(
  //           color: Colors.black54,
  //           borderRadius: BorderRadius.circular(6),
  //         ),
  //         child: Text(
  //           'Current: ${_currentAction != null ? _getActionNameFromInput(_currentAction!) : 'None'}\n'
  //               'Position: (${_petPosition.dx.toInt()}, ${_petPosition.dy.toInt()})\n'
  //               'Interacting: $_isUserInteracting',
  //           style: const TextStyle(
  //             color: Colors.white,
  //             fontSize: 8,
  //           ),
  //         ),
  //       ),
  //     );
  //   }
  //   return const SizedBox();
  // }

  // ==================== MAIN BUILD METHOD ====================

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main pet animation positioned on screen
        Positioned(
          left: _petPosition.dx,
          top: _petPosition.dy,
          child: GestureDetector(
            // Handle drag interactions
            onPanStart: _handleDragStart,
            onPanUpdate: _handleDragUpdate,
            onPanEnd: _handleDragEnd,

            // Handle tap interactions
            onTap: _handlePetTap,

            // Pet container
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                // Optional: Add subtle shadow for better visibility
                boxShadow: widget.isDarkWallpaper
                    ? null
                    : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildPetWidget(),
            ),
          ),
        ),

        // Debug information overlay
       // _buildDebugInfo(),
      ],
    );
  }
}