import 'dart:async';

import 'package:flutter/services.dart';

import 'overlay_status.dart';

class OverlayController {
  static const MethodChannel _channel = MethodChannel('overlay_control');
  static const EventChannel _eventChannel = EventChannel('overlay_events');

  OverlayStatus _status = const OverlayStatus(
    hasPermission: false,
    serviceRunning: false,
  );

  OverlayStatus get status => _status;

  Stream<String> get events {
    return _eventChannel
        .receiveBroadcastStream()
        .map((event) => event?.toString() ?? '');
  }

  Future<bool> checkPermission() async {
    final result = await _channel.invokeMethod<bool>('checkOverlayPermission');
    final hasPermission = result ?? false;
    _status = _status.copyWith(hasPermission: hasPermission);
    return hasPermission;
  }

  Future<void> requestPermission() async {
    await _channel.invokeMethod<void>('requestOverlayPermission');
  }

  Future<bool> startOverlayService() async {
    final result = await _channel.invokeMethod<bool>('startOverlayService');
    final started = result ?? false;
    _status = _status.copyWith(serviceRunning: started);
    return started;
  }

  Future<bool> stopOverlayService() async {
    final result = await _channel.invokeMethod<bool>('stopOverlayService');
    final stopped = result ?? false;
    _status = _status.copyWith(serviceRunning: stopped ? false : _status.serviceRunning);
    return stopped;
  }

  Future<void> openAppFromOverlay() async {
    await _channel.invokeMethod<void>('openAppFromOverlay');
  }

  void updateServiceRunning(bool running) {
    _status = _status.copyWith(serviceRunning: running);
  }
}
