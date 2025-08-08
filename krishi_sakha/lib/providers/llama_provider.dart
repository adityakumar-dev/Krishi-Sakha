import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fllama/fllama.dart';
import 'package:flutter/foundation.dart';
import 'package:krishi_sakha/models/llm_model.dart';

/// -----------------------------------------------------------------
/// LLAMA PROVIDER
///
/// A provider-based service that handles fllama interactions.
/// Provides streaming responses and manages chat state with better control.
/// -----------------------------------------------------------------
class LlamaProvider extends ChangeNotifier {
  // --- Private State ---
  LlmModel? _currentModel;
  final List<Message> _chatHistory = [];
  bool _isInitialized = true;
  bool _isGenerating = false;
  int? _currentRequestId;
  DateTime? _inferenceStartTime;
  String _streamingResponse = '';
  String _status = '';
  String? _error;

  // --- Configuration ---
  static const String systemPrompt = 'You are a helpful and concise assistant.';
  static const int maxTokens = 512;
  static const double temperature = 0.7;
  static const double topP = 0.9;
  static const double presencePenalty = 1.1;
  static const int contextSize = 4096;
  static const int numGpuLayers = 0;

  // --- Public Accessors ---
  LlmModel? get currentModel => _currentModel;
  bool get isInitialized => _isInitialized;
  bool get isGenerating => _isGenerating;
  String get streamingResponse => _streamingResponse;
  String get status => _status;
  String? get error => _error;
  int get messageCount => _chatHistory.length - 1; // Exclude system prompt

  /// Initialize with a model
  Future<void> initialize(LlmModel model) async {
    // if (_isInitialized && _currentModel?.copiedPath == model.copiedPath) {
    //   debugPrint("LlamaProvider already initialized with this model.");
    //   return;
    // }

    // Web platform is not supported
    if (kIsWeb) {
      _setError("Web platform not supported");
      return;
    }

    try {
      _setStatus("Initializing AI model...");
      _clearError();

      // Validate model file exists
      final modelFile = File(model.copiedPath);
      if (!await modelFile.exists()) {
        throw Exception("Model file not found at: ${model.copiedPath}");
      }

      _currentModel = model;
      _chatHistory.clear();
      _chatHistory.add(Message(Role.system, systemPrompt));
      _isInitialized = true;

      // Update model's last used time
      model.updateLastUsed();

      _setStatus("AI model ready");
      debugPrint("LlamaProvider initialized with model: ${model.name}");
    } catch (e) {
      _setError("Failed to initialize: $e");
      debugPrint("Failed to initialize LlamaProvider: $e");
      rethrow;
    }
  }

  /// Send a user message and get streaming response
  Future<void> sendMessage(String userMessage) async {
    if (!_isInitialized || _currentModel == null) {
      _setError(
        "Service not initialized. Please initialize with a model first.",
      );
      return;
    }

    if (_isGenerating) {
      _setError(
        "Already generating a response. Please wait or cancel current generation.",
      );
      return;
    }

    _isGenerating = true;
    _streamingResponse = '';
    _inferenceStartTime = DateTime.now();
    _clearError();

    // Add user message to history
    _chatHistory.add(Message(Role.user, userMessage));

    _setStatus("Generating response...");
    notifyListeners();

    try {
      final request = OpenAiRequest(
        modelPath: _currentModel!.copiedPath,
        messages: _chatHistory,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: topP,
        presencePenalty: presencePenalty,
        contextSize: contextSize,
        numGpuLayers: numGpuLayers,
        logger: (log) {
          // Filter out verbose logs
          if (!log.contains('<unused') && !log.contains('ggml_')) {
            debugPrint('[fllama] $log');
          }
        },
      );

      String fullAssistantResponse = "";

      _currentRequestId = await fllamaChat(request, (
        response,
        responseJson,
        done,
      ) {
        if (!_isGenerating) return; // Stop if generation was cancelled

        // Calculate new tokens (incremental response)
        final newTokens = response.length > fullAssistantResponse.length
            ? response.substring(fullAssistantResponse.length)
            : '';

        if (newTokens.isNotEmpty) {
          fullAssistantResponse = response;
          _streamingResponse = response;
          notifyListeners(); // Notify UI of new tokens
        }

        if (done) {
          _finalizeChatResponse(fullAssistantResponse);
        }
      });
    } catch (e) {
      _setError("Error during chat: $e");
      _isGenerating = false;
      _currentRequestId = null;
      notifyListeners();
      debugPrint("Chat error: $e");
    }
  }

  /// Finalize the chat response and update history
  void _finalizeChatResponse(String fullResponse) {
    try {
      // Add assistant response to history
      _chatHistory.add(Message(Role.assistant, fullResponse));

      // Calculate performance metrics
      if (_inferenceStartTime != null) {
        final elapsedSeconds =
            DateTime.now().difference(_inferenceStartTime!).inMilliseconds /
            1000.0;

        _calculateTokensPerSecond(fullResponse, elapsedSeconds);
      }

      _isGenerating = false;
      _currentRequestId = null;
      _inferenceStartTime = null;
      _streamingResponse = '';

      _setStatus("Response completed");
      notifyListeners();

      debugPrint("Chat response completed successfully");
    } catch (e) {
      _setError("Error finalizing response: $e");
      debugPrint("Error finalizing response: $e");
    }
  }

  /// Calculate and log performance metrics
  void _calculateTokensPerSecond(String response, double elapsedSeconds) {
    if (_currentModel == null) return;

    fllamaTokenize(
          FllamaTokenizeRequest(
            input: response,
            modelPath: _currentModel!.copiedPath,
          ),
        )
        .then((tokenCount) {
          if (elapsedSeconds > 0) {
            final tokensPerSecond = tokenCount / elapsedSeconds;
            debugPrint(
              "Performance: ${tokensPerSecond.toStringAsFixed(2)} tokens/sec",
            );
            _setStatus("Speed: ${tokensPerSecond.toStringAsFixed(1)} tok/s");
          }
        })
        .catchError((e) {
          debugPrint("Error calculating tokens: $e");
        });
  }

  /// Cancel the current generation
  Future<void> cancelGeneration() async {
    if (!_isGenerating || _currentRequestId == null) return;

    try {
      fllamaCancelInference(_currentRequestId!);
      _isGenerating = false;
      _currentRequestId = null;
      _inferenceStartTime = null;
      _streamingResponse = '';

      _setStatus("Generation cancelled");
      notifyListeners();
      debugPrint("Generation cancelled successfully");
    } catch (e) {
      _setError("Error cancelling generation: $e");
      debugPrint("Error cancelling generation: $e");
    }
  }

  /// Clear the conversation history (keeps system prompt)
  void clearHistory() {
    if (_chatHistory.isNotEmpty) {
      final systemPrompt = _chatHistory.first;
      _chatHistory.clear();
      _chatHistory.add(systemPrompt);
      _setStatus("Chat history cleared");
      notifyListeners();
      debugPrint("Chat history cleared");
    }
  }

  /// Get the current chat history as a formatted string
  String getChatHistoryAsString() {
    final buffer = StringBuffer();
    for (int i = 1; i < _chatHistory.length; i++) {
      // Skip system prompt
      final message = _chatHistory[i];
      final role = message.role == Role.user ? 'User' : 'Assistant';
      buffer.writeln('$role: ${message.toString()}');
      buffer.writeln();
    }
    return buffer.toString();
  }

  /// Set status message
  void _setStatus(String status) {
    _status = status;
    notifyListeners();
  }

  /// Set error message
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// Clear error
  void _clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clear error (public method)
  void clearError() {
    _clearError();
  }

  /// Reset the provider
  void reset() {
    _isInitialized = false;
    _isGenerating = false;
    _currentModel = null;
    _chatHistory.clear();
    _streamingResponse = '';
    _status = '';
    _error = null;
    _currentRequestId = null;
    _inferenceStartTime = null;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_currentRequestId != null) {
      fllamaCancelInference(_currentRequestId!);
    }
    super.dispose();
  }
}
