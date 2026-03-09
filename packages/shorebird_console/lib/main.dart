import 'package:flutter/material.dart';
import 'package:shorebird_console/app.dart';

void main() {
  const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
  runApp(const App(apiBaseUrl: apiBaseUrl));
}
