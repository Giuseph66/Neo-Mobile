import 'overlay_controller.dart';

class OverlayPermissions {
  static Future<bool> hasPermission(OverlayController controller) {
    return controller.checkPermission();
  }

  static Future<void> requestPermission(OverlayController controller) {
    return controller.requestPermission();
  }
}
