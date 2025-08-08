import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  // Check if a specific permission is granted
  Future<bool> isPermissionGranted(Permission permission) async {
    final status = await permission.status;
    return status.isGranted;
  }

  // Request a specific permission
  Future<PermissionStatus> requestPermission(Permission permission) async {
    try {
      print('Requesting permission: $permission');
      final status = await permission.request();
      print('Permission $permission status: $status');
      return status;
    } catch (e) {
      print('Error requesting permission $permission: $e');
      return PermissionStatus.denied;
    }
  }

  // Request multiple permissions
  Future<Map<Permission, PermissionStatus>> requestMultiplePermissions(
      List<Permission> permissions) async {
    return await permissions.request();
  }

  // Check if all required permissions are granted
  Future<bool> areAllPermissionsGranted(List<Permission> permissions) async {
    for (Permission permission in permissions) {
      if (!await isPermissionGranted(permission)) {
        return false;
      }
    }
    return true;
  }

  // Get required permissions for the app
  List<Permission> getRequiredPermissions() {
    return [
      Permission.camera,
      Permission.microphone,
      Permission.manageExternalStorage,
      Permission.location,
      Permission.notification,
    ];
  }

  // Open app settings
  Future<bool> openSettings() async {
    return await openAppSettings();
  }
}