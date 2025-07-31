// widget_manager.dart
// Manages Android widgets integration with Flutter

import 'dart:typed_data';
import 'package:flutter/services.dart';

class WidgetManager {
  static const MethodChannel _channel = MethodChannel('com.example.virtual_pet/widgets');

  /// Called when a widget is added (via picker or bind/configure flow)
  static Function(Map<String, dynamic>)? onWidgetAdded;

  /// Called when user denies widget bind permission
  static Function()? onWidgetPermissionDenied;

  /// Initialize method channel callbacks
  static void initialize() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onWidgetAdded':
        if (onWidgetAdded != null) {
          onWidgetAdded!(Map<String, dynamic>.from(call.arguments));
        }
        break;
      case 'onWidgetPermissionDenied':
        if (onWidgetPermissionDenied != null) {
          onWidgetPermissionDenied!();
        }
        break;
    }
  }

  /// Get list of all available widgets on the device
  static Future<List<AndroidWidget>> getAvailableWidgets() async {
    try {
      final List<dynamic> widgets = await _channel.invokeMethod('getAvailableWidgets');
      return widgets.map((w) => AndroidWidget.fromMap(Map<String, dynamic>.from(w))).toList();
    } catch (e) {
      print('Error getting available widgets: $e');
      return [];
    }
  }

  /// Pick a widget and return its ID + provider info
  static Future<PickedWidget?> pickWidget() async {
    try {
      final Map<String, dynamic> result = Map<String, dynamic>.from(await _channel.invokeMethod('pickWidget'));
      return PickedWidget(
        widgetId: result['widgetId'] ?? -1,
        packageName: result['packageName'] ?? '',
        className: result['className'] ?? '',
      );
    } catch (e) {
      print('Error picking widget: $e');
      return null;
    }
  }

  /// Add a widget manually
  static Future<WidgetAddResult?> addWidget({
    required String packageName,
    required String className,
    int width = 300,
    int height = 200,
  }) async {
    try {
      final result = await _channel.invokeMethod('addWidget', {
        'packageName': packageName,
        'className': className,
        'width': width,
        'height': height,
      });

      final map = Map<String, dynamic>.from(result);

      return WidgetAddResult.fromMap(map);
    } catch (e) {
      print('Error adding widget: $e');
      return null;
    }
  }

  static Future<bool> removeWidget(int widgetId) async {
    try {
      return await _channel.invokeMethod('removeWidget', {'widgetId': widgetId});
    } catch (e) {
      print('Error removing widget: $e');
      return false;
    }
  }

  static Future<WidgetSnapshot?> getWidgetSnapshot(int widgetId) async {
    try {
      final Map<String, dynamic> result = await _channel.invokeMethod('getWidgetView', {
        'widgetId': widgetId,
      });
      return WidgetSnapshot.fromMap(result);
    } catch (e) {
      print('Error getting widget snapshot: $e');
      return null;
    }
  }

  static Future<bool> resizeWidget(int widgetId, int width, int height) async {
    try {
      return await _channel.invokeMethod('resizeWidget', {
        'widgetId': widgetId,
        'width': width,
        'height': height,
      });
    } catch (e) {
      print('Error resizing widget: $e');
      return false;
    }
  }

  static Future<List<InstalledWidget>> getInstalledWidgets() async {
    try {
      final List<dynamic> widgets = await _channel.invokeMethod('getInstalledWidgets');
      return widgets.map((w) => InstalledWidget.fromMap(Map<String, dynamic>.from(w))).toList();
    } catch (e) {
      print('Error getting installed widgets: $e');
      return [];
    }
  }
}

// ==================== MODELS ====================

class AndroidWidget {
  final String packageName;
  final String className;
  final String label;
  final int minWidth;
  final int minHeight;
  final int minResizeWidth;
  final int minResizeHeight;
  final int resizeMode;
  final int widgetCategory;
  final Uint8List? previewImage;

  AndroidWidget({
    required this.packageName,
    required this.className,
    required this.label,
    required this.minWidth,
    required this.minHeight,
    required this.minResizeWidth,
    required this.minResizeHeight,
    required this.resizeMode,
    required this.widgetCategory,
    this.previewImage,
  });

  factory AndroidWidget.fromMap(Map<String, dynamic> map) {
    return AndroidWidget(
      packageName: map['packageName'] ?? '',
      className: map['className'] ?? '',
      label: map['label'] ?? '',
      minWidth: map['minWidth'] ?? 0,
      minHeight: map['minHeight'] ?? 0,
      minResizeWidth: map['minResizeWidth'] ?? 0,
      minResizeHeight: map['minResizeHeight'] ?? 0,
      resizeMode: map['resizeMode'] ?? 0,
      widgetCategory: map['widgetCategory'] ?? 0,
      previewImage: map['previewImage'] != null
          ? Uint8List.fromList(List<int>.from(map['previewImage']))
          : null,
    );
  }
}

class PickedWidget {
  final int widgetId;
  final String packageName;
  final String className;

  PickedWidget({
    required this.widgetId,
    required this.packageName,
    required this.className,
  });
}

class WidgetAddResult {
  final int widgetId;
  final bool success;
  final bool needsPermission;
  final int width;
  final int height;

  WidgetAddResult({
    required this.widgetId,
    required this.success,
    this.needsPermission = false,
    required this.width,
    required this.height,
  });

  factory WidgetAddResult.fromMap(Map<String, dynamic> map) {
    return WidgetAddResult(
      widgetId: map['widgetId'] ?? -1,
      success: map['success'] ?? false,
      needsPermission: map['needsPermission'] ?? false,
      width: map['width'] ?? 0,
      height: map['height'] ?? 0,
    );
  }
}

class WidgetSnapshot {
  final int widgetId;
  final Uint8List imageBytes;
  final int width;
  final int height;

  WidgetSnapshot({
    required this.widgetId,
    required this.imageBytes,
    required this.width,
    required this.height,
  });

  factory WidgetSnapshot.fromMap(Map<String, dynamic> map) {
    return WidgetSnapshot(
      widgetId: map['widgetId'] ?? -1,
      imageBytes: Uint8List.fromList(List<int>.from(map['imageBytes'])),
      width: map['width'] ?? 0,
      height: map['height'] ?? 0,
    );
  }
}

class InstalledWidget {
  final int widgetId;
  final String? packageName;
  final String? className;
  final String? label;
  final int width;
  final int height;

  InstalledWidget({
    required this.widgetId,
    this.packageName,
    this.className,
    this.label,
    required this.width,
    required this.height,
  });

  factory InstalledWidget.fromMap(Map<String, dynamic> map) {
    return InstalledWidget(
      widgetId: map['widgetId'] ?? -1,
      packageName: map['packageName'],
      className: map['className'],
      label: map['label'],
      width: map['width'] ?? 0,
      height: map['height'] ?? 0,
    );
  }
}
