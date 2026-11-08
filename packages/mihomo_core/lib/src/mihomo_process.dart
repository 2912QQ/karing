import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'mihomo_api.dart';
import 'state.dart';

typedef CoreStateListener = FutureOr<void> Function(
    CoreState state, Map<String, String> params);

/// Owns the mihomo process: start, stop, crash detection, hot reload.
class MihomoCore {
  MihomoCore({
    required this.executable,
    required this.homeDir,
    this.configFileName = 'config.json',
    this.controllerHost = '127.0.0.1',
    this.controllerPort = 9090,
    this.secret = '',
  }) : api = MihomoApi(host: controllerHost, port: controllerPort, secret: secret);

  /// Path to mihomo.exe (or mihomo on unix).
  final String executable;

  /// Passed as `-d`; geo files, cache and providers live here.
  final String homeDir;
  final String configFileName;
  final String controllerHost;
  final int controllerPort;
  final String secret;
  final MihomoApi api;

  final List<CoreStateListener> onEventStateChanged = [];

  Process? _process;
  CoreState _state = CoreState.disconnected;
  bool _stopping = false;
  final List<String> _logTail = [];

  CoreState get state => _state;
  String get configPath => '$homeDir${Platform.pathSeparator}$configFileName';
  List<String> get logTail => List.unmodifiable(_logTail);

  void _setState(CoreState s, [Map<String, String> params = const {}]) {
    if (_state == s) return;
    _state = s;
    for (final l in List.of(onEventStateChanged)) {
      l(s, params);
    }
  }

  void _keepLog(String line) {
    _logTail.add(line);
    if (_logTail.length > 200) _logTail.removeRange(0, _logTail.length - 200);
  }

  /// Validate the config with `mihomo -t` before touching the running core.
  Future<CoreError?> testConfig() async {
    if (!File(configPath).existsSync()) {
      return CoreError('config not found: $configPath');
    }
    final r = await Process.run(executable, ['-t', '-d', homeDir, '-f', configPath]);
    if (r.exitCode != 0) {
      return CoreError('config test failed: ${r.stdout}${r.stderr}'.trim());
    }
    return null;
  }

  Future<CoreError?> start({Duration timeout = const Duration(seconds: 15)}) async {
    if (_process != null) return CoreError('already running');
    if (!File(executable).existsSync()) {
      return CoreError('mihomo executable not found: $executable');
    }
    final testErr = await testConfig();
    if (testErr != null) return testErr;

    _setState(CoreState.connecting);
    _stopping = false;
    _logTail.clear();
    try {
      final p = await Process.start(
        executable,
        ['-d', homeDir, '-f', configPath],
        workingDirectory: homeDir,
      );
      _process = p;
      p.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(_keepLog);
      p.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(_keepLog);
      p.exitCode.then(_onExit);
    } catch (e, st) {
      _process = null;
      _setState(CoreState.disconnected);
      return CoreError('failed to start mihomo: $e', stacktrace: st);
    }

    final ready = await api.waitReady(timeout);
    if (!ready) {
      final tail = _logTail.reversed.take(8).toList().reversed.join('\n');
      await stop();
      return CoreError('mihomo did not become ready in ${timeout.inSeconds}s\n$tail');
    }
    _setState(CoreState.connected);
    return null;
  }

  void _onExit(int code) {
    _process = null;
    if (_stopping) return;
    // Unexpected exit: surface it so the UI can show disconnected.
    _keepLog('mihomo exited unexpectedly with code $code');
    _setState(CoreState.disconnected, {'exitCode': '$code'});
  }

  Future<void> stop() async {
    final p = _process;
    if (p == null) {
      _setState(CoreState.disconnected);
      return;
    }
    _stopping = true;
    _setState(CoreState.disconnecting);
    p.kill();
    try {
      await p.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      p.kill(ProcessSignal.sigkill);
    }
    _process = null;
    _setState(CoreState.disconnected);
  }

  /// Hot reload after the config file changed. Falls back to restart.
  Future<CoreError?> reload({Duration timeout = const Duration(seconds: 15)}) async {
    if (_process == null) return start(timeout: timeout);
    final testErr = await testConfig();
    if (testErr != null) return testErr;
    _setState(CoreState.reasserting);
    try {
      await api.reloadConfig(File(configPath).absolute.path);
      await api.closeAllConnections();
      _setState(CoreState.connected);
      return null;
    } catch (e) {
      await stop();
      return start(timeout: timeout);
    }
  }
}
