import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';
import 'app_drawer.dart'; // <-- Make sure this file exists

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RiveFile.initialize();
  runApp(const PetLauncherApp());
}

class PetLauncherApp extends StatelessWidget {
  const PetLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Artboard? _artboard;
  StateMachineController? _controller;
  final Map<String, SMIBool> _boolInputs = {};

  final Map<String, String> _inputMap = {
    'Sit': 'Switch_01Action_Sitting',
    'Eat': 'Switch_02Action_Eating',
    'Play': 'Switch_03Action_Play',
    'Sleep': 'Switch_04Action_Sleep',
  };

  @override
  void initState() {
    super.initState();
    _loadRiveFile();
  }

  Future<void> _loadRiveFile() async {
    final data = await rootBundle.load('assets/cat_01.riv');
    final file = RiveFile.import(data);
    final artboard = file.artboardByName('main') ?? file.mainArtboard;

    final controller = StateMachineController.fromArtboard(artboard, 'Big Cat');
    if (controller != null) {
      artboard.addController(controller);
      for (final name in _inputMap.values) {
        final input = controller.findInput<bool>(name);
        if (input is SMIBool) {
          _boolInputs[name] = input;
        }
      }
    }

    setState(() {
      _artboard = artboard;
      _controller = controller;
    });
  }

  Future<void> _setExclusive(String actionLabel) async {
    final inputName = _inputMap[actionLabel];
    if (inputName == null) return;

    for (final input in _boolInputs.values) {
      input.value = false;
    }

    await Future.delayed(const Duration(milliseconds: 50));
    _boolInputs[inputName]?.value = true;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta! < -20) {   //“If the user swiped upward quickly (more than 20 pixels), do something.”
          // swipe up detected
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
                  ? const CircularProgressIndicator()
                  : Rive(artboard: _artboard!, fit: BoxFit.contain),
            ),
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                children: _inputMap.keys.map((label) {
                  return ElevatedButton(
                    onPressed: () => _setExclusive(label),
                    child: Text(label),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
