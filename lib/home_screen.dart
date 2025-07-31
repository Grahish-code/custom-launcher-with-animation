// home_screen.dart - Main UI and Navigation Handler
// Handles wallpaper management, app drawer navigation, status bar theming, and Android widgets

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'app_drawer.dart';
import 'pet_animation.dart';
import 'widget_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Uint8List? _wallpaperBytes;
  bool _isDarkWallpaper = false;
  List<WidgetSnapshot> _widgetSnapshots = [];

  static const _appChannel = MethodChannel('launchable_apps');
  static const _wallpaperChannel = MethodChannel('com.example.virtual_pet/wallpaper');

  @override
  void initState() {
    super.initState();
    _initializeHomeScreen();
    _loadWidgets();
  }

  Future<void> _initializeHomeScreen() async {
    _setInitialStatusBar();
    await _loadSavedWallpaper();
  }

  void _setInitialStatusBar() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  void _updateStatusBarColors() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: _isDarkWallpaper ? Brightness.light : Brightness.dark,
          statusBarBrightness: _isDarkWallpaper ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: _isDarkWallpaper ? Brightness.light : Brightness.dark,
        ),
      );
    });

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
  }

  Future<void> _loadSavedWallpaper() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/wallpaper.jpg');

      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final isDark = await _analyzeWallpaperBrightness(bytes);

        setState(() {
          _wallpaperBytes = bytes;
          _isDarkWallpaper = isDark;
        });

        _updateStatusBarColors();
      }
    } catch (e) {
      debugPrint("❌ Error loading wallpaper: $e");
    }
  }

  Future<void> _pickAndSetWallpaper() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    try {
      final bytes = await image.readAsBytes();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/wallpaper.jpg');
      await file.writeAsBytes(bytes);

      final isDark = await _analyzeWallpaperBrightness(bytes);

      setState(() {
        _wallpaperBytes = bytes;
        _isDarkWallpaper = isDark;
      });

      _updateStatusBarColors();
    } catch (e) {
      debugPrint("❌ Error setting wallpaper: $e");
    }
  }

  Future<bool> _analyzeWallpaperBrightness(Uint8List imageBytes) async {
    try {
      final bool isDark = await _wallpaperChannel.invokeMethod('isDarkWallpaper', {
        'image': imageBytes,
      });

      await _wallpaperChannel.invokeMethod('updateStatusBar', {'isDark': isDark});
      return isDark;
    } catch (e) {
      debugPrint('❌ Error analyzing wallpaper brightness: $e');
      return false;
    }
  }

  Future<List<AppInfo>> _loadDockApps() async {
    try {
      final apps = await _appChannel.invokeMethod<List<dynamic>>('getLaunchableApps');
      if (apps == null) return [];

      const targetPackages = {
        'com.oplus.camera',
        'com.oplus.dialer',
        'com.android.chrome',
      };

      return apps
          .map((a) => a as Map)
          .where((a) => targetPackages.contains(a['packageName']))
          .map((a) => AppInfo(
        appName: a['appName'],
        packageName: a['packageName'],
        icon: Uint8List.fromList(List<int>.from(a['icon'])),
      ))
          .toList();
    } catch (e) {
      debugPrint('❌ Error loading dock apps: $e');
      return [];
    }
  }

  Future<void> _launchApp(String packageName) async {
    try {
      await _appChannel.invokeMethod('launchApp', {'packageName': packageName});
    } catch (e) {
      debugPrint('❌ Failed to launch $packageName: $e');
    }
  }

  Future<void> _loadWidgets() async {
    final installed = await WidgetManager.getInstalledWidgets();
    final snapshots = <WidgetSnapshot>[];

    for (final widget in installed) {
      final snapshot = await WidgetManager.getWidgetSnapshot(widget.widgetId);
      if (snapshot != null) snapshots.add(snapshot);
    }

    setState(() {
      _widgetSnapshots = snapshots;
    });
  }

  List<Widget> _buildWidgetsOnHomeScreen() {
    return _widgetSnapshots.map((widget) {
      return Positioned(
        top: 80,
        left: 20,
        child: Container(
          width: widget.width.toDouble(),
          height: widget.height.toDouble(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              widget.imageBytes,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildBackground() {
    return Container(
      decoration: _wallpaperBytes != null
          ? BoxDecoration(
        image: DecorationImage(
          image: MemoryImage(_wallpaperBytes!),
          fit: BoxFit.cover,
        ),
      )
          : const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF87CEEB),
            Color(0xFFE0F6FF),
          ],
        ),
      ),
    );
  }

  Widget _buildAppDock() {
    return FutureBuilder<List<AppInfo>>(
      future: _loadDockApps(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox();
        }

        final apps = snapshot.data!;
        return Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                  decoration: BoxDecoration(
                    color: _isDarkWallpaper
                        ? Colors.black.withOpacity(0.3)
                        : Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: _isDarkWallpaper
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.1),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: apps.map((app) => _buildAppIcon(app)).toList(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppIcon(AppInfo app) {
    return GestureDetector(
      onTap: () => _launchApp(app.packageName),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                app.icon,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            app.appName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _isDarkWallpaper ? Colors.white : Colors.black87,
              shadows: _isDarkWallpaper
                  ? const [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)]
                  : const [Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.white70)],
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWallpaperButton() {
    return Positioned(
      top: 20,
      right: 20,
      child: Container(
        decoration: BoxDecoration(
          color: _isDarkWallpaper ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.4),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(25),
            onTap: _pickAndSetWallpaper,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.wallpaper,
                color: _isDarkWallpaper ? Colors.white : Colors.black87,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleSwipeUp(DragUpdateDetails details) {
    if (details.primaryDelta! < -20) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AppsGridPage(wallpaperBytes: _wallpaperBytes),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: _handleSwipeUp,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 0,
        ),
        body: Stack(
          children: [
            _buildBackground(),
            SafeArea(
              child: Stack(
                children: [
                 // PetAnimation(isDarkWallpaper: _isDarkWallpaper),
                  ..._buildWidgetsOnHomeScreen(),
                  _buildAppDock(),
                  _buildWallpaperButton(),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final picked = await WidgetManager.pickWidget();
            if (picked != null) {
              final result = await WidgetManager.addWidget(
                packageName: picked.packageName,
                className: picked.className,
              );

              if (result?.success == true) {
                await _loadWidgets();
              } else if (result?.needsPermission == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Widget permission needed')),
                );
              } else {
                debugPrint("❌ Failed to add widget");
              }
            }
          },
          child: const Icon(Icons.widgets),
          backgroundColor: _isDarkWallpaper ? Colors.black87 : Colors.white,
          foregroundColor: _isDarkWallpaper ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}

class AppInfo {
  final String appName;
  final String packageName;
  final Uint8List icon;

  AppInfo({
    required this.appName,
    required this.packageName,
    required this.icon,
  });
}
