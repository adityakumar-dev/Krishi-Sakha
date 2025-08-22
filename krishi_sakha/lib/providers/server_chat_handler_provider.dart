import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:krishi_sakha/apis/api_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

enum MessageStatus {
  sent,
  failed
}

class ChatMessage {
  final String id;
  final int conversationId;
  final String userId;
  final String sender;
  final String message;
  final DateTime createdAt;
  final MessageStatus status;
  final Map<String, dynamic> metadata;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.sender,
    required this.message,
    required this.createdAt,
    this.status = MessageStatus.sent,
    this.metadata = const {},
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'].toString(),
      conversationId: json['conversation_id'],
      userId: json['user_id'],
      sender: json['sender'],
      message: json['message'],
      createdAt: DateTime.parse(json['created_at']),
      status: MessageStatus.sent,
      metadata: _normalizeMetadata((json['metadata'] as Map<String, dynamic>?) ?? const {}),
    );
  }

  static Map<String, dynamic> _normalizeMetadata(Map<String, dynamic> rawMetadata) {
    Map<String, dynamic> normalized = Map<String, dynamic>.from(rawMetadata);
    
    // Normalize URLs: ensure they're in the 'urls' key as a List
    if (rawMetadata.containsKey('url') && rawMetadata['url'] is List) {
      normalized['urls'] = rawMetadata['url'];
      // Remove the original 'url' key to avoid duplication
      normalized.remove('url');
    }
    
    // Normalize YouTube: handle all possible backend formats
    List<dynamic>? youtubeData;
    
    // Check for direct 'youtube' key
    if (rawMetadata.containsKey('youtube') && rawMetadata['youtube'] is List) {
      youtubeData = rawMetadata['youtube'] as List;
    }
    // Check for 'youtberelated' as direct list (new backend format)
    else if (rawMetadata.containsKey('youtberelated') && rawMetadata['youtberelated'] is List) {
      youtubeData = rawMetadata['youtberelated'] as List;
    }
    // Check for 'youtberelated' as map containing 'youtube_urls' (old format)
    else if (rawMetadata.containsKey('youtberelated') && rawMetadata['youtberelated'] is Map<String, dynamic>) {
      final youtberelated = rawMetadata['youtberelated'] as Map<String, dynamic>;
      if (youtberelated.containsKey('youtube_urls') && youtberelated['youtube_urls'] is List) {
        youtubeData = youtberelated['youtube_urls'] as List;
      }
    }
    
    // Set the normalized YouTube data if we found any
    if (youtubeData != null && youtubeData.isNotEmpty) {
      normalized['youtube'] = youtubeData;
      // Clean up old keys
      normalized.remove('youtberelated');
    }
    
    return normalized;
  }

  ChatMessage copyWith({
    String? id,
    int? conversationId,
    String? userId,
    String? sender,
    String? message,
    DateTime? createdAt,
    MessageStatus? status,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      userId: userId ?? this.userId,
      sender: sender ?? this.sender,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
    );
  }
}

class ServerChatHandlerProvider extends ChangeNotifier {
  // Conversation state
  int _actualConversationId = -1;
  String _actualConversationTitle = '';
  List<ChatMessage> _messages = [];
  XFile? _currentImage;

  // UI state
  bool _isSending = false;
  bool _isLoading = false;
  String _status = '';
  String _lastStreamingResponse = '';
  Map<String, dynamic> _currentMetadata = {};
  String? _error;

  // Controllers
  late final TextEditingController _messageController;
  late final ScrollController _scrollController;

  // Network
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<String>? _streamSubscription;

  ServerChatHandlerProvider() {
    _messageController = TextEditingController();
    _scrollController = ScrollController();
  }

  // Getters
  int get actualConversationId => _actualConversationId;
  String get actualConversationTitle => _actualConversationTitle;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isSending => _isSending;
  bool get isLoading => _isLoading;
  String get status => _status;
  String get lastStreamingResponse => _lastStreamingResponse;
  Map<String, dynamic> get currentMetadata => _currentMetadata;
  String? get error => _error;
  // Allow sending if there's either text or an image selected
  bool get canSend => !_isSending && !_isLoading && (_messageController.text.trim().isNotEmpty || _currentImage != null);

  TextEditingController get messageController => _messageController;
  ScrollController get scrollController => _scrollController;
  // Optional getter for current image if UI wants to show a preview
  XFile? get currentImage => _currentImage;

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _currentImage = null;
    super.dispose();
  }

  void setIdAndTitle(int id, String title) {
    _clearState();
    _actualConversationId = id;
    _actualConversationTitle = title;
    _error = null;
    notifyListeners();
    // Trigger message fetch after state is set
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_actualConversationId != -1) {
        fetchMessages(null);
      }
    });
  }

  void clearAllData() {
    _clearState();
    _actualConversationId = -1;
    _actualConversationTitle = '';
    notifyListeners();
  }

  void _clearState() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _status = '';
    _lastStreamingResponse = '';
    _currentMetadata = {};
    _isSending = false;
    _isLoading = false;
    _messages.clear();
    _error = null;
    _messageController.clear();
    _currentImage = null;
  }

  void _setError(String errorMessage) {
    _error = errorMessage;
    _status = '';
    _isSending = false;
    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void setImage(XFile? file) {
    _currentImage = file;
    notifyListeners();
  }

  Future<void> fetchMessages(BuildContext? context) async {
    if (_actualConversationId == -1) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _supabase
          .from('chat_messages')
          .select('*')
          .eq('conversation_id', _actualConversationId)
          .order('id', ascending: true);

      _messages = List<ChatMessage>.from(
        (response as List).map((json) => ChatMessage.fromJson(json)),
      );

      _isLoading = false;
      notifyListeners();

      // Auto-scroll to bottom after loading messages
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToBottom();
      });
    } catch (e) {
      _isLoading = false;
      _setError('Failed to load messages: ${e.toString()}');
    }
  }

  Future<void> createConversation(BuildContext context, String title) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('conversations')
          .insert({
            'title': title,
            'user_id': user.id,
          })
          .select()
          .single();

      _actualConversationId = response['id'];
      _actualConversationTitle = title;
      _error = null;
      notifyListeners();
    } catch (e) {
      _setError('Failed to create conversation: ${e.toString()}');
      rethrow;
    }
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> retryLastMessage() async {
    clearError();

    // Retry the last user message if it exists
    if (_messages.isNotEmpty) {
      final lastUserMessage = _messages.reversed.firstWhere(
        (msg) => msg.sender == 'user',
        orElse: () => _messages.last,
      );

      await _sendMessageInternal(lastUserMessage.message);
    }
  }

  Future<void> sendMessage(BuildContext context) async {
    if (_isSending || _isLoading) return;
    final text = _messageController.text.trim();
    // Allow sending if either text or image is present
    if (text.isEmpty && _currentImage == null) return;

    try {
      // Create conversation on first message
      if (_actualConversationId == -1) {
        String base = text.isNotEmpty ? text : 'Image message';
        String title = base.length > 20 ? base.substring(0, 20) : base;
        await createConversation(context, title);
      }

      await _sendMessageInternal(text);
      _messageController.clear();
    } catch (e) {
      _setError('Failed to send message: ${e.toString()}');
    }
  }

  Future<void> _sendMessageInternal(String text) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Create and add user message locally
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: _actualConversationId,
      userId: user.id,
      sender: 'user',
      message: text,
      createdAt: DateTime.now(),
    );

    _messages.add(userMessage);
    notifyListeners();
    scrollToBottom();

    // Insert user message in database
    try {
      await _supabase.from('chat_messages').insert({
        'conversation_id': _actualConversationId,
        'user_id': user.id,
        'sender': 'user',
        'message': text,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // If DB insert fails, remove the local message
      _messages.removeWhere((msg) => msg.id == userMessage.id);
      notifyListeners();
      throw Exception('Failed to save message: ${e.toString()}');
    }

    // Start streaming request
    await _startStreamingRequest(text, user);
  }

  Future<void> _startStreamingRequest(String text, User user) async {
    _isSending = true;
    _status = _currentImage != null ? "Processing uploaded image..." : "Processing query...";
    _lastStreamingResponse = '';
    _currentMetadata = {};
    _error = null;
    notifyListeners();

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiManager.baseUrl + ApiManager.chatUrl),
      );

      final session = _supabase.auth.currentSession;
      if (session?.accessToken == null) {
        throw Exception('Authentication required. Please log in again.');
      }

      request.headers['Authorization'] = 'Bearer ${session!.accessToken}';
      request.headers['ngrok-skip-browser-warning'] = 'true';
      request.fields['conversation_id'] = _actualConversationId.toString();
      request.fields['prompt'] = text;
      
      // Get last 5 messages safely
      final startIndex = _messages.length > 5 ? _messages.length - 5 : 0;
      final last5Message = _messages.sublist(startIndex);
      final jsonHistory = last5Message.map((msg) => {
        'role': msg.sender,
        'content': msg.message,
      }).toList();
      request.fields['history'] = jsonEncode(jsonHistory);
      
      debugPrint('Sending request with history: $jsonHistory');
      
      // Add image if present
      if (_currentImage != null) {
        try {
          request.files.add(
            await http.MultipartFile.fromPath('image', _currentImage!.path),
          );
          debugPrint('Image added to request: ${_currentImage!.path}');
        } catch (e) {
          debugPrint('Error adding image to request: $e');
          throw Exception('Failed to process image. Please try again.');
        }
      }

      final streamed = await request.send().timeout(
        const Duration(seconds: 60), // Increased timeout for image processing
        onTimeout: () => throw Exception('Request timeout. Please try again.'),
      );

      // Reset selected image after request is sent successfully
      _currentImage = null;
      notifyListeners();

      if (streamed.statusCode == 401) {
        throw Exception('Authentication expired. Please log in again.');
      } else if (streamed.statusCode == 500) {
        throw Exception('Server error. Please try again later.');
      } else if (streamed.statusCode != 200) {
        throw Exception(
          'Network error (${streamed.statusCode}). Please check your connection.',
        );
      }

      await _streamSubscription?.cancel();

      _streamSubscription = streamed.stream
          .transform(utf8.decoder)
          .listen(
            _handleStreamChunk,
            onError: (error) {
              // Ignore all stream errors
              _handleStreamError(error);
            },
            onDone: () {
              _streamSubscription = null;
              // If streaming ends without completion, finalize anyway
              if (_isSending) {
                _completeStreaming();
              }
            },
            cancelOnError: false, // Don't cancel stream on errors
          );
    } catch (e) {
      debugPrint('Request error: $e');
      // Reset image on error so user can retry
      _currentImage = null;
      _setError('Failed to send request: ${e.toString()}');
    }
  }

  void _handleStreamChunk(String chunk) {
    if (chunk.isEmpty) return;

    // DEBUG: Log all chunks
    debugPrint('🔴 RAW CHUNK: $chunk');

    try {
      final lines = chunk.split('\n');
      for (final line in lines) {
        try {
          final trimmedLine = line.trim();
          if (trimmedLine.isEmpty) continue;

          String jsonStr = trimmedLine;
          if (jsonStr.startsWith('data: ')) {
            jsonStr = jsonStr.substring(6).trim();
          }

          if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;

          // DEBUG: Log parsed JSON string
          debugPrint('🔵 JSON STRING: $jsonStr');

          // Try to parse JSON, ignore any errors
          dynamic data;
          try {
            data = jsonDecode(jsonStr);
            debugPrint('🟢 PARSED DATA: $data');
          } catch (e) {
            debugPrint('🔴 JSON PARSE ERROR: $e');
            // Ignore JSON parse errors and continue
            continue;
          }

          // Ignore null or invalid data
          if (data == null || data is! Map<String, dynamic>) continue;

          final type = data['type'];
          if (type == null || type is! String) continue;

          debugPrint('🟡 CHUNK TYPE: $type');

          switch (type) {
            case 'status':
              try {
                final message = data['message'];
                if (message != null && message is String && message.isNotEmpty) {
                  _status = message;
                  notifyListeners();
                }
              } catch (e) {
                // Ignore status update errors
              }
              break;

            case 'metadata':
              try {
                final metadata = data['metadata'];
                debugPrint('📨 RECEIVED METADATA CHUNK: $metadata');
                Fluttertoast.showToast(msg: 'Received metadata chunk');
                Fluttertoast.showToast(msg: 'Metadata: $metadata', toastLength: Toast.LENGTH_LONG);
                if (metadata != null && metadata is Map<String, dynamic>) {
                  // Clear existing metadata and process the new data
                  _currentMetadata.clear();
                  
                  // Handle URLs - ensure they're in the 'urls' key as a List
                  if (metadata.containsKey('url') && metadata['url'] is List) {
                    _currentMetadata['urls'] = metadata['url'];
                    debugPrint('   Added URLs from url key: ${metadata['url']}');
                  }
                  if (metadata.containsKey('urls') && metadata['urls'] is List) {
                    _currentMetadata['urls'] = metadata['urls'];
                    debugPrint('   Added URLs from urls key: ${metadata['urls']}');
                  }
                  
                  // Handle YouTube videos - ensure they're in the 'youtube' key as a List
                  if (metadata.containsKey('youtberelated') && metadata['youtberelated'] is List) {
                    _currentMetadata['youtube'] = metadata['youtberelated'];
                    debugPrint('   Added YouTube from youtberelated (List): ${metadata['youtberelated']}');
                  }
                  if (metadata.containsKey('youtube') && metadata['youtube'] is List) {
                    _currentMetadata['youtube'] = metadata['youtube'];
                    debugPrint('   Added YouTube from youtube key: ${metadata['youtube']}');
                  }
                  
                  // Also handle if youtberelated contains nested youtube_urls
                  if (metadata.containsKey('youtberelated') && metadata['youtberelated'] is Map<String, dynamic>) {
                    final youtberelated = metadata['youtberelated'] as Map<String, dynamic>;
                    if (youtberelated.containsKey('youtube_urls') && youtberelated['youtube_urls'] is List) {
                      _currentMetadata['youtube'] = youtberelated['youtube_urls'];
                      debugPrint('   Added YouTube from youtberelated.youtube_urls: ${youtberelated['youtube_urls']}');
                    }
                  }
                  
                  debugPrint('   Final _currentMetadata: $_currentMetadata');
                  notifyListeners();
                }
              } catch (e) {
                debugPrint('❌ Error processing metadata chunk: $e');
              }
              break;

            case 'text':
              try {
                final textChunk = data['chunk'];
                if (textChunk != null && textChunk is String) {
                  _lastStreamingResponse += textChunk;
                  _status = 'Generating response...';
                  notifyListeners();
                }
              } catch (e) {
                // Ignore text chunk errors
              }
              break;

            case 'complete':
              try {
                _completeStreaming();
              } catch (e) {
                // Even if completion fails, reset state
                _isSending = false;
                _status = '';
                notifyListeners();
              }
              break;

            case 'error':
              // Ignore backend errors and continue as if nothing happened
              break;
          }
        } catch (e) {
          // Ignore any line processing errors and continue
          continue;
        }
      }
    } catch (e) {
      // Ignore all chunk processing errors
    }
  }

  void _completeStreaming() {
    try {
      // Always create assistant message, even if response is empty
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final responseText = _lastStreamingResponse.isNotEmpty
            ? _lastStreamingResponse
            : 'Sorry, I encountered an issue generating a response.';

        // Create assistant message with empty metadata initially
        final assistantMessage = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          conversationId: _actualConversationId,
          userId: user.id,
          sender: 'assistant',
          message: responseText,
          createdAt: DateTime.now(),
          metadata: {},
        );

        _messages.add(assistantMessage);
        notifyListeners();

        // Save to database and then fetch back with metadata
        _saveAssistantMessageAndFetchMetadata(assistantMessage, responseText);
      }
    } catch (e) {
      debugPrint('❌ Error in _completeStreaming: $e');
    } finally {
      _isSending = false;
      _status = '';
      _lastStreamingResponse = '';
      _currentMetadata = {};
      notifyListeners();
      scrollToBottom();
    }
  }

  Future<void> _saveAssistantMessageAndFetchMetadata(ChatMessage assistantMessage, String responseText) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      Map<String, dynamic>? fetchedMetadata;
      int attempts = 0;
      const maxAttempts = 5;
      
      while (attempts < maxAttempts && fetchedMetadata == null) {
        attempts++;
        final delayMs = attempts * 1000; // 1s, 2s, 3s, 4s, 5s
        
        debugPrint('🔄 Attempt $attempts: Waiting ${delayMs}ms before fetching...');
        await Future.delayed(Duration(milliseconds: delayMs));

        // Fetch the last assistant message from database to get its metadata
        final response = await _supabase
            .from('chat_messages')
            .select('*')
            .eq('conversation_id', _actualConversationId)
            .eq('sender', 'assistant')
            .order('created_at', ascending: false)
            .limit(1);

        if (response.isNotEmpty) {
          final lastMessage = response.first;
          final metadata = lastMessage['metadata'];
          
          debugPrint('🔍 Attempt $attempts - Fetched metadata: $metadata');
          
          if (metadata != null && metadata is Map<String, dynamic> && metadata.isNotEmpty) {
            fetchedMetadata = metadata;
            debugPrint('✅ Found metadata on attempt $attempts!');
            break;
          } else {
            debugPrint('⚠️ Attempt $attempts - No metadata yet, retrying...');
          }
        } else {
          debugPrint('⚠️ Attempt $attempts - Could not fetch message, retrying...');
        }
      }

      if (fetchedMetadata != null) {
        // Normalize the metadata from database
        final normalizedMetadata = ChatMessage._normalizeMetadata(fetchedMetadata);
        debugPrint('✅ Final normalized database metadata: $normalizedMetadata');
        
        // Find the assistant message in our local list and update its metadata
        final messageIndex = _messages.indexWhere((msg) => msg.id == assistantMessage.id);
        if (messageIndex != -1) {
          // Create a new message with updated metadata
          final updatedMessage = ChatMessage(
            id: assistantMessage.id,
            conversationId: assistantMessage.conversationId,
            userId: assistantMessage.userId,
            sender: assistantMessage.sender,
            message: assistantMessage.message,
            createdAt: assistantMessage.createdAt,
            metadata: normalizedMetadata,
          );
          
          _messages[messageIndex] = updatedMessage;
          debugPrint('🎯 Updated local message with metadata from database');
          notifyListeners();
        }
      } else {
        debugPrint('❌ Failed to fetch metadata after $maxAttempts attempts');
      }
    } catch (e) {
      debugPrint('❌ Error in _saveAssistantMessageAndFetchMetadata: $e');
      // Don't throw error - this is a fallback mechanism
    }
  }

  void _handleStreamError(dynamic error) {
    debugPrint('Stream error: $error');
    _isSending = false;
    _lastStreamingResponse = '';
    _currentMetadata = {};
    _status = '';

    // Show error to user for debugging
    _setError('Connection error: ${error.toString()}');
  }
}
