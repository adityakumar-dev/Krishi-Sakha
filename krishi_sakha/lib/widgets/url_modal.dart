
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:krishi_sakha/utils/theme/colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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