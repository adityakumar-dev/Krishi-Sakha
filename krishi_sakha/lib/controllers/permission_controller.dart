import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/permission_service.dart';

class PermissionController extends ChangeNotifier {
  final PermissionService _permissionService = PermissionService();
  
  Map<Permission, bool> _permissionStatus = {};
  bool _isLoading = false;
  
  Map<Permission, bool> get permissionStatus => _permissionStatus;
  bool get isLoading => _isLoading;
  
  // Initialize permission status
  Future<void> initializePermissions() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final permissions = _permissionService.getRequiredPermissions();
      debugPrint("Initializing permissions: $permissions");
      
      for (Permission permission in permissions) {
        final isGranted = await _permissionService.isPermissionGranted(permission);
        _permissionStatus[permission] = isGranted;
        debugPrint("Permission $permission: $isGranted");
      }
    } catch (e) {
      debugPrint("Error initializing permissions: $e");
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  // Request a specific permission
  Future<void> requestPermission(Permission permission) async {
    try {
      debugPrint("Requesting permission: $permission");
      final status = await _permissionService.requestPermission(permission);
      debugPrint("Permission $permission result: ${status.isGranted}");
      _permissionStatus[permission] = status.isGranted;
      notifyListeners();
    } catch (e) {
      debugPrint("Error requesting permission $permission: $e");
    }
  }
  
  // Request all permissions
  Future<void> requestAllPermissions() async {
    _isLoading = true;
    notifyListeners();
    
    final permissions = _permissionService.getRequiredPermissions();
    final results = await _permissionService.requestMultiplePermissions(permissions);
    
    results.forEach((permission, status) {
      _permissionStatus[permission] = status.isGranted;
    });
    
    _isLoading = false;
    notifyListeners();
  }
  
  // Check if all permissions are granted
  bool get areAllPermissionsGranted {
    return _permissionStatus.values.every((granted) => granted);
  }
  
  // Get permission info
  Map<Permission, Map<String, String>> getPermissionInfo() {
    return {
      Permission.camera: {
        'title': 'Camera Access',
        'description': 'Used for scanning images and real-time detection.',
        'icon': 'camera_alt',
      },
      Permission.microphone: {
        'title': 'Microphone Access',
        'description': 'Needed for voice recognition features.',
        'icon': 'mic',
      },
      Permission.manageExternalStorage: {
        'title': 'Storage Access',
        'description': 'Allows reading images or files from your device.',
        'icon': 'storage',
      },
      Permission.location: {
        'title': 'Location Access',
        'description': 'Helps provide location-based support.',
        'icon': 'location_on',
      },
      Permission.notification: {
        'title': 'Notification Access',
        'description': 'To send timely alerts or health updates.',
        'icon': 'notifications',
      },
    };
  }
}