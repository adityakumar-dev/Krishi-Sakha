import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
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

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.sender,
    required this.message,
    required this.createdAt,
    this.status = MessageStatus.sent,
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
    );
  }

  ChatMessage copyWith({
    String? id,
    int? conversationId,
    String? userId,
    String? sender,
    String? message,
    DateTime? createdAt,
    MessageStatus? status,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      userId: userId ?? this.userId,
      sender: sender ?? this.sender,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
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
      request.headers['ngrok-skip-browser-warning'] = 'true'; // Add this for ngrok
      request.fields['conversation_id'] = _actualConversationId.toString();
      request.fields['prompt'] = text;

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
      // Reset image on error so user can retry
      _currentImage = null;
      _handleStreamError(e);
    }
  }

  void _handleStreamChunk(String chunk) {
    if (chunk.isEmpty) return;

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

          // Try to parse JSON, ignore any errors
          dynamic data;
          try {
            data = jsonDecode(jsonStr);
          } catch (e) {
            // Ignore JSON parse errors and continue
            continue;
          }

          // Ignore null or invalid data
          if (data == null || data is! Map<String, dynamic>) continue;

          final type = data['type'];
          if (type == null || type is! String) continue;

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

        final assistantMessage = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          conversationId: _actualConversationId,
          userId: user.id,
          sender: 'assistant',
          message: responseText,
          createdAt: DateTime.now(),
        );

        _messages.add(assistantMessage);

        // Save assistant message to database (ignore any errors)
        try {
          _supabase.from('chat_messages').insert({
            'conversation_id': _actualConversationId,
            'user_id': user.id,
            'sender': 'assistant',
            'message': responseText,
            'created_at': DateTime.now().toIso8601String(),
          }).catchError((e) {
            // Ignore database save errors
          });
        } catch (e) {
          // Ignore all database errors
        }
      }
    } catch (e) {
      // Ignore all completion errors
    } finally {
      _isSending = false;
      _status = '';
      _lastStreamingResponse = '';
      notifyListeners();
      scrollToBottom();
    }
  }

  void _handleStreamError(dynamic error) {
    // Ignore all streaming errors and just reset state
    _isSending = false;
    _lastStreamingResponse = '';
    _status = '';

    // Don't show errors to user, just silently handle them
    notifyListeners();
  }
}
