import 'package:flutter/material.dart';

import '../models/toy_customization.dart';
import '../models/toy_series.dart';
import '../services/collection_store.dart';
import '../services/sound_service.dart';
import '../widgets/toy_3d_viewport.dart';

class CustomizeScreen extends StatefulWidget {
  final HatchedToy hatchedToy;
  final CollectionStore store;

  const CustomizeScreen({
    super.key,
    required this.hatchedToy,
    required this.store,
  });

  @override
  State<CustomizeScreen> createState() => _CustomizeScreenState();
}

class _CustomizeScreenState extends State<CustomizeScreen> {
  late ToyCustomization _draft;
  late TextEditingController _nameController;

  static const List<Color> _paletteColors = [
    Color(0xFF5B8CFF),
    Color(0xFFFF6B9D),
    Color(0xFF4CE0B3),
    Color(0xFFFFD166),
    Color(0xFF9D4EDD),
    Color(0xFFFF7B54),
    Color(0xFF48CAE4),
    Color(0xFF8AC926),
    Color(0xFFF8F9FA),
    Color(0xFF5C677D),
  ];

  @override
  void initState() {
    super.initState();
    _draft = widget.hatchedToy.customization;
    _nameController = TextEditingController(text: _draft.nickname ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveAndClose() async {
    final trimmed = _nameController.text.trim();
    final updated = _draft.copyWith(
      nickname: trimmed.isEmpty ? null : trimmed,
      clearNickname: trimmed.isEmpty,
    );
    await widget.store.updateCustomization(widget.hatchedToy.instanceId, updated);
    await SoundService.instance.playPop();
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final toy = toyById(widget.hatchedToy.toyId);
    if (toy == null) {
      return const Scaffold(body: Center(child: Text('Toy not found')));
    }
    final series = seriesById(toy.seriesId);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Make it yours',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _draft = const ToyCustomization();
                _nameController.clear();
              });
            },
            child: const Text('Reset'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _saveAndClose,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 250,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  series.primaryColor.withValues(alpha: 0.18),
                  series.secondaryColor.withValues(alpha: 0.25),
                ],
              ),
              border: Border.all(
                color: series.primaryColor.withValues(alpha: 0.25),
              ),
            ),
            child: Stack(
              children: [
                Toy3DViewport(
                  toy: toy,
                  customization: _draft,
                  zoom: 1.05,
                ),
                Positioned(
                  left: 16,
                  top: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${toy.name} • ${series.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  right: 14,
                  bottom: 12,
                  child: Text(
                    'Drag to rotate 3D',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                _SectionCard(
                  icon: Icons.badge_outlined,
                  title: 'Nickname',
                  child: TextField(
                    controller: _nameController,
                    maxLength: 18,
                    decoration: InputDecoration(
                      hintText: 'Name your ${toy.name}...',
                      filled: true,
                      fillColor: const Color(0xFFF3F5FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  icon: Icons.palette_outlined,
                  title: 'Toy Color',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _ColorDot(
                        color: toy.defaultColor,
                        selected: _draft.bodyColorOverride == null,
                        label: 'Original',
                        onTap: () => setState(() {
                          _draft = _draft.copyWith(clearBodyColor: true);
                        }),
                      ),
                      for (final c in _paletteColors)
                        _ColorDot(
                          color: c,
                          selected: _draft.bodyColorOverride?.toARGB32() ==
                              c.toARGB32(),
                          onTap: () => setState(() {
                            _draft = _draft.copyWith(bodyColorOverride: c);
                          }),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  icon: Icons.sentiment_satisfied_alt,
                  title: 'Expression',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: FaceStyle.values.map((style) {
                      final selected = _draft.faceStyle == style;
                      return ChoiceChip(
                        label: Text(style.label),
                        selected: selected,
                        onSelected: (_) {
                          SoundService.instance.playPeelTick();
                          setState(() {
                            _draft = _draft.copyWith(faceStyle: style);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  icon: Icons.auto_awesome,
                  title: 'Accessory',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AccessoryStyle.values.map((style) {
                      final selected = _draft.accessoryStyle == style;
                      return ChoiceChip(
                        label: Text(style.label),
                        selected: selected,
                        onSelected: (_) {
                          SoundService.instance.playPeelTick();
                          setState(() {
                            _draft = _draft.copyWith(accessoryStyle: style);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  icon: Icons.hiking,
                  title: 'Shoes',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ShoeStyle.values.map((style) {
                      final selected = _draft.shoeStyle == style;
                      return ChoiceChip(
                        label: Text(style.label),
                        selected: selected,
                        onSelected: (_) {
                          SoundService.instance.playPeelTick();
                          setState(() {
                            _draft = _draft.copyWith(shoeStyle: style);
                          });
                        },
                      );
                    }).toList(),
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

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final String? label;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.selected,
    this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.black87 : Colors.black12,
            width: selected ? 3 : 1.5,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, size: 18, color: Colors.white)
            : null,
      ),
    );
  }
}
