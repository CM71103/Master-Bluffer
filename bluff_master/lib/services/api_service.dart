import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

/// Talks to the Node server's REST API, which reads and writes MongoDB.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const _timeout = Duration(seconds: 8);

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    final res = await http.get(Uri.parse('$serverUrl$path')).timeout(_timeout);
    if (res.statusCode != 200) throw Exception('Server error ${res.statusCode}');
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> leaderboard() => _getList('/api/leaderboard');

  Future<List<Map<String, dynamic>>> recentGames() => _getList('/api/recent');

  Future<List<Map<String, dynamic>>> myHistory(String uid) =>
      _getList('/api/history/${Uri.encodeComponent(uid)}');

  Future<void> deleteGame(String gameId, String uid) async {
    final res = await http
        .delete(Uri.parse(
            '$serverUrl/api/history/$gameId/${Uri.encodeComponent(uid)}'))
        .timeout(_timeout);
    if (res.statusCode != 200) throw Exception('Server error ${res.statusCode}');
  }
}
