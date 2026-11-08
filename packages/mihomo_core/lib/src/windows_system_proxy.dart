import 'dart:io';

/// Sets/clears the per-user WinINet proxy (what "Settings > Proxy" edits).
class WindowsSystemProxy {
  static const _key =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';

  static Future<bool> isEnabled() async {
    if (!Platform.isWindows) return false;
    final r = await Process.run('reg', ['query', _key, '/v', 'ProxyEnable']);
    return r.exitCode == 0 && r.stdout.toString().contains('0x1');
  }

  static Future<void> enable(
    String host,
    int port, {
    List<String> bypass = const [
      'localhost', '127.*', '10.*', '172.16.*', '172.17.*', '172.18.*',
      '172.19.*', '172.2*', '172.30.*', '172.31.*', '192.168.*', '<local>',
    ],
  }) async {
    if (!Platform.isWindows) return;
    await _reg('ProxyServer', 'REG_SZ', '$host:$port');
    await _reg('ProxyOverride', 'REG_SZ', bypass.join(';'));
    await _reg('ProxyEnable', 'REG_DWORD', '1');
    await _notify();
  }

  static Future<void> disable() async {
    if (!Platform.isWindows) return;
    await _reg('ProxyEnable', 'REG_DWORD', '0');
    await _notify();
  }

  static Future<void> _reg(String name, String type, String data) async {
    final r = await Process.run('reg', ['add', _key, '/v', name, '/t', type, '/d', data, '/f']);
    if (r.exitCode != 0) {
      throw ProcessException('reg', ['add', name], '${r.stderr}', r.exitCode);
    }
  }

  /// Tell WinINet clients (browsers etc.) the settings changed.
  static Future<void> _notify() async {
    const script = r'''
$sig='[DllImport("wininet.dll")] public static extern bool InternetSetOption(IntPtr h,int o,IntPtr b,int l);'
$t=Add-Type -MemberDefinition $sig -Name W -Namespace N -PassThru
$t::InternetSetOption([IntPtr]::Zero,39,[IntPtr]::Zero,0) | Out-Null
$t::InternetSetOption([IntPtr]::Zero,37,[IntPtr]::Zero,0) | Out-Null
''';
    await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-Command', script]);
  }
}
