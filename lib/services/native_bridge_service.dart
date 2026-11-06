import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart wrapper communicating with Android & iOS native notification channels.
class NativeBridgeService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.openqris.bridge/listener');
  static const EventChannel _eventChannel =
      EventChannel('com.openqris.bridge/notifications');

  Stream<Map<String, dynamic>>? _notificationStream;

  /// Whether the current platform supports Android NotificationListenerService
  bool get isAndroidSupported => !kIsWeb && Platform.isAndroid;

  /// Checks if Notification Listener permission is enabled on Android
  Future<bool> isNotificationPermissionGranted() async {
    if (!isAndroidSupported) return false;
    try {
      final bool? granted =
          await _methodChannel.invokeMethod<bool>('isPermissionGranted');
      return granted ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking notification permission: ${e.message}');
      return false;
    }
  }

  /// Opens Android Settings screen to grant Notification Access
  Future<void> openPermissionSettings() async {
    if (!isAndroidSupported) return;
    try {
      await _methodChannel.invokeMethod('openPermissionSettings');
    } on PlatformException catch (e) {
      debugPrint('Error opening permission settings: ${e.message}');
    }
  }

  /// Starts the Android Foreground Service for persistent background listening
  Future<bool> startForegroundService() async {
    if (!isAndroidSupported) return false;
    try {
      final res =
          await _methodChannel.invokeMethod<bool>('startForegroundService');
      return res ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error starting foreground service: ${e.message}');
      return false;
    }
  }

  /// Stops the Android Foreground Service
  Future<bool> stopForegroundService() async {
    if (!isAndroidSupported) return false;
    try {
      final res =
          await _methodChannel.invokeMethod<bool>('stopForegroundService');
      return res ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error stopping foreground service: ${e.message}');
      return false;
    }
  }

  /// Stream of raw incoming notifications intercepted by Android NotificationListenerService
  Stream<Map<String, dynamic>> get notificationStream {
    if (!isAndroidSupported) {
      return const Stream.empty();
    }

    _notificationStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));

    return _notificationStream!;
  }
}
