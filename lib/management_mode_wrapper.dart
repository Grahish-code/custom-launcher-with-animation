// management_mode_wrapper.dart
// Handles pinch-to-zoom gestures and management mode UI

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ManagementModeWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onWallpaperTap;
  final VoidCallback? onWidgetTap;
  final bool isDarkWallpaper;

  const ManagementModeWrapper({
    super.key,
    required this.child,
    this.onWallpaperTap,
    this.onWidgetTap,
    this.isDarkWallpaper = false,
  });

  @override
  State<ManagementModeWrapper> createState() => _ManagementModeWrapperState();
}

class _ManagementModeWrapperState extends State<ManagementModeWrapper>
    with TickerProviderStateMixin {

  // Management mode state
  bool _isManagementMode = false;
  double _wallpaperScale = 1.0;
  double _wallpaperOpacity = 1.0;

  // Gesture tracking
  double _gestureStartScale = 1.0;
  bool _hasTriggeredThisGesture = false;

  // Animation controllers
  late AnimationController _managementModeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _buttonAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  @override
  void dispose() {
    _managementModeController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _managementModeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _managementModeController,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.7,
    ).animate(CurvedAnimation(
      parent: _managementModeController,
      curve: Curves.easeInOut,
    ));

    _buttonAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _managementModeController,
      curve: Curves.elasticOut,
    ));

    _scaleAnimation.addListener(() {
      setState(() {
        _wallpaperScale = _scaleAnimation.value;
        _wallpaperOpacity = _opacityAnimation.value;
      });
    });
  }

  // Toggle management mode with animation
  void _toggleManagementMode() {
    setState(() {
      _isManagementMode = !_isManagementMode;
    });

    if (_isManagementMode) {
      print('📱 ✅ ENTERING MANAGEMENT MODE');
      _managementModeController.forward();
      HapticFeedback.mediumImpact();
      _scheduleAutoExit();
    } else {
      print('🏠 ✅ EXITING MANAGEMENT MODE');
      _managementModeController.reverse();
    }
  }

  void _scheduleAutoExit() {
    Future.delayed(Duration(seconds: 5), () {
      if (_isManagementMode && mounted) {
        print('⏰ Auto-exiting management mode');
        _toggleManagementMode();
      }
    });
  }

  // Handle scale gesture for management mode
  void _handleScaleStart(ScaleStartDetails details) {
    print('🔥 Scale gesture started - pointers: ${details.pointerCount}');

    // Reset the trigger flag for each new gesture
    _hasTriggeredThisGesture = false;
    _gestureStartScale = 1.0;

    if (details.pointerCount >= 2) {
      HapticFeedback.lightImpact();
      print('✅ Multi-finger gesture detected');
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    print('📏 Scale: ${details.scale.toStringAsFixed(2)} | Triggered: $_hasTriggeredThisGesture | Management: $_isManagementMode');

    // Only trigger once per gesture and only when not already in management mode
    if (!_hasTriggeredThisGesture &&
        !_isManagementMode &&
        details.scale < 0.9 &&
        details.pointerCount >= 2) {

      print('🎯 TRIGGERING MANAGEMENT MODE!');
      _hasTriggeredThisGesture = true; // Mark as triggered
      _toggleManagementMode();
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    print('🏁 Scale gesture ended - Triggered this gesture: $_hasTriggeredThisGesture');

    // Reset for next gesture
    _hasTriggeredThisGesture = false;
    _gestureStartScale = 1.0;
  }

  void _handleWallpaperTap() {
    if (widget.onWallpaperTap != null) {
      widget.onWallpaperTap!();

      // Auto-exit management mode after action
      if (_isManagementMode) {
        Future.delayed(Duration(milliseconds: 1500), () {
          if (mounted) _toggleManagementMode();
        });
      }
    }
  }

  void _handleWidgetTap() {
    if (widget.onWidgetTap != null) {
      widget.onWidgetTap!();

      // Auto-exit management mode after action
      if (_isManagementMode) {
        Future.delayed(Duration(milliseconds: 1500), () {
          if (mounted) _toggleManagementMode();
        });
      }
    }
  }

  Widget _buildManagementButtons() {
    return AnimatedBuilder(
      animation: _buttonAnimation,
      builder: (context, child) {
        if (_buttonAnimation.value == 0.0) return SizedBox.shrink();

        return Stack(
          children: [
            // Left corner - Wallpaper button
            Positioned(
              bottom: 40 + (100 * _buttonAnimation.value),
              left: 30,
              child: Transform.scale(
                scale: _buttonAnimation.value,
                child: _buildManagementButton(
                  icon: Icons.wallpaper,
                  label: 'Wallpaper',
                  onTap: _handleWallpaperTap,
                  color: Colors.blue,
                ),
              ),
            ),

            // Right corner - Widget button
            Positioned(
              bottom: 40 + (100 * _buttonAnimation.value),
              right: 30,
              child: Transform.scale(
                scale: _buttonAnimation.value,
                child: _buildManagementButton(
                  icon: Icons.widgets,
                  label: 'Widgets',
                  onTap: _handleWidgetTap,
                  color: Colors.green,
                ),
              ),
            ),

            // Center - Instructions
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: _buttonAnimation.value,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Tap to customize • Pinch again to exit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildManagementButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: _handleScaleStart,
      onScaleUpdate: _handleScaleUpdate,
      onScaleEnd: _handleScaleEnd,
      onTap: _isManagementMode ? _toggleManagementMode : null,
      child: Stack(
        children: [
          // Main content with scale and opacity transformations
          Transform.scale(
            scale: _wallpaperScale,
            child: Opacity(
              opacity: _wallpaperOpacity,
              child: widget.child,
            ),
          ),

          // Management mode buttons overlay
          if (_isManagementMode) _buildManagementButtons(),
        ],
      ),
    );
  }

  // Getters to access current state from parent
  bool get isManagementMode => _isManagementMode;
  double get currentScale => _wallpaperScale;
  double get currentOpacity => _wallpaperOpacity;
}