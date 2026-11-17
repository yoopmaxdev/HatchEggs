import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../engine3d/toy_3d_renderer.dart';
import '../models/toy_series.dart';
import '../services/collection_store.dart';
import '../services/sound_service.dart';
import '../widgets/toy_3d_viewport.dart';
import 'customize_screen.dart';

class HatchScreen extends StatefulWidget {
  final CollectionStore store;

  const HatchScreen({super.key, required this.store});

  @override
  State<HatchScreen> createState() => _HatchScreenState();
}

class _HatchScreenState extends State<HatchScreen>
    with TickerProviderStateMixin {
  ToySeriesId? _selectedSeries; // null = Mystery (all 10 series)
  double _peelProgress = 0.0;
  HatchOutcome? _hatchedOutcome;

  late final AnimationController _wobbleController;
  late final AnimationController _popController;

  @override
  void initState() {
    super.initState();
    _wobbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _wobbleController.dispose();
    _popController.dispose();
    super.dispose();
  }

  void _advancePeel(double delta) {
    if (_hatchedOutcome != null) return;
    final next = (_peelProgress + delta).clamp(0.0, 1.0);
    if ((next * 10).floor() != (_peelProgress * 10).floor() && next < 1.0) {
      SoundService.instance.playPeelTick();
    }
    setState(() {
      _peelProgress = next;
    });
    if (next >= 1.0) {
      _triggerHatch();
    }
  }

  void _triggerHatch() {
    final outcome = widget.store.hatchRandomToy(
      preferredSeries: _selectedSeries,
    );
    SoundService.instance.playCelebration();
    _popController.forward(from: 0.0);
    setState(() {
      _hatchedOutcome = outcome;
    });
  }

  void _resetCapsule() {
    SoundService.instance.playPeelTick();
    setState(() {
      _peelProgress = 0.0;
      _hatchedOutcome = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeSeries = _selectedSeries != null
        ? seriesById(_selectedSeries!)
        : null;
    final primary = activeSeries?.primaryColor ?? const Color(0xFF6C5CE7);
    final secondary = activeSeries?.secondaryColor ?? const Color(0xFFFF85A1);

    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        // Keep hatched outcome synced if customized
        final currentOutcome = _hatchedOutcome;
        final syncedHatched = currentOutcome != null
            ? widget.store.hatchedToys.cast<dynamic>().firstWhere(
                  (t) => t.instanceId == currentOutcome.hatchedToy.instanceId,
                  orElse: () => currentOutcome.hatchedToy,
                )
            : null;

        return SafeArea(
          child: Column(
            children: [
              // Series selector bar
              SizedBox(
                height: 54,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: const Icon(Icons.casino, size: 16),
                        label: const Text('Mystery'),
                        selected: _selectedSeries == null,
                        onSelected: _hatchedOutcome == null
                            ? (_) => setState(() => _selectedSeries = null)
                            : null,
                      ),
                    ),
                    for (final series in kToySeriesList)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Icon(
                            series.icon,
                            size: 16,
                            color: _selectedSeries == series.id
                                ? Colors.white
                                : series.primaryColor,
                          ),
                          label: Text(series.name),
                          selected: _selectedSeries == series.id,
                          selectedColor: series.primaryColor,
                          labelStyle: TextStyle(
                            color: _selectedSeries == series.id
                                ? Colors.white
                                : null,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: _hatchedOutcome == null
                              ? (_) => setState(
                                    () => _selectedSeries = series.id,
                                  )
                              : null,
                        ),
                      ),
                  ],
                ),
              ),

              // Main 3D Stage
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primary.withValues(alpha: 0.14),
                        secondary.withValues(alpha: 0.20),
                        Colors.white,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: currentOutcome == null
                      ? _buildPeelStage(primary, secondary)
                      : _buildRevealedStage(
                          currentOutcome,
                          syncedHatched ?? currentOutcome.hatchedToy,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeelStage(Color primary, Color secondary) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _advancePeel(0.26),
      onVerticalDragUpdate: (details) {
        if (details.delta.dy.abs() > 1.5) {
          _advancePeel(details.delta.dy.abs() * 0.0045);
        }
      },
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx.abs() > 1.5) {
          _advancePeel(details.delta.dx.abs() * 0.0045);
        }
      },
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _wobbleController,
            builder: (context, _) {
              return CustomPaint(
                painter: FoilCapsulePainter(
                  peelProgress: _peelProgress,
                  primaryColor: primary,
                  secondaryColor: secondary,
                  wobble: _wobbleController.value,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),
          Positioned(
            top: 24,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Text(
                  'Peel the foil',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Swipe or tap the capsule to unwrap your 3D toy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.58),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 24,
            left: 48,
            right: 48,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _peelProgress,
                    minHeight: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.7),
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_peelProgress * 100).round()}% unwrapped',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevealedStage(HatchOutcome outcome, dynamic hatchedToy) {
    final toy = outcome.definition;
    final series = seriesById(toy.seriesId);
    final rarityColor = switch (toy.rarity) {
      ToyRarity.common => const Color(0xFF4CAF50),
      ToyRarity.rare => const Color(0xFF2196F3),
      ToyRarity.epic => const Color(0xFF9C27B0),
    };

    return Stack(
      children: [
        // Subtle celebratory sparkle ring
        AnimatedBuilder(
          animation: _popController,
          builder: (context, _) {
            final t = _popController.value;
            if (t >= 1.0) return const SizedBox.shrink();
            return CustomPaint(
              painter: _BurstPainter(progress: t, color: series.primaryColor),
              child: const SizedBox.expand(),
            );
          },
        ),
        Column(
          children: [
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: outcome.isNewDiscovery
                        ? const Color(0xFFFFD166)
                        : Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    outcome.isNewDiscovery ? 'NEW DISCOVERY!' : 'COLLECTED',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: rarityColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    toy.rarity.name.toUpperCase(),
                    style: TextStyle(
                      color: rarityColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hatchedToy.customization.nickname ?? toy.name,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(series.icon, size: 15, color: series.primaryColor),
                const SizedBox(width: 5),
                Text(
                  series.name,
                  style: TextStyle(
                    color: series.primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Expanded(
              child: Toy3DViewport(
                toy: toy,
                customization: hatchedToy.customization,
                zoom: 1.05,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CustomizeScreen(
                              hatchedToy: hatchedToy,
                              store: widget.store,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.brush_outlined),
                      label: const Text('Make it yours'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _resetCapsule,
                      icon: const Icon(Icons.egg_outlined),
                      label: const Text('Hatch Another'),
                      style: FilledButton.styleFrom(
                        backgroundColor: series.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BurstPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _BurstPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.48);
    final maxR = math.min(size.width, size.height) * 0.45;
    final alpha = (1.0 - progress).clamp(0.0, 1.0);

    for (var i = 0; i < 16; i++) {
      final angle = (i / 16) * math.pi * 2;
      final dist = maxR * (0.2 + progress * 0.85);
      final pt = center + Offset(math.cos(angle) * dist, math.sin(angle) * dist);
      final dotColor = i.isEven ? color : const Color(0xFFFFD166);
      canvas.drawCircle(
        pt,
        6.0 * (1.0 - progress * 0.6),
        Paint()..color = dotColor.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
