// home_screen.dart - Complete, Optimized Code
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
// Make sure you have these files in your project
import 'app_drawer.dart';
import 'pet_animation.dart';
import 'management_mode_wrapper.dart';
import 'widget_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- State Variables ---
  bool _isLoading = true;
  List<AppInfo> _dockApps = [];
  Uint8List? _wallpaperBytes;
  bool _isDarkWallpaper = false;
  List<ActiveWidget> _activeWidgets = [];
  Map<int, WidgetBitmap> _widgetBitmaps = {};
  bool _isLoadingWidgets = false;
  bool _isInitialized = false;

  static const _appChannel = MethodChannel('launchable_apps');
  static const _wallpaperChannel = MethodChannel('com.example.virtual_pet/wallpaper');

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    WorkingWidgetManager.stopListening();
    super.dispose();
  }

  // --- Initialization and Performance Logic ---

  Future<void> _initializeScreen() async {
    _setInitialStatusBar();

    try {
      await Future.wait([
        _loadSavedWallpaper(),
        _initializeWidgetSystem(),
        _loadDockApps(),
      ]);

      if (_isInitialized) {
        await _loadActiveWidgets();
      }
    } catch (e) {
      debugPrint("❌ A critical error occurred during initialization: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDockApps() async {
    try {
      final apps = await _appChannel.invokeMethod<List<dynamic>>('getLaunchableApps');
      if (apps == null) {
        _dockApps = [];
        return;
      }

      const targetPackages = {
        'com.oplus.camera',
        'com.oplus.dialer',
        'com.android.chrome',
      };

      final loadedApps = apps
          .map((a) => a as Map)
          .where((a) => targetPackages.contains(a['packageName']))
          .map((a) => AppInfo(
        appName: a['appName'],
        packageName: a['packageName'],
        icon: Uint8List.fromList(List<int>.from(a['icon'])),
      ))
          .toList();

      _dockApps = loadedApps;
    } catch (e) {
      debugPrint('❌ Error loading dock apps: $e');
      _dockApps = [];
    }
  }

  Future<void> _initializeWidgetSystem() async {
    try {
      final hostInitialized = await WorkingWidgetManager.initializeWidgetHost();
      if (!hostInitialized) return;

      final startedListening = await WorkingWidgetManager.startListening();
      if (!startedListening) return;

      _isInitialized = true;
    } catch (e) {
      print('❌ Error initializing widget system: $e');
    }
  }

  // --- Wallpaper and System UI ---

  void _setInitialStatusBar() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  }

  void _updateStatusBarColors() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: _isDarkWallpaper ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: _isDarkWallpaper ? Brightness.light : Brightness.dark,
    ));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
  }

  Future<void> _loadSavedWallpaper() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/wallpaper.jpg');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final isDark = await _analyzeWallpaperBrightness(bytes);
        _wallpaperBytes = bytes;
        _isDarkWallpaper = isDark;
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
      _showSnackBar('Wallpaper updated!');
    } catch (e) {
      debugPrint("❌ Error setting wallpaper: $e");
      _showSnackBar('Failed to set wallpaper');
    }
  }

  Future<bool> _analyzeWallpaperBrightness(Uint8List imageBytes) async {
    try {
      final bool isDark = await _wallpaperChannel.invokeMethod('isDarkWallpaper', {'image': imageBytes});
      await _wallpaperChannel.invokeMethod('updateStatusBar', {'isDark': isDark});
      return isDark;
    } catch (e) {
      debugPrint('❌ Error analyzing wallpaper brightness: $e');
      return false;
    }
  }

  // --- Widget Management ---

  Future<void> _loadActiveWidgets() async {
    if (!_isInitialized) return;
    try {
      final widgets = await WorkingWidgetManager.getActiveWidgets();
      _activeWidgets = widgets;
      await Future.wait(widgets.map((widget) => _captureWidgetBitmap(widget.appWidgetId)));
    } catch (e) {
      print('❌ Error loading active widgets: $e');
    }
  }

  Future<void> _captureWidgetBitmap(int appWidgetId) async {
    try {
      final bitmap = await WorkingWidgetManager.captureWidget(appWidgetId);
      if (bitmap != null && bitmap.isValid) {
        _widgetBitmaps[appWidgetId] = bitmap;
      }
    } catch (e) {
      print('❌ Error capturing widget bitmap for $appWidgetId: $e');
    }
  }

  Future<void> _addNewWidget() async {
    if (!_isInitialized) {
      _showSnackBar('Widget system not ready yet');
      return;
    }
    try {
      final shouldProceed = await _showAddWidgetDialog();
      if (!shouldProceed) return;
      setState(() => _isLoadingWidgets = true);
      final result = await WorkingWidgetManager.addWidgetFromPicker();
      setState(() => _isLoadingWidgets = false);
      if (result.success) {
        _showSnackBar('Widget "${result.widgetLabel}" added successfully!');
        Future.delayed(const Duration(milliseconds: 1000), () {
          _loadActiveWidgets().then((_) => setState(() {}));
        });
      } else {
        _showSnackBar('Failed to add widget: ${result.message}');
      }
    } catch (e) {
      setState(() => _isLoadingWidgets = false);
      _showSnackBar('Error adding widget: $e');
    }
  }

  Future<void> _removeWidget(int appWidgetId) async {
    try {
      final success = await WorkingWidgetManager.removeWidget(appWidgetId);
      if (success && mounted) {
        setState(() {
          _activeWidgets.removeWhere((w) => w.appWidgetId == appWidgetId);
          _widgetBitmaps.remove(appWidgetId);
        });
        _showSnackBar('Widget removed successfully');
      } else {
        _showSnackBar('Failed to remove widget');
      }
    } catch (e) {
      _showSnackBar('Error removing widget: $e');
    }
  }

  Future<void> _refreshWidget(int appWidgetId) async {
    try {
      _showSnackBar('Refreshing widget...');
      await _captureWidgetBitmap(appWidgetId);
      if (mounted) {
        setState(() {});
      }
      _showSnackBar('Widget refreshed!');
    } catch (e) {
      _showSnackBar('Error refreshing widget');
    }
  }

  Future<void> _launchApp(String packageName) async {
    try {
      await _appChannel.invokeMethod('launchApp', {'packageName': packageName});
    } catch (e) {
      debugPrint('❌ Failed to launch $packageName: $e');
    }
  }

  void _handleSwipeUp(DragUpdateDetails details) {
    if (details.primaryDelta! < -6) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AppsGridPage(wallpaperBytes: _wallpaperBytes),
        ),
      );
    }
  }

  // --- UI Build Methods ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: _isLoading
          ? Stack(
        children: [
          _buildBackground(),
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      )
          : GestureDetector(
        onVerticalDragUpdate: _handleSwipeUp,
        child: Stack(
          children: [
            ManagementModeWrapper(
              isDarkWallpaper: _isDarkWallpaper,
              onWallpaperTap: _pickAndSetWallpaper,
              onWidgetTap: _addNewWidget,
              child: Stack(
                children: [
                  _buildBackground(),
                  Stack(
                    children: [
                      PetAnimation(isDarkWallpaper: _isDarkWallpaper),
                      ..._buildWidgetsOnHomeScreen(),
                      _buildLoadingIndicator(),
                      _buildSystemStatusIndicator(),
                    ],
                  ),
                ],
              ),
            ),
            _buildAppDock(),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildBackground() {
    return Container(
      decoration: _wallpaperBytes != null
          ? BoxDecoration(
        image: DecorationImage(image: MemoryImage(_wallpaperBytes!), fit: BoxFit.cover),
      )
          : const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF87CEEB), Color(0xFFE0F6FF)],
        ),
      ),
    );
  }

  Widget _buildAppDock() {
    if (_dockApps.isEmpty) return const SizedBox.shrink();
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 34),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: _isDarkWallpaper ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.4),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _isDarkWallpaper ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.15),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _dockApps.map((app) => _buildAppIcon(app)).toList(),
              ),
            ),
          ),
        ),
      ),
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
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(app.icon, width: 56, height: 56, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            app.appName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _isDarkWallpaper ? Colors.white : Colors.black87,
              shadows: _isDarkWallpaper
                  ? [const Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)]
                  : [const Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.white70)],
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWidgetsOnHomeScreen() {
    if (_activeWidgets.isEmpty) return [];
    return _activeWidgets.asMap().entries.map((entry) {
      final index = entry.key;
      final widget = entry.value;
      final bitmap = _widgetBitmaps[widget.appWidgetId];
      final double topPosition = 120.0 + (index * 200.0);
      final double leftPosition = 20.0;
      return Positioned(
        top: topPosition,
        left: leftPosition,
        child: GestureDetector(
          onTap: () => _refreshWidget(widget.appWidgetId),
          onLongPress: () => _showWidgetOptions(widget),
          child: Container(
            width: 320,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: const Offset(0, 6))],
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  if (bitmap != null && bitmap.isValid)
                    Image.memory(bitmap.imageBytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(widget))
                  else
                    _buildLoadingWidget(widget),
                  Positioned(
                    top: 8, left: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.touch_app, color: Colors.white70, size: 16),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: widget.isConfigured ? Colors.green : Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildErrorWidget(ActiveWidget widget) {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline, size: 32, color: Colors.grey[600]),
          const SizedBox(height: 8),
          Text('Widget Error', style: TextStyle(color: Colors.grey[700], fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(widget.label, style: TextStyle(color: Colors.grey[600], fontSize: 11), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  Widget _buildLoadingWidget(ActiveWidget widget) {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue)),
          const SizedBox(height: 12),
          Text('Loading Widget...', style: TextStyle(color: Colors.grey[700], fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(widget.label, style: TextStyle(color: Colors.grey[600], fontSize: 11), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    if (!_isLoadingWidgets) return const SizedBox.shrink();
    return Positioned(
      top: 80, left: 20, right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isDarkWallpaper ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue)),
          const SizedBox(width: 12),
          Expanded(child: Text('Adding widget...', style: TextStyle(color: _isDarkWallpaper ? Colors.white : Colors.black, fontWeight: FontWeight.w500))),
        ]),
      ),
    );
  }

  Widget _buildSystemStatusIndicator() {
    if (_isInitialized) return const SizedBox.shrink();
    return Positioned(
      top: 50, right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.9), borderRadius: BorderRadius.circular(6)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white)),
          SizedBox(width: 6),
          Text('Initializing...', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  // --- Dialogs and Modals ---

  Future<bool> _showAddWidgetDialog() async {
    final canBind = await WorkingWidgetManager.canBindWidgets();
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkWallpaper ? Colors.grey[900] : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.widgets, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Add Widget', style: TextStyle(color: _isDarkWallpaper ? Colors.white : Colors.black)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add a widget to your home screen:', style: TextStyle(fontWeight: FontWeight.w500, color: _isDarkWallpaper ? Colors.white : Colors.black)),
            const SizedBox(height: 12),
            _buildInstructionStep('1️⃣', 'Widget picker will open'),
            _buildInstructionStep('2️⃣', 'Choose your desired widget'),
            _buildInstructionStep('3️⃣', 'Configure if required'),
            _buildInstructionStep('4️⃣', 'Widget appears on home screen'),
            if (!canBind) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Note: Some widgets may need configuration',
                          style: TextStyle(fontSize: 12, color: _isDarkWallpaper ? Colors.orange[200] : Colors.orange[800])),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Open Picker')),
        ],
      ),
    ) ?? false;
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(number, style: TextStyle(fontSize: 16, color: _isDarkWallpaper ? Colors.white : Colors.black)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: _isDarkWallpaper ? Colors.white : Colors.black))),
      ]),
    );
  }

  void _showWidgetOptions(ActiveWidget widget) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isDarkWallpaper ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(widget.label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _isDarkWallpaper ? Colors.white : Colors.black)),
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.blue),
              title: Text('Refresh Widget', style: TextStyle(color: _isDarkWallpaper ? Colors.white : Colors.black)),
              subtitle: Text('Update widget content', style: TextStyle(color: _isDarkWallpaper ? Colors.grey[300] : Colors.grey[600])),
              onTap: () { Navigator.pop(context); _refreshWidget(widget.appWidgetId); },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.green),
              title: Text('Widget Info', style: TextStyle(color: _isDarkWallpaper ? Colors.white : Colors.black)),
              subtitle: Text('Package: ${widget.packageName}', style: TextStyle(color: _isDarkWallpaper ? Colors.grey[300] : Colors.grey[600])),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text('Remove Widget', style: TextStyle(color: _isDarkWallpaper ? Colors.white : Colors.black)),
              subtitle: Text('Delete from home screen', style: TextStyle(color: _isDarkWallpaper ? Colors.grey[300] : Colors.grey[600])),
              onTap: () { Navigator.pop(context); _removeWidget(widget.appWidgetId); },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _isDarkWallpaper ? Colors.grey[800] : Colors.grey[700],
      ),
    );
  }
}

// --- Data Classes ---

class AppInfo {
  final String appName;
  final String packageName;
  final Uint8List icon;

  AppInfo({required this.appName, required this.packageName, required this.icon});
}