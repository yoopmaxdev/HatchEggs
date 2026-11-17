import 'package:flutter/material.dart';

import 'screens/collection_screen.dart';
import 'screens/hatch_screen.dart';
import 'services/collection_store.dart';
import 'services/sound_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WonderHatchApp());
}

class WonderHatchApp extends StatelessWidget {
  const WonderHatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HatchEggs Wonder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6C5CE7),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        fontFamily: '.AppleSystemUIFont',
      ),
      home: const WonderHatchHome(),
    );
  }
}

class WonderHatchHome extends StatefulWidget {
  const WonderHatchHome({super.key});

  @override
  State<WonderHatchHome> createState() => _WonderHatchHomeState();
}

class _WonderHatchHomeState extends State<WonderHatchHome> {
  final CollectionStore _store = CollectionStore();
  int _tabIndex = 0;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 34,
                height: 34,
                errorBuilder: (_, _, _) => Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.egg, color: Colors.white, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'HatchEggs Wonder',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ],
        ),
        actions: [
          ListenableBuilder(
            listenable: _store,
            builder: (context, _) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: Color(0xFF6C5CE7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_store.discoveredCount}/${_store.totalToyCount}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            tooltip: _muted ? 'Unmute Sound' : 'Mute Sound',
            onPressed: () {
              setState(() {
                _muted = !_muted;
                SoundService.instance.muted = _muted;
              });
            },
            icon: Icon(
              _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          HatchScreen(store: _store),
          CollectionScreen(store: _store),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (idx) => setState(() => _tabIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.egg_outlined),
            selectedIcon: Icon(Icons.egg),
            label: 'Hatch',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Collection',
          ),
        ],
      ),
    );
  }
}
