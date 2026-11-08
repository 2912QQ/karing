import 'package:mihomo_core/mihomo_core.dart';
import 'package:test/test.dart';

void main() {
  test('build() sets app-owned keys and default groups/rules', () {
    final cfg = ClashConfigBuilder.build(
      proxies: [
        {'name': 'a', 'type': 'ss', 'server': '1.1.1.1', 'port': 8388, 'cipher': 'aes-128-gcm', 'password': 'x'},
      ],
      options: ClashConfigOptions(mixedPort: 7899, controllerPort: 9191, secret: 's'),
    );
    expect(cfg['mixed-port'], 7899);
    expect(cfg['external-controller'], '127.0.0.1:9191');
    expect(cfg['secret'], 's');
    expect((cfg['proxy-groups'] as List).length, 2);
    expect((cfg['rules'] as List).last, 'MATCH,PROXY');
    expect(cfg.containsKey('tun'), isFalse);
  });

  test('overlay keeps subscription content and forces app-owned keys', () {
    const sub = '''
mixed-port: 1
external-controller: 0.0.0.0:1234
proxies:
  - {name: n1, type: vless, server: s.example.com, port: 443, uuid: u}
proxy-groups:
  - {name: PROXY, type: select, proxies: [n1]}
rule-providers:
  ads: {type: http, behavior: domain, url: "https://e.com/a.yaml", path: ./ads.yaml, interval: 86400}
rules:
  - RULE-SET,ads,REJECT
  - MATCH,PROXY
''';
    final cfg = ClashConfigBuilder.overlayOnSubscription(
      sub,
      ClashConfigOptions(mixedPort: 7890, tun: true),
    );
    expect(cfg['mixed-port'], 7890);
    expect(cfg['external-controller'], '127.0.0.1:9090');
    expect(cfg['rule-providers'], isA<Map>());
    expect((cfg['rules'] as List).first, 'RULE-SET,ads,REJECT');
    expect((cfg['tun'] as Map)['enable'], true);
    expect(cfg.containsKey('dns'), isTrue);
  });
}
