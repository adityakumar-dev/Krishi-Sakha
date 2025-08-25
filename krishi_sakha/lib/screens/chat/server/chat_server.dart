import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:krishi_sakha/utils/ui/markdown_helper.dart';
import 'package:krishi_sakha/widgets/url_modal.dart';
import 'package:krishi_sakha/widgets/youtube_widget.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:krishi_sakha/providers/server_chat_handler_provider.dart';
import 'package:krishi_sakha/utils/theme/colors.dart';
import 'package:krishi_sakha/widgets/youtube_player_dialog.dart';

class ChatServerScreen extends StatefulWidget {
  const ChatServerScreen({super.key});

  @override
  State<ChatServerScreen> createState() => _ChatServerScreenState();
}

class _ChatServerScreenState extends State<ChatServerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ServerChatHandlerProvider>(context, listen: false);
      // Only fetch if we have a conversation ID and no messages loaded
      if (provider.actualConversationId != -1 && provider.messages.isEmpty) {
        provider.fetchMessages(context);
      }
      provider.messageController.addListener(() {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    // Do not dispose provider-owned controllers here
    super.dispose();
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
            Consumer<ServerChatHandlerProvider>(
              builder: (context, provider, child) {
                return Text(
                  provider.actualConversationTitle.isNotEmpty 
                      ? provider.actualConversationTitle 
                      : 'Chat',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                );
                
              },
            ),
            Consumer<ServerChatHandlerProvider>(
              builder: (context, provider, child) {
                String status = 'Ready';
                if (provider.isLoading) {
                  status = 'Loading...';
                } else if (provider.isSending) {
                  status = provider.status.isNotEmpty ? provider.status : 'Generating response...';
                } else if (provider.error != null) {
                  status = 'Error occurred';
                }
                
                return Text(
                  status,
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
          IconButton(onPressed: ()async{
              
            // Use FilePicker for desktop (Linux/Windows/macOS) compatibility.
            // image_picker is not supported on Linux; FilePicker works across desktop and mobile.
            final result = await FilePicker.platform.pickFiles(
              type: FileType.image,
              allowMultiple: false,
            );

            if (!mounted) return;

            if (result != null && result.files.single.path != null) {
              final path = result.files.single.path!;
              // Convert to XFile for provider compatibility
              final xFile = XFile(path);
              context.read<ServerChatHandlerProvider>().setImage(xFile);

              ScaffoldMessenger.of(context).showMaterialBanner(
                MaterialBanner(
                  content: const Text("Image Selected"),
                  actions: [
                    IconButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context)..hideCurrentMaterialBanner();
                      },
                      icon: const Icon(Icons.close),
                    )
                  ],
                ),
              );
            } else {
              // Optional: give feedback when user cancels or selection fails
              Fluttertoast.showToast(msg: 'No image selected');
            }

          }, icon: Icon(Icons.attach_file_outlined))
        ],

      ),
      body: Column(
        children: [
          Consumer<ServerChatHandlerProvider>(
            builder: (context, provider, child) {
              if (provider.error != null) {
                return _buildErrorBanner(provider);
              }
              return const SizedBox.shrink();
            },
          ),
          Expanded(child: _buildMessageList()),
          _buildInputArea(),
        ],
      ),
      floatingActionButton: Consumer<ServerChatHandlerProvider>(
        builder: (context, provider, child) {
          if (provider.showScrollToBottom) {
            return FloatingActionButton.small(
              onPressed: provider.scrollToBottomManually,
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.primaryBlack,
              child: const Icon(Icons.keyboard_arrow_down),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildErrorBanner(ServerChatHandlerProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              provider.error!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ),
          TextButton(
            onPressed: () => provider.clearError(),
            child: const Text('Dismiss', style: TextStyle(color: Colors.red)),
          ),
          if (provider.messages.isNotEmpty)
            TextButton(
              onPressed: () => provider.retryLastMessage(),
              child: const Text('Retry', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return Consumer<ServerChatHandlerProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          );
        }

        final hasMessages = provider.messages.isNotEmpty;
        if (!hasMessages && !provider.isSending) {
          return _buildEmptyState();
        }

        final itemCount = provider.messages.length + (provider.isSending ? 1 : 0);
        return ListView.builder(
          controller: provider.scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index == provider.messages.length && provider.isSending) {
              return _buildStreamingMessage(provider.lastStreamingResponse, provider.currentMetadata);
            }

            final message = provider.messages[index];
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
              color: AppColors.primaryBlack,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.forum_outlined,
                  size: 48,
                  color: Colors.grey.withValues(alpha: 0.8),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Start your conversation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ask anything related to farming, crops, weather, and more.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamingMessage(String streamingText, Map<String, dynamic> metadata) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.withValues(alpha: 0.2),
                ),
                child: const Icon(
                  Icons.smart_toy,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.85,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (streamingText.isEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Thinking…',
                              style: TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                          ],
                        )
                      else
                        Text(
                          streamingText,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      if (metadata.isNotEmpty) ..._buildMetadataWidgets(metadata),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.sender == 'user';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUser ? AppColors.primaryGreen : Colors.grey.withValues(alpha: 0.2),
                ),
                child: Icon(
                  isUser ? Icons.person : Icons.smart_toy,
                  size: 18,
                  color: isUser ? AppColors.primaryBlack : Colors.white,
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.85,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser 
                        ? AppColors.primaryGreen 
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    border: isUser ? null : Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildMarkdownText(message.message),
                      if (!isUser && message.metadata.isNotEmpty) 
                        ..._buildMetadataWidgets(message.metadata),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  List<Widget> _buildMetadataWidgets(Map<String, dynamic> metadata) {
    List<Widget> widgets = [];

    // Handle URLs
    if (metadata.containsKey('urls') && metadata['urls'] is List) {
      final urls = metadata['urls'] as List;
      if (urls.isNotEmpty) {
        widgets.add(const SizedBox(height: 8));
        widgets.add(
          UrlDropDown(
            urls: urls.map((url) => url.toString()).toList(),
          ),
        );
      }
    }

    // Handle YouTube videos
    if (metadata.containsKey('youtube') && metadata['youtube'] is List) {
      final videos = metadata['youtube'] as List;
      if (videos.isNotEmpty) {
        widgets.add(const SizedBox(height: 8));
        widgets.add(
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.play_circle_fill, size: 16, color: Colors.red.shade300),
                    const SizedBox(width: 4),
                    Text(
                      'YouTube Videos',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade300,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...videos.take(3).map((video) => youTubeVideoWidget(context, video)),
              ],
            ),
          ),
        );
      }
    }

    return widgets;
  }




  Widget _buildInputArea() {
    return Consumer<ServerChatHandlerProvider>(
      builder: (context, provider, child) {
        final canSend = _canSendMessage(provider);
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.primaryBlack,
            border: const Border(top: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: provider.messageController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: 'Type your message…',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.grey.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: AppColors.primaryGreen),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: canSend ? (_) => provider.sendMessage(context) : null,
                  textInputAction: TextInputAction.send,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: canSend ? AppColors.primaryGreen : Colors.grey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  onPressed: canSend ? () => provider.sendMessage(context) : null,
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

  bool _canSendMessage(ServerChatHandlerProvider provider) {
    return provider.canSend;
  }
}
