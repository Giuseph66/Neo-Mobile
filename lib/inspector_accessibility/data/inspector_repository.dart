import 'dart:async';
import '../domain/models/ui_snapshot.dart';

abstract class InspectorRepository {
  Future<bool> isAccessibilityEnabled();
  Future<void> openAccessibilitySettings();
  Future<void> setInspectorEnabled(bool enabled);
  Future<void> setOverlayVisible(bool visible);
  Future<void> setTextVisible(bool visible);
  Future<void> setAimPosition(int x, int y);
  Future<void> selectNode(String nodeId);
  Future<bool> clickSelected();
  Future<bool> scrollForward();
  Future<bool> scrollBackward();
  Future<void> tap(int x, int y, {int durationMs = 100});
  Future<void> swipe(int x1, int y1, int x2, int y2, {int durationMs = 300});
  Future<bool> navigateHome();
  Future<bool> navigateBack();
  Future<bool> navigateRecents();
  Future<bool> inputText(String text);
  Stream<UiSnapshot> get nodesStream;
}
