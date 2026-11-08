import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

class ClashConfigOptions {
  ClashConfigOptions({
    this.mixedPort = 7890,
    this.allowLan = false,
    this.logLevel = 'info',
    this.controllerHost = '127.0.0.1',
    this.controllerPort = 9090,
    this.secret = '',
    this.mode = 'rule',
    this.ipv6 = false,
    this.tun = false,
    this.tunStack = 'mixed',
    this.fakeIp = true,
    this.nameservers = const ['https://dns.alidns.com/dns-query', 'https://doh.pub/dns-query'],
    this.fallbackDns = const ['https://1.1.1.1/dns-query', 'https://dns.google/dns-query'],
  });

  int mixedPort;
  bool allowLan;
  String logLevel;
  String controllerHost;
  int controllerPort;
  String secret;
  String mode; // rule | global | direct
  bool ipv6;
  bool tun;
  String tunStack; // system | gvisor | mixed
  bool fakeIp;
  List<String> nameservers;
  List<String> fallbackDns;
}

class ClashConfigBuilder {
  /// Settings the app owns. They always override whatever a subscription says,
  /// so the controller port/secret and the proxy port stay predictable.
  static Map<String, dynamic> appOwned(ClashConfigOptions o) => {
        'mixed-port': o.mixedPort,
        'allow-lan': o.allowLan,
        'log-level': o.logLevel,
        'mode': o.mode,
        'ipv6': o.ipv6,
        'external-controller': '${o.controllerHost}:${o.controllerPort}',
        'secret': o.secret,
      };

  static Map<String, dynamic> _dns(ClashConfigOptions o) => {
        'enable': true,
        'ipv6': o.ipv6,
        'enhanced-mode': o.fakeIp ? 'fake-ip' : 'normal',
        if (o.fakeIp) 'fake-ip-range': '198.18.0.1/16',
        if (o.fakeIp)
          'fake-ip-filter': ['*.lan', '*.local', 'localhost.ptlogin2.qq.com', '+.msftconnecttest.com'],
        'default-nameserver': ['223.5.5.5', '119.29.29.29'],
        'nameserver': o.nameservers,
        'fallback': o.fallbackDns,
        'fallback-filter': {'geoip': true, 'geoip-code': 'CN'},
      };

  static Map<String, dynamic> _tun(ClashConfigOptions o) => {
        'enable': true,
        'stack': o.tunStack,
        'auto-route': true,
        'auto-detect-interface': true,
        'dns-hijack': ['any:53', 'tcp://any:53'],
        'strict-route': true,
      };

  /// Build a complete config from Clash-format proxy maps
  /// (e.g. {name, type: vless, server, port, ...}).
  static Map<String, dynamic> build({
    required List<Map<String, dynamic>> proxies,
    List<Map<String, dynamic>>? groups,
    List<String>? rules,
    ClashConfigOptions? options,
  }) {
    final o = options ?? ClashConfigOptions();
    final names = proxies.map((p) => p['name'].toString()).toList();
    final cfg = <String, dynamic>{
      ...appOwned(o),
      'unified-delay': true,
      'tcp-concurrent': true,
      'dns': _dns(o),
      if (o.tun) 'tun': _tun(o),
      'proxies': proxies,
      'proxy-groups': groups ??
          [
            {
              'name': 'AUTO',
              'type': 'url-test',
              'proxies': names,
              'url': 'https://www.gstatic.com/generate_204',
              'interval': 300,
              'tolerance': 50,
            },
            {
              'name': 'PROXY',
              'type': 'select',
              'proxies': ['AUTO', ...names, 'DIRECT'],
            },
          ],
      'rules': rules ??
          [
            'GEOIP,LAN,DIRECT,no-resolve',
            'GEOSITE,CN,DIRECT',
            'GEOIP,CN,DIRECT',
            'MATCH,PROXY',
          ],
    };
    return cfg;
  }

  /// Use a Clash/Clash.Meta subscription as-is and only overlay app-owned keys.
  /// This is how real mihomo features (new protocols, rule-providers,
  /// proxy-providers, script rules) survive untouched.
  static Map<String, dynamic> overlayOnSubscription(
    String subscriptionYaml,
    ClashConfigOptions options,
  ) {
    final parsed = loadYaml(subscriptionYaml);
    if (parsed is! YamlMap) {
      throw const FormatException('subscription is not a YAML mapping');
    }
    final cfg = Map<String, dynamic>.from(_toPlain(parsed) as Map);
    cfg.addAll(appOwned(options));
    if (options.tun) {
      final existing = cfg['tun'] is Map ? Map<String, dynamic>.from(cfg['tun'] as Map) : {};
      cfg['tun'] = {...existing, ..._tun(options)};
    }
    // Keep the subscription's dns if it has one; otherwise provide a sane default.
    cfg.putIfAbsent('dns', () => _dns(options));
    cfg.putIfAbsent('proxy-groups', () => <dynamic>[]);
    return cfg;
  }

  static dynamic _toPlain(dynamic v) {
    if (v is YamlMap) {
      return {for (final e in v.entries) e.key.toString(): _toPlain(e.value)};
    }
    if (v is YamlList) return [for (final e in v) _toPlain(e)];
    return v;
  }

  /// JSON is valid YAML, and mihomo parses config as YAML, so we write JSON.
  /// Written to a temp file then renamed so a crash never leaves a half file.
  static Future<File> write(Map<String, dynamic> cfg, String path) async {
    final tmp = File('$path.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(cfg));
    return tmp.rename(path);
  }
}
