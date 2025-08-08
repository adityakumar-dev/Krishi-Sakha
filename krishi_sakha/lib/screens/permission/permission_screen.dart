import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:krishi_sakha/utils/ui/ui_helper.dart';
import '../../utils/theme/colors.dart';
import '../../utils/routes/routes.dart';
import '../../controllers/permission_controller.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  final PermissionController _permissionController = PermissionController();
  
  @override
  void initState() {
    super.initState();
    
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: AppColors.primaryBlack,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.primaryBlack,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    
    _permissionController.initializePermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.primaryBlack,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppColors.primaryBlack,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.primaryBlack,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        // leading: IconButton(
        //             onPressed: () => Navigator.pop(context),
        //             icon: const Icon(
        //               Icons.arrow_back,
        //               color: AppColors.primaryGreen,
        //               size: 24,
        //             ),
        //           ),
                  title: const Text(
                    'Permissions',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                      letterSpacing: 0.5,
                    ),
                  ),
      ),
      backgroundColor: AppColors.primaryBlack,
      body: SafeArea(
        child: Column(
          children: [
     
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
           
                    
                    const Text(
                      'Please allow the following permissions to continue using the app.',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.primaryWhite,
                        height: 1.4,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Permission cards
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _permissionController,
                        builder: (context, child) {
                          final permissionInfo = _permissionController.getPermissionInfo();
                          final permissions = _permissionController.permissionStatus;
                          
                          return ListView.builder(
                            itemCount: permissionInfo.length,
                            itemBuilder: (context, index) {
                              final permission = permissionInfo.keys.elementAt(index);
                              final info = permissionInfo[permission]!;
                              final isGranted = permissions[permission] ?? false;
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: buildPermissionCard(
                                  title: info['title']!,
                                  description: info['description']!,
                                  iconName: info['icon']!,
                                  isGranted: isGranted,
                                  onTap: () async {
                                    await _permissionController.requestPermission(permission);
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Continue button
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: AnimatedBuilder(
                animation: _permissionController,
                builder: (context, child) {
                  return Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGreen.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _permissionController.isLoading
                          ? null
                          : () {
                              if (_permissionController.areAllPermissionsGranted) {
                                context.go(AppRoutes.login);
                              } else {
                                _permissionController.requestAllPermissions();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: AppColors.primaryBlack,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _permissionController.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primaryBlack,
                                ),
                              ),
                            )
                          : const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}