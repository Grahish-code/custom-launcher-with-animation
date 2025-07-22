import 'package:flutter/material.dart'; // Flutter UI framework
import 'package:installed_apps/app_info.dart'; // Data model for app info
import 'package:installed_apps/installed_apps.dart'; // Plugin to list and launch apps


// This widget represents the full-screen app drawer UI
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

// State for AppDrawer that handles loading and showing apps
class _AppDrawerState extends State<AppDrawer> {
  List<AppInfo>? _apps; // Stores the list of installed (non-system) apps

  @override
  void initState() {
    super.initState();
    _loadApps(); // Start loading apps when widget initializes
  }

  // Loads all installed user apps (excluding system apps) with icons
  Future<void> _loadApps() async {
    final apps = await InstalledApps.getInstalledApps(
      true,  // exclude system apps
      true,  // include app icons
    );
    setState(() => _apps = apps); // Save result in state to re-render UI
  }

  @override
  Widget build(BuildContext context) {
    // If apps are not yet loaded, show a loading spinner
    if (_apps == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Otherwise, show the grid of app icons
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.8), // semi-transparent dark bg
      body: GridView.builder(
        padding: const EdgeInsets.all(10), // space around the grid
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,         // number of icons per row
          crossAxisSpacing: 8,       // horizontal space between icons
          mainAxisSpacing: 8,        // vertical space between icons
        ),
        itemCount: _apps!.length,    // total number of apps to display
        itemBuilder: (ctx, i) {
          final app = _apps![i];     // get the i-th app from the list

          // Each app is wrapped in a tapable widget to launch it
          return GestureDetector(
            onTap: () => InstalledApps.startApp(app.packageName), // Launch app
            child: Column(
              mainAxisSize: MainAxisSize.min, // Don't expand vertically
              children: [
                if (app.icon != null)         // Only show icon if available
                  Image.memory(app.icon!, width: 48, height: 48), // Icon as image
                Text(
                  app.name,                    // Show app name
                  maxLines: 1,                 // Only show one line
                  overflow: TextOverflow.ellipsis, // Add ... if name too long
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
