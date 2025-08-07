// pet_animation.dart - Rive Animation Handler (Corrected Version)
// Handles all pet animation logic, state management, and user interactions

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' as rive;

class PetAnimation extends StatefulWidget {
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
  rive.Artboard? _artboard;
  rive.StateMachineController? _controller;
  final Map<String, rive.SMIBool> _boolInputs = {};
  final Map<String, String> _inputMap = {
    'Sit': 'Switch_01Action_Sitting',
    'Eat': 'Switch_02Action_Eating',
    'Play': 'Switch_03Action_Play',
    'Sleep': 'Switch_04Action_Sleep',
  };

  // ==================== ANIMATION STATE MANAGEMENT ====================
  Offset _petPosition = const Offset(150, 300);
  Ticker? _animationTicker;
  Duration _lastAnimationSwitch = Duration.zero;
  Duration _switchInterval = Duration(seconds: 6 + Random().nextInt(5));
  bool _isUserInteracting = false;
  String? _currentAction;

  // ==================== LIFECYCLE METHODS ====================
  @override
  void initState() {
    super.initState();
    _initializePetAnimation();
  }

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
  Future<void> _loadRiveFile() async {
    try {
      final data = await rootBundle.load('assets/cat_01.riv');
      final file = rive.RiveFile.import(data);
      final artboard = file.artboardByName('main') ?? file.mainArtboard;
      final controller = rive.StateMachineController.fromArtboard(
        artboard,
        'Big Cat', // Ensure this is the correct State Machine name
      );

      if (controller != null) {
        artboard.addController(controller);
        for (final inputName in _inputMap.values) {
          final input = controller.findInput<bool>(inputName);
          if (input is rive.SMIBool) {
            _boolInputs[inputName] = input;
          }
        }
        debugPrint('✅ Rive animation loaded successfully');
      } else {
        debugPrint('❌ Failed to create state machine controller');
      }

      setState(() {
        _artboard = artboard;
        _controller = controller;
      });

      // Set a default animation to start with
      await _playSpecificAnimation(_inputMap['Sit']!);

    } catch (e) {
      debugPrint('❌ Error loading Rive animation: $e');
    }
  }

  // ==================== AUTOMATIC ANIMATION SYSTEM ====================
  void _startAutomaticAnimations() {
    _animationTicker = createTicker((elapsed) {
      if (_artboard == null || _isUserInteracting) return;

      final timeSinceLastSwitch = elapsed - _lastAnimationSwitch;
      if (timeSinceLastSwitch > _switchInterval) {
        _playRandomAnimation();
        _lastAnimationSwitch = elapsed;
        _switchInterval = Duration(seconds: 6 + Random().nextInt(5));
      }
    });
    _animationTicker?.start();
  }

  Future<void> _playRandomAnimation() async {
    if (_boolInputs.isEmpty) return;
    final availableActions = _inputMap.values.where((action) => action != _currentAction).toList();
    if (availableActions.isEmpty) return;

    availableActions.shuffle();
    final nextAction = availableActions.first;

    await _playSpecificAnimation(nextAction);
    debugPrint('🎭 Random animation: ${_getActionNameFromInput(nextAction)}');
  }

  String _getActionNameFromInput(String inputName) {
    return _inputMap.entries
        .firstWhere((entry) => entry.value == inputName, orElse: () => const MapEntry('Unknown', ''))
        .key;
  }

  // ==================== ANIMATION CONTROL (THE FIX) ====================

  /// *** THIS IS THE CORRECTED FUNCTION ***
  /// Play a specific animation by cleanly turning the old one off and the new one on.
  Future<void> _playSpecificAnimation(String newActionName) async {
    // If the requested animation is already playing, do nothing.
    if (_currentAction == newActionName) return;

    // Turn OFF the previous animation, if there was one.
    if (_currentAction != null) {
      _boolInputs[_currentAction]?.value = false;
    }

    // Turn ON the new animation.
    _boolInputs[newActionName]?.value = true;

    // Update the current action tracker.
    _currentAction = newActionName;
  }

  // ==================== USER INTERACTION HANDLERS ====================
  Future<void> _handlePetTap() async {
    _isUserInteracting = true;
    await _playRandomAnimation();
    Future.delayed(const Duration(seconds: 2), () {
      _isUserInteracting = false;
    });
    debugPrint('👆 Pet tapped');
  }

  void _handleDragStart(DragStartDetails details) {
    _isUserInteracting = true;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      final newPosition = _petPosition + details.delta;
      final screenSize = MediaQuery.of(context).size;
      _petPosition = Offset(
        newPosition.dx.clamp(0, screenSize.width - 150),
        newPosition.dy.clamp(0, screenSize.height - 200),
      );
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    Future.delayed(const Duration(seconds: 1), () {
      _isUserInteracting = false;
    });
  }

  // ==================== UI BUILDERS ====================
  Widget _buildPetWidget() {
    if (_artboard == null) return _buildLoadingIndicator();
    return rive.Rive(artboard: _artboard!, fit: BoxFit.contain);
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(
            widget.isDarkWallpaper ? Colors.white : Colors.black54),
        strokeWidth: 2,
      ),
    );
  }

  // ==================== MAIN BUILD METHOD ====================
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: _petPosition.dx,
          top: _petPosition.dy,
          child: GestureDetector(
            onPanStart: _handleDragStart,
            onPanUpdate: _handleDragUpdate,
            onPanEnd: _handleDragEnd,
            onTap: _handlePetTap,
            child: SizedBox(
              width: 150,
              height: 150,
              child: _buildPetWidget(),
            ),
          ),
        ),
      ],
    );
  }
}