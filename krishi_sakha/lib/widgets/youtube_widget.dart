  import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:krishi_sakha/utils/theme/colors.dart';
import 'package:krishi_sakha/widgets/youtube_player_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

Widget youTubeVideoWidget(BuildContext context, dynamic video) {
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
        onTap: () => showYouTubePlayerDialog(
          context: context,
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


  void showYouTubePlayerDialog({
    required BuildContext context,
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
