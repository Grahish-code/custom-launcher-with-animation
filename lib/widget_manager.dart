// working_widget_manager.dart
// This implementation works WITHOUT BIND_APPWIDGET permission
import 'dart:typed_data';
import 'package:flutter/services.dart';

class WorkingWidgetManager {
  static const MethodChannel _channel = MethodChannel('com.example.virtual_pet/working_widgets');

  // Widget host ID - should be unique for your app
  static const int HOST_ID = 12345;

  /// Initialize the widget host
  static Future<bool> initializeWidgetHost() async {
    try {
      return await _channel.invokeMethod('initializeWidgetHost', {
        'hostId': HOST_ID,
      });
    } catch (e) {
      print('❌ Error initializing widget host: $e');
      return false;
    }
  }

  /// Start listening for widgets - this creates the host
  static Future<bool> startListening() async {
    try {
      return await _channel.invokeMethod('startListening');
    } catch (e) {
      print('❌ Error starting widget listening: $e');
      return false;
    }
  }

  /// Stop listening for widgets
  static Future<bool> stopListening() async {
    try {
      return await _channel.invokeMethod('stopListening');
    } catch (e) {
      print('❌ Error stopping widget listening: $e');
      return false;
    }
  }

  /// Add widget using system picker (this is the working approach)
  static Future<AddWidgetResult> addWidgetFromPicker() async {
    try {
      print('🎯 Requesting widget addition via system picker...');

      final result = await _channel.invokeMethod('addWidgetFromPicker', {
        'hostId': HOST_ID,
      });

      return AddWidgetResult.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      print('❌ Error adding widget from picker: $e');
      return AddWidgetResult(
        success: false,
        message: 'Error: $e',
      );
    }
  }

  /// Get all active widgets
  static Future<List<ActiveWidget>> getActiveWidgets() async {
    try {
      final result = await _channel.invokeMethod('getActiveWidgets');
      if (result == null) return [];

      final widgets = List<Map<String, dynamic>>.from(result);
      return widgets.map((w) => ActiveWidget.fromMap(w)).toList();
    } catch (e) {
      print('❌ Error getting active widgets: $e');
      return [];
    }
  }

  /// Capture widget as bitmap
  static Future<WidgetBitmap?> captureWidget(int appWidgetId) async {
    try {
      final result = await _channel.invokeMethod('captureWidget', {
        'appWidgetId': appWidgetId,
        'width': 320,
        'height': 180,
      });

      if (result == null) return null;
      return WidgetBitmap.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      print('❌ Error capturing widget $appWidgetId: $e');
      return null;
    }
  }

  /// Remove widget
  static Future<bool> removeWidget(int appWidgetId) async {
    try {
      return await _channel.invokeMethod('removeWidget', {
        'appWidgetId': appWidgetId,
      });
    } catch (e) {
      print('❌ Error removing widget $appWidgetId: $e');
      return false;
    }
  }

  /// Check if widget binding is available (will always be false for regular apps)
  static Future<bool> canBindWidgets() async {
    try {
      return await _channel.invokeMethod('canBindWidgets');
    } catch (e) {
      print('❌ Error checking bind widgets: $e');
      return false;
    }
  }
}

// ==================== MODELS ====================

class AddWidgetResult {
  final bool success;
  final String message;
  final int? appWidgetId;
  final String? widgetLabel;
  final String? packageName;

  AddWidgetResult({
    required this.success,
    required this.message,
    this.appWidgetId,
    this.widgetLabel,
    this.packageName,
  });

  factory AddWidgetResult.fromMap(Map<String, dynamic> map) {
    return AddWidgetResult(
      success: map['success'] ?? false,
      message: map['message'] ?? '',
      appWidgetId: map['appWidgetId'],
      widgetLabel: map['widgetLabel'],
      packageName: map['packageName'],
    );
  }
}

class ActiveWidget {
  final int appWidgetId;
  final String label;
  final String packageName;
  final String className;
  final int minWidth;
  final int minHeight;
  final bool isConfigured;

  ActiveWidget({
    required this.appWidgetId,
    required this.label,
    required this.packageName,
    required this.className,
    required this.minWidth,
    required this.minHeight,
    required this.isConfigured,
  });

  factory ActiveWidget.fromMap(Map<String, dynamic> map) {
    return ActiveWidget(
      appWidgetId: map['appWidgetId'] ?? -1,
      label: map['label'] ?? 'Unknown Widget',
      packageName: map['packageName'] ?? '',
      className: map['className'] ?? '',
      minWidth: map['minWidth'] ?? 0,
      minHeight: map['minHeight'] ?? 0,
      isConfigured: map['isConfigured'] ?? false,
    );
  }
}

class WidgetBitmap {
  final int appWidgetId;
  final Uint8List imageBytes;
  final int width;
  final int height;
  final bool isValid;

  WidgetBitmap({
    required this.appWidgetId,
    required this.imageBytes,
    required this.width,
    required this.height,
    required this.isValid,
  });

  factory WidgetBitmap.fromMap(Map<String, dynamic> map) {
    final imageData = map['imageBytes'];
    final bytes = imageData != null
        ? Uint8List.fromList(List<int>.from(imageData))
        : Uint8List(0);

    return WidgetBitmap(
      appWidgetId: map['appWidgetId'] ?? -1,
      imageBytes: bytes,
      width: map['width'] ?? 0,
      height: map['height'] ?? 0,
      isValid: map['isValid'] ?? false,
    );
  }
}