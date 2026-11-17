import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine3d/toy_3d_renderer.dart';
import '../models/toy_customization.dart';
import '../models/toy_series.dart';
import '../services/collection_store.dart';
import '../widgets/toy_3d_viewport.dart';
import 'customize_screen.dart';

class CollectionScreen extends StatefulWidget {
  final CollectionStore store;

  const CollectionScreen({super.key, required this.store});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  ToySeriesId? _filterSeries;

  void _showJsonBackupDialog() {
    final jsonController = TextEditingController(
      text: widget.store.exportJson(),
    );

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Collection JSON'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Copy your collection JSON or paste a backup to restore.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: jsonController,
                  maxLines: 8,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF3F5FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: jsonController.text),
                );
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Copied JSON to clipboard')),
                  );
                }
              },
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final count = await widget.store.importJson(
                    jsonController.text,
                  );
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Imported $count toys')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Invalid JSON: $e')),
                    );
                  }
                }
              },
              child: const Text('Import'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _openToyInspector(ToyDefinition toy, HatchedToy hatched) {
    final series = seriesById(toy.seriesId);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                hatched.customization.nickname ?? toy.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${series.name} • ${toy.rarity.name.toUpperCase()}',
                style: TextStyle(
                  color: series.primaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: Toy3DViewport(
                  toy: toy,
                  customization: hatched.customization,
                  zoom: 1.08,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CustomizeScreen(
                          hatchedToy: hatched,
                          store: widget.store,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.brush_outlined),
                  label: const Text('Make it yours'),
                  style: FilledButton.styleFrom(
                    backgroundColor: series.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final toys = _filterSeries == null
            ? kAllToys
            : seriesById(_filterSeries!).toys;

        return SafeArea(
          child: Column(
            children: [
              // Progress header
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Toy Collection',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.store.discoveredCount} of ${widget.store.totalToyCount} discovered (${widget.store.hatchedToys.length} total hatched)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Export / Import JSON',
                          onPressed: _showJsonBackupDialog,
                          icon: const Icon(Icons.data_object),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: widget.store.collectionProgress,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFECEFF6),
                      ),
                    ),
                  ],
                ),
              ),

              // Series filter pills
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('All'),
                        selected: _filterSeries == null,
                        onSelected: (_) => setState(() => _filterSeries = null),
                      ),
                    ),
                    for (final s in kToySeriesList)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: Icon(s.icon, size: 15, color: s.primaryColor),
                          label: Text(
                            '${s.name} (${widget.store.discoveredInSeries(s.id)}/6)',
                          ),
                          selected: _filterSeries == s.id,
                          onSelected: (_) =>
                              setState(() => _filterSeries = s.id),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Toy grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.78,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: toys.length,
                  itemBuilder: (context, index) {
                    final toy = toys[index];
                    final series = seriesById(toy.seriesId);
                    final hatched = widget.store.latestForToy(toy.id);
                    final count = widget.store.countForToy(toy.id);
                    final unlocked = hatched != null;

                    return GestureDetector(
                      onTap: unlocked
                          ? () => _openToyInspector(toy, hatched)
                          : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: unlocked ? Colors.white : const Color(0xFFECEFF5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: unlocked
                                ? series.primaryColor.withValues(alpha: 0.28)
                                : Colors.transparent,
                          ),
                          boxShadow: unlocked
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Stack(
                          children: [
                            Column(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: unlocked
                                        ? CustomPaint(
                                            painter: Toy3DPainter(
                                              toy: toy,
                                              customization:
                                                  hatched.customization,
                                              rotY: 0.35,
                                              rotX: -0.15,
                                              zoom: 0.95,
                                            ),
                                            child: const SizedBox.expand(),
                                          )
                                        : Center(
                                            child: Icon(
                                              Icons.help_outline_rounded,
                                              size: 32,
                                              color: Colors.black
                                                  .withValues(alpha: 0.18),
                                            ),
                                          ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    6,
                                    0,
                                    6,
                                    10,
                                  ),
                                  child: Text(
                                    unlocked
                                        ? (hatched.customization.nickname ??
                                            toy.name)
                                        : '???',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: unlocked
                                          ? Colors.black87
                                          : Colors.black38,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (count > 1)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: series.primaryColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'x$count',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
