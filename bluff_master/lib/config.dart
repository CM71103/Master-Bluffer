/// Server address. Override at run time, e.g.
///   flutter run --dart-define=SERVER_URL=http://192.168.1.5:3000
const String _override = String.fromEnvironment('SERVER_URL');

String get serverUrl {
  if (_override.isNotEmpty) return _override.replaceFirst(RegExp(r'/$'), '');
  return 'https://master-bluffer-1.onrender.com';
}
