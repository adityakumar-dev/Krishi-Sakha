import 'dart:async';
import 'dart:io';
import 'package:fllama/fllama.dart';
import 'package:flutter/foundation.dart';

/// -----------------------------------------------------------------
/// CONSTANTS
///
/// A single place to configure the model and its parameters.
/// -----------------------------------------------------------------
class LlamaSetup {
  // --- Model Configuration ---
  static const String modelName = 'model.gguf'; // Your model file name
  
  // --- System Prompt ---
  static const String systemPrompt = 'You are a helpful and concise assistant.';

  // --- Inference Parameters ---
  static const int maxTokens = 512;
  static const double temperature = 0.7;
  static const double topP = 0.9;
  static const double presencePenalty = 1.1;
  static const int contextSize = 4096;
  static const int numGpuLayers = 0; // Disabled for CPU-only inference
}

/// -----------------------------------------------------------------
/// LLAMA SERVICE
///
/// A singleton service that handles fllama interactions.
/// Provides streaming responses and manages chat state.
/// -----------------------------------------------------------------
class LlamaService {
  // --- Private State ---
  String? _modelPath;
  final List<Message> _chatHistory = [];
  bool _isInitialized = false;
  bool _isGenerating = false;
  int? _currentRequestId;
  DateTime? _inferenceStartTime;

  // --- Stream Controllers ---
  final _responseController = StreamController<String>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  // --- Singleton Setup ---
  LlamaService._privateConstructor();
  static final LlamaService instance = LlamaService._privateConstructor();

  // --- Public Accessors ---
  Stream<String> get responseStream => _responseController.stream;
  Stream<String> get statusStream => _statusController.stream;
  bool get isInitialized => _isInitialized;
  bool get isGenerating => _isGenerating;

  /// Initializes the service with the model path
  Future<void> initialize(String modelPath) async {
    if (_isInitialized) {
      print("LlamaService is already initialized.");
      return;
    }

    // Web platform is not supported
    if (kIsWeb) {
      _statusController.add("Web platform not supported");
      return;
    }

    try {
      print("Initializing LlamaService...");
      
      // Validate model file exists
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        throw Exception("Model file not found at: $modelPath");
      }

      _modelPath = modelPath;
      _chatHistory.clear();
      _chatHistory.add(Message(Role.system, LlamaSetup.systemPrompt));
      _isInitialized = true;
      
      _statusController.add("LlamaService initialized successfully");
      print("LlamaService initialized with model: $modelPath");
    } catch (e) {
      _statusController.add("Failed to initialize: $e");
      print("Failed to initialize LlamaService: $e");
      throw e;
    }
  }

  /// Sends a user message and streams the AI response
  Future<void> getChatResponse(String userMessage) async {
    if (!_isInitialized || _modelPath == null) {
      _responseController.addError("Service not initialized. Call initialize() first.");
      return;
    }

    if (_isGenerating) {
      _responseController.addError("Already generating a response. Please wait.");
      return;
    }

    _isGenerating = true;
    _inferenceStartTime = DateTime.now();
    
    // Add user message to history
    _chatHistory.add(Message(Role.user, userMessage));
    
    _statusController.add("Generating response...");

    try {
      final request = OpenAiRequest(
        modelPath: _modelPath!,
        messages: _chatHistory,
        maxTokens: LlamaSetup.maxTokens,
        temperature: LlamaSetup.temperature,
        topP: LlamaSetup.topP,
        presencePenalty: LlamaSetup.presencePenalty,
        contextSize: LlamaSetup.contextSize,
        numGpuLayers: LlamaSetup.numGpuLayers,
        logger: (log) {
          if (!log.contains('<unused') && !log.contains('ggml_')) {
            print('[fllama] $log');
          }
        },
      );

      String fullAssistantResponse = "";
      List<String> allResponses = [];

      _currentRequestId = await fllamaChat(request, (response, responseJson, done) {
        if (!_isGenerating) return; 
        // Calculate new tokens (incremental response)
        final newTokens = response.length > fullAssistantResponse.length 
            ? response.substring(fullAssistantResponse.length)
            : '';
        
        if (newTokens.isNotEmpty) {
          fullAssistantResponse = response;
          allResponses.add(responseJson);
          
          // Stream the new tokens to UI
          _responseController.add(newTokens);
        }

        if (done) {
          _finalizeChatResponse(fullAssistantResponse);
        }
      });

    } catch (e) {
      _responseController.addError("Error during chat: $e");
      _statusController.add("Error: $e");
      _isGenerating = false;
      _currentRequestId = null;
      print("Chat error: $e");
    }
  }

  /// Finalizes the chat response and updates history
  void _finalizeChatResponse(String fullResponse) {
    try {
      // Add assistant response to history
      _chatHistory.add(Message(Role.assistant, fullResponse));
      
      // Calculate performance metrics
      if (_inferenceStartTime != null) {
        final elapsedSeconds = DateTime.now()
            .difference(_inferenceStartTime!)
            .inMilliseconds / 1000.0;
        
        // Optional: Calculate tokens per second
        _calculateTokensPerSecond(fullResponse, elapsedSeconds);
      }

      _isGenerating = false;
      _currentRequestId = null;
      _inferenceStartTime = null;
      
      _statusController.add("Response completed");
      print("Chat response completed successfully");
      
    } catch (e) {
      print("Error finalizing response: $e");
      _statusController.add("Error finalizing response: $e");
    }
  }

  /// Optional: Calculate and log performance metrics
  void _calculateTokensPerSecond(String response, double elapsedSeconds) {
    if (_modelPath == null) return;
    
    fllamaTokenize(FllamaTokenizeRequest(
      input: response, 
      modelPath: _modelPath!
    )).then((tokenCount) {
      if (elapsedSeconds > 0) {
        final tokensPerSecond = tokenCount / elapsedSeconds;
        print("Performance: ${tokensPerSecond.toStringAsFixed(2)} tokens/sec");
        _statusController.add("Speed: ${tokensPerSecond.toStringAsFixed(1)} tok/s");
      }
    }).catchError((e) {
      print("Error calculating tokens: $e");
    });
  }

  /// Cancels the current generation
  Future<void> cancelGeneration() async {
    if (!_isGenerating || _currentRequestId == null) return;

    try {
       fllamaCancelInference(_currentRequestId!);
      _isGenerating = false;
      _currentRequestId = null;
      _inferenceStartTime = null;
      
      _statusController.add("Generation cancelled");
      print("Generation cancelled successfully");
    } catch (e) {
      print("Error cancelling generation: $e");
      _statusController.add("Error cancelling: $e");
    }
  }

  /// Clears the conversation history (keeps system prompt)
  void clearHistory() {
    if (_chatHistory.isNotEmpty) {
      final systemPrompt = _chatHistory.first;
      _chatHistory.clear();
      _chatHistory.add(systemPrompt);
      _statusController.add("Chat history cleared");
      print("Chat history cleared");
    }
  }

  /// Gets the current chat history as a formatted string
  String getChatHistoryAsString() {
    final buffer = StringBuffer();
    for (int i = 1; i < _chatHistory.length; i++) { // Skip system prompt
      final message = _chatHistory[i];
      final role = message.role == Role.user ? 'User' : 'Assistant';
      buffer.writeln('$role: ${message}');
      buffer.writeln();
    }
    return buffer.toString();
  }

  /// Gets the number of messages in history (excluding system prompt)
  int get messageCount => _chatHistory.length - 1;

  /// Disposes of resources
  void dispose() {
    if (_currentRequestId != null) {
      fllamaCancelInference(_currentRequestId!);
    }
    _responseController.close();
    _statusController.close();
    _isInitialized = false;
    print("LlamaService disposed");
  }
}