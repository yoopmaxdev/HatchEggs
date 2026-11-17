import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wonderhatch_flutter/main.dart';
import 'package:wonderhatch_flutter/models/toy_customization.dart';
import 'package:wonderhatch_flutter/screens/customize_screen.dart';
import 'package:wonderhatch_flutter/services/collection_store.dart';
import 'package:wonderhatch_flutter/services/sound_service.dart';

class _ScreenshotSpec {
  final String folder;
  final double logicalWidth;
  final double logicalHeight;
  final double pixelRatio;

  const _ScreenshotSpec({
    required this.folder,
    required this.logicalWidth,
    required this.logicalHeight,
    required this.pixelRatio,
  });
}

const _specs = [
  _ScreenshotSpec(
    folder: 'iphone_6.1',
    logicalWidth: 393,
    logicalHeight: 852,
    pixelRatio: 3.0, // 1179 x 2556
  ),
  _ScreenshotSpec(
    folder: 'ipad_12.9',
    logicalWidth: 1024,
    logicalHeight: 1366,
    pixelRatio: 2.0, // 2048 x 2732
  ),
  _ScreenshotSpec(
    folder: 'iphone_duo',
    logicalWidth: 669,
    logicalHeight: 951,
    pixelRatio: 3.0, // 2007 x 2853
  ),
];

Future<void> _capturePng(
  WidgetTester tester,
  GlobalKey key,
  double pixelRatio,
  String outPath,
) async {
  await tester.pump(const Duration(milliseconds: 100));
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync(
    () => boundary.toImage(pixelRatio: pixelRatio),
  );
  final byteData = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  final file = File(outPath);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(byteData!.buffer.asUint8List());
}

Future<void> _loadRealFonts() async {
  const sfPath = '/System/Library/Fonts/SFNS.ttf';
  const fontsDir =
      '/Users/macbookpro/development/flutter/bin/cache/artifacts/material_fonts';

  if (File(sfPath).existsSync()) {
    final sfBytes = File(sfPath).readAsBytesSync().buffer.asByteData();
    final sfLoader = FontLoader('.AppleSystemUIFont')
      ..addFont(Future.value(sfBytes));
    await sfLoader.load();
  }

  final robotoLoader = FontLoader('Roboto');
  for (final file in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ]) {
    final f = File('$fontsDir/$file');
    if (f.existsSync()) {
      robotoLoader.addFont(Future.value(f.readAsBytesSync().buffer.asByteData()));
    }
  }
  await robotoLoader.load();

  final iconsFile = File('$fontsDir/MaterialIcons-Regular.otf');
  if (iconsFile.existsSync()) {
    final iconBytes = iconsFile.readAsBytesSync().buffer.asByteData();
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(iconBytes));
    await iconLoader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Generate App Store screenshots', (WidgetTester tester) async {
    await tester.runAsync(_loadRealFonts);
    SharedPreferences.setMockInitialValues({});
    SoundService.instance.muted = true;

    for (final spec in _specs) {
      tester.view.physicalSize = Size(
        spec.logicalWidth * spec.pixelRatio,
        spec.logicalHeight * spec.pixelRatio,
      );
      tester.view.devicePixelRatio = spec.pixelRatio;

      final boundaryKey = GlobalKey();

      // 1. Peel the foil screen
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: const WonderHatchApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await _capturePng(
        tester,
        boundaryKey,
        spec.pixelRatio,
        'screenshots/${spec.folder}/01_peel.png',
      );

      // 2. Hatched 3D Toy screen (tap 4 times to unwrap)
      final capsuleFinder = find.text('Peel the foil');
      for (var i = 0; i < 4; i++) {
        await tester.tap(capsuleFinder);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 700));
      await _capturePng(
        tester,
        boundaryKey,
        spec.pixelRatio,
        'screenshots/${spec.folder}/02_hatched.png',
      );

      // 3. Collection screen (hatch a few more toys for a lively shelf)
      for (var n = 0; n < 5; n++) {
        await tester.tap(find.text('Hatch Another'));
        await tester.pump(const Duration(milliseconds: 50));
        for (var i = 0; i < 4; i++) {
          await tester.tap(find.text('Peel the foil'));
          await tester.pump(const Duration(milliseconds: 30));
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.byIcon(Icons.grid_view_outlined));
      await tester.pump(const Duration(milliseconds: 200));
      await _capturePng(
        tester,
        boundaryKey,
        spec.pixelRatio,
        'screenshots/${spec.folder}/04_collection.png',
      );

      // 4. Customize ("Make it yours") screen with Ember dragon
      final store = CollectionStore();
      final sampleDragon = HatchedToy(
        instanceId: 'sample_ember',
        toyId: 'dragon_ember',
        hatchedAt: DateTime(2026, 11, 17),
        customization: const ToyCustomization(
          faceStyle: FaceStyle.starry,
          accessoryStyle: AccessoryStyle.crown,
          shoeStyle: ShoeStyle.star,
          nickname: 'Sparky',
        ),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: const Color(0xFF6C5CE7),
              scaffoldBackgroundColor: const Color(0xFFF6F7FB),
              fontFamily: '.AppleSystemUIFont',
            ),
            home: CustomizeScreen(
              hatchedToy: sampleDragon,
              store: store,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await _capturePng(
        tester,
        boundaryKey,
        spec.pixelRatio,
        'screenshots/${spec.folder}/03_customize.png',
      );
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
