import 'dart:io';

export 'state.dart';

class VpnServiceError {
  VpnServiceError(this.message);
  String message;
}

/// STUB. Signatures were reverse-engineered from Karing's call sites.
/// Bodies are placeholders so the project can compile; real behaviour
/// (TUN service, firewall, privileges) is still to be implemented on top of mihomo_core.
class FlutterVpnService {
  static Future<String> getSystemVersion() async => Platform.operatingSystemVersion;

  static Future<void> firewallAddPorts(List<int> ports, String exeName) async {}

  static Future<void> hideDockIcon(bool hide) async {}

  static Future<void> setExcludeFromRecents(bool exclude) async {}

  static Future<bool> isServiceAuthorized(String servicePath) async => true;

  static Future<VpnServiceError?> authorizeService(String servicePath, String password) async => null;

  static Future<Directory?> getAppGroupDirectory(String groupId) async => Directory.systemTemp;

  /// Snapshot of mihomo /connections as a JSON string. TODO: wire to MihomoCore.api.
  static Future<String> clashiApiConnections(bool closeAll) async => '{}';
}
