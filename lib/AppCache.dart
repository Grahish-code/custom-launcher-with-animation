import 'app_drawer.dart';

class AppCache {
  static final AppCache _instance = AppCache._internal();
  factory AppCache() => _instance;
  AppCache._internal();

  List<AppInfo>? apps;

  bool get hasCache => apps != null && apps!.isNotEmpty;
}
