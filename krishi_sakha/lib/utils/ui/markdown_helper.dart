import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:krishi_sakha/utils/theme/colors.dart';
import 'package:url_launcher/url_launcher.dart';

Widget buildMarkdownText(String data) {
  return MarkdownBody(
    data: data, 
    onTapLink: (text, href, title) {
      if(href != null) {
        launchUrl(Uri.parse(href));
      }
    },
    styleSheet: MarkdownStyleSheet(
      p: const TextStyle(
        color: AppColors.primaryWhite,
        fontSize: 16,
        height: 1.6,
      ),
      a: TextStyle(
        color: AppColors.primaryGreen,
        decoration: TextDecoration.underline,
      ),
      h1: const TextStyle(
        color: AppColors.primaryWhite,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      h2: const TextStyle(
        color: AppColors.primaryWhite,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      h3: const TextStyle(
        color: AppColors.primaryWhite,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      strong: const TextStyle(
        color: AppColors.primaryWhite,
        fontWeight: FontWeight.bold,
      ),
      em: const TextStyle(
        color: AppColors.primaryWhite,
        fontStyle: FontStyle.italic,
      ),
      code: TextStyle(
        color: AppColors.primaryGreen,
        backgroundColor: Colors.grey.withOpacity(0.1),
        fontFamily: 'monospace',
      ),
      codeblockDecoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      blockquote: const TextStyle(
        color: AppColors.primaryWhite,
        fontStyle: FontStyle.italic,
      ),
      listBullet: const TextStyle(
        color: AppColors.primaryGreen,
      ),
    ),
    selectable: true,
  );
}