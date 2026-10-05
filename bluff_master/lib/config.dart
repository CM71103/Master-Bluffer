import 'package:flutter/foundation.dart';

/// Server address. Override at run time, e.g.
///   flutter run --dart-define=SERVER_URL=http://192.168.1.5:3000
const String _override = String.fromEnvironment('SERVER_URL');

String get serverUrl {
  if (_override.isNotEmpty) return _override;
  if (kIsWeb) return 'http://localhost:3000';
  // Android emulator reaches the host machine through 10.0.2.2
  return 'http://10.0.2.2:3000';
}
