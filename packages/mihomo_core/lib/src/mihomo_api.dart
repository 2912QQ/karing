import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'state.dart';

/// Client for mihomo's external-controller REST API.
class MihomoApi {
  MihomoApi({required this.host, required this.port, this.secret = ''});

  final String host;
  final int port;
  final String secret;

  final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 3);

  Uri _uri(List<String> segments, [Map<String, String>? query]) => Uri(
        scheme: 'http',
        host: host,
        port: port,
        pathSegments: segments,
        queryParameters: query,
      );

  Future<dynamic> _request(
    String method,
    Uri uri, {
    Object? body,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final req = await _http.openUrl(method, uri);
    if (secret.isNotEmpty) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $secret');
    }
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(body)));
    }
    final resp = await req.close().timeout(timeout);
    final text = await resp.transform(utf8.decoder).join().timeout(timeout);
    if (resp.statusCode >= 400) {
      throw HttpException(
        'mihomo api ${resp.statusCode}: ${text.isEmpty ? uri.path : text}',
        uri: uri,
      );
    }
    if (text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } catch (_) {
      return text;
    }
  }

  Future<String> version() async {
    final r = await _request('GET', _uri(['version']));
    return (r as Map)['version']?.toString() ?? '';
  }

  /// Polls /version until the core answers or [timeout] passes.
  Future<bool> waitReady(Duration timeout) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      try {
        await version();
        return true;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    return false;
  }

  Future<Map<String, dynamic>> proxies() async {
    final r = await _request('GET', _uri(['proxies']));
    return Map<String, dynamic>.from((r as Map)['proxies'] as Map);
  }

  Future<void> selectProxy(String group, String name) async {
    await _request('PUT', _uri(['proxies', group]), body: {'name': name});
  }

  /// Latency in ms of a single proxy. Throws on timeout/failure.
  Future<int> proxyDelay(
    String name, {
    String url = 'https://www.gstatic.com/generate_204',
    int timeoutMs = 5000,
  }) async {
    final r = await _request(
      'GET',
      _uri(['proxies', name, 'delay'], {'url': url, 'timeout': '$timeoutMs'}),
      timeout: Duration(milliseconds: timeoutMs + 3000),
    );
    return ((r as Map)['delay'] as num).toInt();
  }

  /// Latency of every member of a group: name -> ms (0 on failure).
  Future<Map<String, int>> groupDelay(
    String group, {
    String url = 'https://www.gstatic.com/generate_204',
    int timeoutMs = 5000,
  }) async {
    final r = await _request(
      'GET',
      _uri(['group', group, 'delay'], {'url': url, 'timeout': '$timeoutMs'}),
      timeout: Duration(milliseconds: timeoutMs + 5000),
    );
    return (r as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
  }

  Future<Map<String, dynamic>> connections() async {
    final r = await _request('GET', _uri(['connections']));
    return Map<String, dynamic>.from(r as Map);
  }

  Future<void> closeAllConnections() async {
    await _request('DELETE', _uri(['connections']));
  }

  Future<void> closeConnection(String id) async {
    await _request('DELETE', _uri(['connections', id]));
  }

  /// Hot-reload a config file without restarting the process.
  Future<void> reloadConfig(String absolutePath) async {
    await _request(
      'PUT',
      _uri(['configs'], {'force': 'true'}),
      body: {'path': absolutePath},
    );
  }

  Future<void> patchConfigs(Map<String, dynamic> patch) async {
    await _request('PATCH', _uri(['configs']), body: patch);
  }

  Future<Map<String, dynamic>> getConfigs() async {
    final r = await _request('GET', _uri(['configs']));
    return Map<String, dynamic>.from(r as Map);
  }

  Future<Map<String, dynamic>> dnsQuery(String name, {String type = 'A'}) async {
    final r = await _request('GET', _uri(['dns', 'query'], {'name': name, 'type': type}));
    return Map<String, dynamic>.from(r as Map);
  }

  Future<List<dynamic>> rules() async {
    final r = await _request('GET', _uri(['rules']));
    return List<dynamic>.from((r as Map)['rules'] as List);
  }

  Future<Map<String, dynamic>> ruleProviders() async {
    final r = await _request('GET', _uri(['providers', 'rules']));
    return Map<String, dynamic>.from((r as Map)['providers'] as Map);
  }

  Future<void> updateRuleProvider(String name) async {
    await _request('PUT', _uri(['providers', 'rules', name]));
  }

  Future<void> updateProxyProvider(String name) async {
    await _request('PUT', _uri(['providers', 'proxies', name]));
  }

  /// Live up/down speed, one sample per second.
  Stream<TrafficSample> traffic() async* {
    final ws = await WebSocket.connect(
      'ws://$host:$port/traffic${secret.isEmpty ? '' : '?token=${Uri.encodeQueryComponent(secret)}'}',
    );
    try {
      await for (final msg in ws) {
        final m = jsonDecode(msg as String) as Map;
        yield TrafficSample((m['up'] as num).toInt(), (m['down'] as num).toInt());
      }
    } finally {
      await ws.close();
    }
  }

  /// URLs for UI components that open their own websocket (logs, connections).
  Uri logsUri({String level = 'info'}) => Uri(
        scheme: 'ws',
        host: host,
        port: port,
        path: '/logs',
        queryParameters: {'level': level, if (secret.isNotEmpty) 'token': secret},
      );

  Uri connectionsUri() => Uri(
        scheme: 'ws',
        host: host,
        port: port,
        path: '/connections',
        queryParameters: {if (secret.isNotEmpty) 'token': secret},
      );

  void close() => _http.close(force: true);
}
