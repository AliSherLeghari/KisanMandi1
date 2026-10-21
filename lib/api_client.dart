import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override String toString() => message;
}

class ApiClient {
  static const configuredUrl = String.fromEnvironment('API_BASE_URL');
  final String baseUrl;
  final http.Client client;
  String? token;
  ApiClient({String? baseUrl,http.Client? client})
    : baseUrl = (baseUrl ?? configuredUrl).replaceAll(RegExp(r'/$'), ''), client = client ?? http.Client();

  Future<dynamic> request(String method,String path, [Json? input]) async {
    if (baseUrl.isEmpty) throw const ApiException('No API URL configured. Deploy the mock API and rebuild with --dart-define=API_BASE_URL=https://your-server.example');
    try {
      final request = http.Request(method,Uri.parse('$baseUrl$path'));
      request.headers['Accept'] = 'application/json';
      if (token != null) request.headers['X-Demo-Token'] = token!;
      if (input != null) { request.headers['Content-Type'] = 'application/json'; request.body = jsonEncode(input); }
      final response = await http.Response.fromStream(await client.send(request).timeout(const Duration(seconds: 15)));
      final decoded = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(decoded is Map ? (decoded['error']?.toString() ?? 'HTTP ${response.statusCode}') : 'HTTP ${response.statusCode}');
      }
      return decoded;
    } on ApiException { rethrow; } catch (_) { throw const ApiException('Cannot reach the mock API. Check internet connection and configured API URL.'); }
  }
  Future<List<T>> list<T>(String path,T Function(Json) decoder) async =>
      (await request('GET',path) as List).map((x)=>decoder(Map<String,dynamic>.from(x as Map))).toList();
}
