import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/toy_customization.dart';
import '../models/toy_series.dart';

class HatchOutcome {
  final HatchedToy hatchedToy;
  final ToyDefinition definition;
  final bool isNewDiscovery;

  const HatchOutcome({
    required this.hatchedToy,
    required this.definition,
    required this.isNewDiscovery,
  });
}

class CollectionStore extends ChangeNotifier {
  static const String _storageKey = 'wonderhatch_collection_v1';

  final Random _random = Random();
  List<HatchedToy> _hatchedToys = [];
  bool _loaded = false;

  List<HatchedToy> get hatchedToys => List.unmodifiable(_hatchedToys);
  bool get isLoaded => _loaded;

  Set<String> get discoveredToyIds =>
      _hatchedToys.map((e) => e.toyId).toSet();

  int get discoveredCount => discoveredToyIds.length;
  int get totalToyCount => kAllToys.length;
  double get collectionProgress =>
      totalToyCount == 0 ? 0 : discoveredCount / totalToyCount;

  HatchedToy? latestForToy(String toyId) {
    for (var i = _hatchedToys.length - 1; i >= 0; i--) {
      if (_hatchedToys[i].toyId == toyId) return _hatchedToys[i];
    }
    return null;
  }

  int countForToy(String toyId) =>
      _hatchedToys.where((e) => e.toyId == toyId).length;

  int discoveredInSeries(ToySeriesId seriesId) {
    final series = seriesById(seriesId);
    final owned = discoveredToyIds;
    return series.toys.where((t) => owned.contains(t.id)).length;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _hatchedToys = decoded
              .whereType<Map<String, dynamic>>()
              .map(HatchedToy.fromJson)
              .toList();
        }
      }
    } catch (_) {
      // Fall back to empty collection if storage is unavailable.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_hatchedToys.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (_) {
      // Ignore storage errors in restricted environments.
    }
  }

  HatchOutcome hatchRandomToy({ToySeriesId? preferredSeries}) {
    final pool = preferredSeries != null
        ? seriesById(preferredSeries).toys
        : kAllToys;

    final weighted = <ToyDefinition>[];
    for (final toy in pool) {
      final weight = switch (toy.rarity) {
        ToyRarity.common => 5,
        ToyRarity.rare => 3,
        ToyRarity.epic => 1,
      };
      for (var i = 0; i < weight; i++) {
        weighted.add(toy);
      }
    }

    final chosen = weighted[_random.nextInt(weighted.length)];
    final isNew = !discoveredToyIds.contains(chosen.id);
    final hatched = HatchedToy(
      instanceId:
          '${chosen.id}_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(9999)}',
      toyId: chosen.id,
      hatchedAt: DateTime.now(),
    );

    _hatchedToys = [..._hatchedToys, hatched];
    notifyListeners();
    _save();

    return HatchOutcome(
      hatchedToy: hatched,
      definition: chosen,
      isNewDiscovery: isNew,
    );
  }

  Future<void> updateCustomization(
    String instanceId,
    ToyCustomization customization,
  ) async {
    final idx = _hatchedToys.indexWhere((e) => e.instanceId == instanceId);
    if (idx == -1) return;
    _hatchedToys[idx] = _hatchedToys[idx].copyWith(customization: customization);
    notifyListeners();
    await _save();
  }

  String exportJson() {
    final payload = {
      'app': 'HatchEggs Wonder',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'toys': _hatchedToys.map((e) => e.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<int> importJson(String rawJson) async {
    final decoded = jsonDecode(rawJson);
    final list = switch (decoded) {
      {'toys': final List toys} => toys,
      final List toys => toys,
      _ => throw const FormatException('Invalid HatchEggs Wonder JSON format'),
    };
    final imported = list
        .whereType<Map<String, dynamic>>()
        .map(HatchedToy.fromJson)
        .where((t) => toyById(t.toyId) != null)
        .toList();

    _hatchedToys = imported;
    notifyListeners();
    await _save();
    return imported.length;
  }

  Future<void> clearCollection() async {
    _hatchedToys = [];
    notifyListeners();
    await _save();
  }
}
