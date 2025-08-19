import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:krishi_sakha/models/llm_model.dart';
import 'package:krishi_sakha/providers/llama_provider.dart';
import 'package:krishi_sakha/utils/theme/colors.dart';

class ChatScreen extends StatefulWidget {
  final LlmModel model;

  const ChatScreen({super.key, required this.model});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _initializeLlama();

    // Add listener to text controller to rebuild when text changes
    _messageController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeLlama() async {
    final llamaProvider = Provider.of<LlamaProvider>(context, listen: false);
    try {
      await llamaProvider.initialize(widget.model);
    } catch (e) {
      _showError('Failed to initialize AI model: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlack,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlack,
        foregroundColor: AppColors.primaryWhite,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.model.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Consumer<LlamaProvider>(
              builder: (context, llamaProvider, child) {
                return Text(
                  llamaProvider.status.isNotEmpty
                      ? llamaProvider.status
                      : 'Ready',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.withValues(alpha: 0.7),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          Consumer<LlamaProvider>(
            builder: (context, llamaProvider, child) {
              if (llamaProvider.isGenerating) {
                return IconButton(
                  onPressed: () => llamaProvider.cancelGeneration(),
                  icon: const Icon(Icons.stop),
                  tooltip: 'Stop generation',
                );
              }
              return const SizedBox.shrink();
            },
          ),
          if (_messages.isNotEmpty)
            IconButton(
              onPressed: _clearChat,
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear chat',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return Consumer<LlamaProvider>(
      builder: (context, llamaProvider, child) {
        if (_messages.isEmpty && !llamaProvider.isGenerating) {
          return _buildEmptyState();
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _messages.length + (llamaProvider.isGenerating ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _messages.length && llamaProvider.isGenerating) {
              return _buildStreamingMessage(llamaProvider.streamingResponse);
            }

            final message = _messages[index];
            return _buildMessageBubble(message);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Ask Me Anything',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryWhite,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a conversation with AI',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStreamingMessage(String streamingText) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.2),
            child: const Icon(
              Icons.smart_toy,
              size: 16,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(
                  16,
                ).copyWith(bottomLeft: const Radius.circular(4)),
                border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (streamingText.isNotEmpty)
                    Text(
                      streamingText,
                      style: const TextStyle(
                        color: AppColors.primaryWhite,
                        fontSize: 16,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(3, (index) {
                            return AnimatedContainer(
                              duration: Duration(
                                milliseconds: 600 + (index * 200),
                              ),
                              curve: Curves.easeInOut,
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryGreen,
                                shape: BoxShape.circle,
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'AI is typing...',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(false),
          const SizedBox(width: 12),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primaryGreen
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isUser ? const Radius.circular(4) : null,
                  bottomLeft: !isUser ? const Radius.circular(4) : null,
                ),
                border: !isUser
                    ? Border.all(
                        color: Colors.grey.withValues(alpha: 0.2),
                        width: 1,
                      )
                    : null,
              ),
              padding: const EdgeInsets.all(16),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isUser
                      ? AppColors.primaryBlack
                      : AppColors.primaryWhite,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (isUser) _buildAvatar(true),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isUser) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: isUser
          ? AppColors.primaryGreen.withValues(alpha: 0.2)
          : AppColors.primaryGreen.withValues(alpha: 0.2),
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy,
        size: 16,
        color: AppColors.primaryGreen,
      ),
    );
  }

  Widget _buildInputArea() {
    return Consumer<LlamaProvider>(
      builder: (context, llamaProvider, child) {
        final canSend =
            llamaProvider.isInitialized && !llamaProvider.isGenerating;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryBlack,
            border: Border(
              top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  enabled: canSend,
                  maxLines: null,
                  style: const TextStyle(color: AppColors.primaryWhite),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: canSend
                        ? 'Type a message...'
                        : 'Initializing AI model...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: canSend ? (_) => _sendMessage() : null,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: _canSendMessage()
                      ? AppColors.primaryGreen
                      : Colors.grey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  onPressed: _canSendMessage() ? _sendMessage : null,
                  icon: const Icon(Icons.send),
                  color: AppColors.primaryBlack,
                  tooltip: 'Send message',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _canSendMessage() {
    final llamaProvider = Provider.of<LlamaProvider>(context, listen: false);
    return llamaProvider.isInitialized &&
        !llamaProvider.isGenerating &&
        _messageController.text.trim().isNotEmpty;
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
    });

    final llamaProvider = Provider.of<LlamaProvider>(context, listen: false);
    llamaProvider.clearHistory();
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    final llamaProvider = Provider.of<LlamaProvider>(context, listen: false);

    // Add user message
    setState(() {
      _messages.add(ChatMessage(content: messageText, isUser: true));
    });

    // Clear input
    _messageController.clear();

    // Scroll to bottom
    _scrollToBottom();

    try {
      // Send message to LlamaProvider
      await llamaProvider.sendMessage(messageText);

      // Wait for response to complete and add it
      _waitForResponse(llamaProvider);
    } catch (e) {
      _showError('Failed to send message: $e');
    }
  }

  void _waitForResponse(LlamaProvider llamaProvider) {
    String lastStreamingResponse = '';
    bool wasGenerating = true;
    bool responseAdded = false;
    
    void checkStatus() {
      // Capture the streaming response while it's being generated
      if (llamaProvider.isGenerating && llamaProvider.streamingResponse.isNotEmpty) {
        lastStreamingResponse = llamaProvider.streamingResponse;
      }
      
      // Check if generation just completed
      if (wasGenerating && !llamaProvider.isGenerating && !responseAdded) {
        // Generation completed, add the final response
        if (lastStreamingResponse.isNotEmpty) {
          setState(() {
            _messages.add(ChatMessage(content: lastStreamingResponse, isUser: false));
          });
          responseAdded = true;
          _scrollToBottom();
          return; // Stop monitoring
        }
      }
      
      // Update the generation state
      wasGenerating = llamaProvider.isGenerating;
      
      // Continue monitoring if still generating or no response captured yet
      if (llamaProvider.isGenerating || (lastStreamingResponse.isEmpty && !responseAdded)) {
        Future.delayed(const Duration(milliseconds: 100), checkStatus);
      }
    }
    
    // Start monitoring
    checkStatus();
  }

  void _scrollToBottom() {
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

// Simple chat message class
class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.content,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}