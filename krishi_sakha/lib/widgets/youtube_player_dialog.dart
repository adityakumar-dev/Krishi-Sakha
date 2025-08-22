import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:krishi_sakha/utils/theme/colors.dart';

class YouTubePlayerDialog extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String channel;
  final String duration;
  final String thumbnailUrl;

  const YouTubePlayerDialog({
    Key? key,
    required this.videoUrl,
    required this.title,
    this.channel = '',
    this.duration = '',
    this.thumbnailUrl = '',
  }) : super(key: key);

  @override
  State<YouTubePlayerDialog> createState() => _YouTubePlayerDialogState();
}

class _YouTubePlayerDialogState extends State<YouTubePlayerDialog> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    
    final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);
    if (videoId != null) {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: true,
          captionLanguage: 'en',
          useHybridComposition: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header with close button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.primaryBlack,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.primaryWhite,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.title.isNotEmpty ? widget.title : 'YouTube Video',
                      style: const TextStyle(
                        color: AppColors.primaryWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
            // Video Player - Expanded to take available space
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.black,
                child: Center(
                  child: YoutubePlayerBuilder(
                    player: YoutubePlayer(
                      controller: _controller,
                      showVideoProgressIndicator: true,
                      progressIndicatorColor: AppColors.primaryGreen,
                      progressColors: ProgressBarColors(
                        playedColor: AppColors.primaryGreen,
                        handleColor: AppColors.primaryGreen,
                        backgroundColor: Colors.grey.shade800,
                        bufferedColor: Colors.grey.shade600,
                      ),
                      onReady: () {
                        // Player is ready
                      },
                      onEnded: (metaData) {
                        // Video ended - could auto close or show related videos
                      },
                    ),
                    builder: (context, player) {
                      return Column(
                        children: [
                          // Video player takes most of the space
                          Expanded(child: player),
                          // Simple bottom info bar
                          if (widget.channel.isNotEmpty || widget.duration.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              color: AppColors.primaryBlack,
                              child: Row(
                                children: [
                                  if (widget.channel.isNotEmpty) ...[
                                    Icon(
                                      Icons.account_circle,
                                      color: AppColors.primaryGreen,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        widget.channel,
                                        style: TextStyle(
                                          color: AppColors.primaryWhite.withOpacity(0.9),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                  if (widget.duration.isNotEmpty) ...[
                                    if (widget.channel.isNotEmpty) const SizedBox(width: 12),
                                    Icon(
                                      Icons.access_time,
                                      color: AppColors.primaryGreen,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.duration,
                                      style: TextStyle(
                                        color: AppColors.primaryWhite.withOpacity(0.8),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
