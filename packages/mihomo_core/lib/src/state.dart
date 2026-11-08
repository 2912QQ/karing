/// Same state names the Karing UI already switches on (FlutterVpnServiceState).
enum CoreState {
  invalid,
  disconnected,
  connecting,
  connected,
  reasserting,
  disconnecting,
}

class CoreError {
  CoreError(this.message, {this.stacktrace});
  String message;
  StackTrace? stacktrace;
  @override
  String toString() => message;
}

class TrafficSample {
  const TrafficSample(this.up, this.down);
  final int up; // bytes/s
  final int down; // bytes/s
}
