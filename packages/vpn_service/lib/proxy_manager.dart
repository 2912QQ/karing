import 'package:mihomo_core/mihomo_core.dart';

/// Thin wrapper over the Windows system proxy helper.
class ProxyManager {
  static Future<bool> isEnabled() => WindowsSystemProxy.isEnabled();
  static Future<void> enable(String host, int port) =>
      WindowsSystemProxy.enable(host, port);
  static Future<void> disable() => WindowsSystemProxy.disable();
}
