import 'package:flutter/widgets.dart';
import 'package:shorebird_console/data/api_client.dart';
import 'package:shorebird_console/data/auth_storage.dart';

/// InheritedWidget providing global dependencies to the widget tree.
class AppDependencies extends InheritedWidget {
  const AppDependencies({
    required this.apiClient,
    required this.authStorage,
    required super.child,
    super.key,
  });

  final ApiClient apiClient;
  final IAuthStorage authStorage;

  static AppDependencies of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppDependencies>()!;
  }

  @override
  bool updateShouldNotify(AppDependencies oldWidget) =>
      apiClient != oldWidget.apiClient || authStorage != oldWidget.authStorage;
}
