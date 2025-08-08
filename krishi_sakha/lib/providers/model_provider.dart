import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:krishi_sakha/models/llm_model.dart';

class ModelProvider extends ChangeNotifier {
  static const String _boxName = 'llm_models';
  
  Box<LlmModel>? _modelBox;
  List<LlmModel> _models = [];
  LlmModel? _activeModel;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<LlmModel> get models => _models;
  LlmModel? get activeModel => _activeModel;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasModels => _models.isNotEmpty;
  bool get hasActiveModel => _activeModel != null;

  /// Initialize the provider
  Future<void> initialize() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Open Hive box
      _modelBox = await Hive.openBox<LlmModel>(_boxName);

      // Load models from Hive
      await _loadModels();
      debugPrint('Models loaded: ${_models.length}');

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to initialize: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint(_error);
    }
  }

  /// Load all models from Hive
  Future<void> _loadModels() async {
    if (_modelBox == null) return;

    _models = _modelBox!.values.toList();
    
    // Find active model
    _activeModel = _models.where((model) => model.isActive).firstOrNull;
    
    // If no active model but models exist, set first as active
    if (_activeModel == null && _models.isNotEmpty) {
      await setActiveModel(_models.first);
    }
  }

  /// Add a new model
  Future<void> addModel({
    required String name,
    required String modelPath,
  }) async {
    try {
      _error = null;
      _isLoading = true;
      notifyListeners();

      // Validate model file exists
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        throw Exception('Model file not found: $modelPath');
      }

      // Check if model already exists
      final existingModel = _models.where((m) => m.copiedPath == modelPath).firstOrNull;
      if (existingModel != null) {
        throw Exception('Model already exists');
      }

      // Create new model
      final model = LlmModel(
        name: name,
        copiedPath: modelPath,
        lastUsed: DateTime.now().toIso8601String(),
      );

      // Save to Hive
      await _modelBox?.add(model);

      // Add to local list
      _models.add(model);

      // Set as active if it's the first model
      if (_activeModel == null) {
        await setActiveModel(model);
      }
      debugPrint(
      _modelBox!.values.toList().toString());

      _isLoading = false;
      notifyListeners();
      // debugPrint("Models is box : ${_modelBox.}")

      debugPrint('Model added: ${model.name}');
    } catch (e) {
      _error = 'Failed to add model: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Remove a model
  Future<void> removeModel(LlmModel model) async {
    try {
      _error = null;
      _isLoading = true;
      notifyListeners();

      // Remove from Hive
      await model.delete();

      // Remove from local list
      _models.remove(model);
      await File(model.copiedPath).delete();

      // Clear active model if it was removed
      if (_activeModel == model) {
        _activeModel = _models.isNotEmpty ? _models.first : null;
        if (_activeModel != null) {
          _activeModel!.setActive(true);
        }
      }

      _isLoading = false;
      notifyListeners();

      debugPrint('Model removed: ${model.name}');
    } catch (e) {
      _error = 'Failed to remove model: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Set active model
  Future<void> setActiveModel(LlmModel model) async {
    try {
      _error = null;

      // Mark previous active model as inactive
      if (_activeModel != null) {
        _activeModel!.setActive(false);
      }

      // Set new active model
      _activeModel = model;
      model.setActive(true);

      notifyListeners();

      debugPrint('Active model set to: ${model.name}');
    } catch (e) {
      _error = 'Failed to set active model: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Get model by name
  LlmModel? getModelByName(String name) {
    try {
      return _models.firstWhere((model) => model.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Refresh models
  Future<void> refresh() async {
    await _loadModels();
    notifyListeners();
  }

  @override
  void dispose() {
    _modelBox?.close();
    super.dispose();
  }
}