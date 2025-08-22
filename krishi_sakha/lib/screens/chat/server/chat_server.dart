import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
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
                      Text(
                        message.message,
                        style: TextStyle(
                          color: isUser ? AppColors.primaryBlack : Colors.white,
                          fontSize: 16,
                        ),
                      ),
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
                ...videos.take(3).map((video) => _buildYouTubeVideoWidget(video)),
              ],
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildYouTubeVideoWidget(dynamic video) {
    if (video is! Map<String, dynamic>) return const SizedBox.shrink();
    
    final title = video['title']?.toString() ?? 'Unknown Title';
    final url = video['url']?.toString() ?? '';
    final thumbnail = video['thumbnail']?.toString() ?? '';
    final duration = video['duration']?.toString() ?? '';
    final channel = video['channel']?.toString() ?? '';
    final channelUrl = video['channel_url']?.toString() ?? '';
    final views = video['views']?.toString() ?? '';
    final published = video['published']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _showYouTubePlayerDialog(
          url: url,
          title: title,
          channel: channel,
          duration: duration,
          thumbnailUrl: thumbnail,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 100,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: Colors.grey.withValues(alpha: 0.3),
              ),
              child: Stack(
                children: [
                  thumbnail.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            thumbnail,
                            width: 100,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => 
                                const Icon(Icons.play_arrow, color: Colors.white),
                          ),
                        )
                      : const Icon(Icons.play_arrow, color: Colors.white),
                  if (duration.isNotEmpty)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          duration,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  // Play button overlay
                  Positioned.fill(
                    child: Icon(
                      Icons.play_circle_filled,
                      color: Colors.white.withOpacity(0.9),
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (channel.isNotEmpty)
                    GestureDetector(
                      onTap: () => _launchUrl(channelUrl),
                      child: Text(
                        channel,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (views.isNotEmpty)
                        Flexible(
                          child: Text(
                            views,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (published.isNotEmpty && views.isNotEmpty) ...[
                        Text(
                          ' • ',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            published,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else if (published.isNotEmpty)
                        Flexible(
                          child: Text(
                            published,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Fluttertoast.showToast(msg: 'Could not open link');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error opening link');
    }
  }

  void _showYouTubePlayerDialog({
    required String url,
    required String title,
    String channel = '',
    String duration = '',
    String thumbnailUrl = '',
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return YouTubePlayerDialog(
          videoUrl: url,
          title: title,
          channel: channel,
          duration: duration,
          thumbnailUrl: thumbnailUrl,
        );
      },
    );
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

class UrlDropDown extends StatefulWidget {
  final List<String> urls;
  const UrlDropDown({super.key, required this.urls});

  @override
  State<UrlDropDown> createState() => _UrlDropDownState();
}

class _UrlDropDownState extends State<UrlDropDown>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primaryBlack,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showSourcesModal(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Sources",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:Colors.white,
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
              Icon(Icons.arrow_forward, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showSourcesModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.2,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.primaryBlack,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(color: AppColors.primaryGreen.withOpacity(0.15)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        Icon(Icons.link, color: AppColors.primaryGreen),
                        const SizedBox(width: 8),
                        Text(
                          "Web Sources",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.white.withOpacity(0.08)),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: widget.urls.length,
                      separatorBuilder: (context, i) => Divider(height: 1, color: Colors.white.withOpacity(0.08)),
                      itemBuilder: (context, i) {
                        final url = widget.urls[i];
                        return ListTile(
                          tileColor: Colors.transparent,
                          title: Text(
                            url,
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: Icon(Icons.open_in_new, color: AppColors.primaryGreen, size: 20),
                          onTap: () async {
                            Navigator.of(context).pop();
                            try {
                              final uri = Uri.parse(url);
                              LaunchMode launchMode = LaunchMode.externalApplication;
                              await launchUrl(uri,mode: launchMode);
                              // if (await canLaunchUrl(uri)) {
                              //   await launchUrl(uri, mode: LaunchMode.externalApplication);
                              // } else {
                              //   Fluttertoast.showToast(msg: 'Could not open link');
                              // }
                            } catch (e) {
                              Fluttertoast.showToast(msg: 'Error opening link');
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
