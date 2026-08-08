import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api',
  );

  String? accessToken;
  String? refreshToken;

  Uri _uri(String path, [Map<String, String?>? query]) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('$baseUrl/$normalized');
    if (query == null) return uri;
    final clean = <String, String>{};
    query.forEach((key, value) {
      if (value != null && value.trim().isNotEmpty) clean[key] = value;
    });
    return uri.replace(queryParameters: clean.isEmpty ? null : clean);
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString('pcc_access');
    refreshToken = prefs.getString('pcc_refresh');
  }

  Future<void> saveTokens(String access, String refresh) async {
    accessToken = access;
    refreshToken = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pcc_access', access);
    await prefs.setString('pcc_refresh', refresh);
  }

  Future<void> clearTokens() async {
    accessToken = null;
    refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pcc_access');
    await prefs.remove('pcc_refresh');
  }

  dynamic _decode(http.Response response) {
    dynamic body;
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = response.body;
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    String message = 'Request failed (${response.statusCode}).';
    if (body is Map) {
      final detail =
          body['detail'] ?? body['message'] ?? body['non_field_errors'];
      if (detail is List && detail.isNotEmpty) {
        message = detail.first.toString();
      } else if (detail != null) {
        message = detail.toString();
      } else if (body.isNotEmpty) {
        final first = body.values.first;
        message = first is List && first.isNotEmpty
            ? first.first.toString()
            : first.toString();
      }
    } else if (body is String && body.isNotEmpty) {
      message = body;
    }
    throw ApiException(message, response.statusCode);
  }

  Future<bool> _refresh() async {
    if (refreshToken == null) return false;
    final response = await http.post(
      _uri('auth/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refreshToken}),
    );
    if (response.statusCode != 200) return false;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    await saveTokens(data['access'].toString(),
        data['refresh']?.toString() ?? refreshToken!);
    return true;
  }

  Future<http.Response> _withRefresh(
      Future<http.Response> Function() request) async {
    var response = await request();
    if (response.statusCode == 401 && await _refresh())
      response = await request();
    return response;
  }

  Future<dynamic> get(String path, {Map<String, String?>? query}) async {
    final response = await _withRefresh(
        () => http.get(_uri(path, query), headers: _headers));
    return _decode(response);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final response = await _withRefresh(() =>
        http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));
    return _decode(response);
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    final response = await _withRefresh(() => http.patch(_uri(path),
        headers: _headers, body: jsonEncode(body ?? {})));
    return _decode(response);
  }

  Future<dynamic> put(String path, {Object? body}) async {
    final response = await _withRefresh(() =>
        http.put(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));
    return _decode(response);
  }

  Future<void> delete(String path) async {
    final response =
        await _withRefresh(() => http.delete(_uri(path), headers: _headers));
    _decode(response);
  }

  Future<dynamic> multipart(
    String path, {
    required String method,
    required Map<String, String> fields,
    Uint8List? fileBytes,
    String? filename,
    String fileField = 'photo',
  }) async {
    Future<http.StreamedResponse> send() async {
      final request = http.MultipartRequest(method, _uri(path));
      request.headers['Accept'] = 'application/json';
      if (accessToken != null)
        request.headers['Authorization'] = 'Bearer $accessToken';
      request.fields.addAll(fields);
      if (fileBytes != null) {
        request.files.add(http.MultipartFile.fromBytes(fileField, fileBytes,
            filename: filename ?? 'upload.jpg'));
      }
      return request.send();
    }

    var streamed = await send();
    if (streamed.statusCode == 401 && await _refresh()) streamed = await send();
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Future<Uint8List> download(String path, {Map<String, String?>? query}) async {
    final response =
        await _withRefresh(() => http.get(_uri(path, query), headers: {
              'Accept': '*/*',
              if (accessToken != null) 'Authorization': 'Bearer $accessToken',
            }));
    if (response.statusCode < 200 || response.statusCode >= 300)
      _decode(response);
    return response.bodyBytes;
  }

  List<dynamic> unwrapList(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['results'] is List) return data['results'] as List;
    return const [];
  }
}
