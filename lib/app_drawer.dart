
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:ui';

class AppsGridPage extends StatefulWidget {
  final Uint8List? wallpaperBytes;
  const AppsGridPage({super.key, required this.wallpaperBytes});

  @override
  _AppsGridPageState createState() => _AppsGridPageState();
}

class _AppsGridPageState extends State<AppsGridPage> {
  static const platform = MethodChannel('launchable_apps');

  List<AppInfo> apps = [];
  TextEditingController searchController = TextEditingController();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadApps();
    searchController.addListener(onSearchTextChanged);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadApps() async {
    if (AppCache().hasCache) {
      setState(() {
        apps = List.from(AppCache().apps!);
        isLoading = false;
      });
      return;
    }

    try {
      final List<dynamic> result = await platform.invokeMethod('getLaunchableApps');

      final loadedApps = result.map((app) => AppInfo(
        name: app['appName'],
        packageName: app['packageName'],
        iconBytes: Uint8List.fromList(List<int>.from(app['icon'])),
      )).toList();

      AppCache().apps = loadedApps;

      setState(() {
        apps = List.from(loadedApps);
        isLoading = false;
      });
    } catch (e) {
      print('Error loading apps: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void onSearchTextChanged() {
    final query = searchController.text.toLowerCase();
    setState(() {
      apps = query.isEmpty
          ? List.from(AppCache().apps!)
          : AppCache().apps!
          .where((app) => app.name.toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> launchApp(String packageName) async {
    try {
      await platform.invokeMethod('launchApp', {'packageName': packageName});
    } catch (e) {
      print('Could not launch app: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.wallpaperBytes != null)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Image.memory(
                widget.wallpaperBytes!,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(color: Colors.black87),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Search apps...",
                        hintStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.search, color: Colors.white70),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : apps.isEmpty
                      ? const Center(
                      child: Text('No apps found', style: TextStyle(color: Colors.white)))
                      : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.7,
                    ),
                    itemCount: apps.length,
                    itemBuilder: (context, index) {
                      final app = apps[index];
                      return GestureDetector(
                        onTap: () => launchApp(app.packageName),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.memory(
                              app.iconBytes,
                              width: 50,
                              height: 50,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              app.name.length > 12
                                  ? '${app.name.substring(0, 10)}...'
                                  : app.name,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────
// App Info Model
class AppInfo {
  final String name;
  final String packageName;
  final Uint8List iconBytes;

  AppInfo({
    required this.name,
    required this.packageName,
    required this.iconBytes,
  });
}

// ─────────────────────────────────────
// Global App Cache (Lives Across Screens)
class AppCache {
  static final AppCache _instance = AppCache._internal();
  factory AppCache() => _instance;
  AppCache._internal();

  List<AppInfo>? apps;
  bool get hasCache => apps != null && apps!.isNotEmpty;
}

