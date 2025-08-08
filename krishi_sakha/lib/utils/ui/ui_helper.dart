import 'package:flutter/material.dart';
import 'package:krishi_sakha/utils/theme/colors.dart';

  Widget buildPermissionCard({
    required String title,
    required String description,
    required String iconName,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    IconData getIcon(String iconName) {
      switch (iconName) {
        case 'camera_alt':
          return Icons.camera_alt;
        case 'mic':
          return Icons.mic;
        case 'storage':
          return Icons.storage;
        case 'location_on':
          return Icons.location_on;
        case 'notifications':
          return Icons.notifications;
        default:
          return Icons.help;
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primaryBlack,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isGranted 
                ? AppColors.primaryGreen 
                : AppColors.primaryGreen.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isGranted 
                  ? AppColors.primaryGreen.withOpacity(0.2)
                  : Colors.transparent,
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isGranted 
                    ? AppColors.primaryGreen.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                getIcon(iconName),
                color: isGranted ? AppColors.primaryGreen : Colors.grey,
                size: 24,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isGranted ? AppColors.primaryGreen : AppColors.primaryWhite,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            
            // Check icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isGranted ? AppColors.primaryGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isGranted ? Icons.check : Icons.chevron_right,
                color: isGranted ? AppColors.primaryBlack : Colors.grey,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
