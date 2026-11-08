# mihomo_core

Pure-Dart controller for the mihomo (Clash.Meta) core. No Flutter dependency.

- `MihomoCore`   start/stop/reload the mihomo process, crash detection, log tail
- `MihomoApi`    REST/WebSocket client: proxies, delay tests, connections, rules, DNS query, traffic
- `ClashConfigBuilder`  build a config, or overlay app-owned keys on a Clash subscription (keeps rule-providers etc.)
- `WindowsSystemProxy`  set/clear the WinINet system proxy

## Quick use
```dart
final core = MihomoCore(executable: r'C:\app\mihomo.exe', homeDir: r'C:\app\data', secret: 'abc');
final cfg = ClashConfigBuilder.overlayOnSubscription(yamlText, ClashConfigOptions(secret: 'abc'));
await ClashConfigBuilder.write(cfg, core.configPath);
final err = await core.start();            // null on success
await core.api.selectProxy('PROXY', 'HK-01');
await WindowsSystemProxy.enable('127.0.0.1', 7890);
```

mihomo.exe is NOT bundled; download the windows-amd64 release from the MetaCubeX/mihomo repo.
Status: written without a Dart SDK available, never compiled or run. Run `dart pub get && dart test` first.
