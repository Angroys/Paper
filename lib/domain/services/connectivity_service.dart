/// Online/offline signal. "Online" means a network interface is up AND a
/// lightweight ping succeeded, not just that Wi-Fi is connected.
abstract interface class ConnectivityService {
  /// Last known value (true until proven otherwise).
  bool get isOnline;

  /// Emits the current value on listen, then distinct changes.
  Stream<bool> watchOnline();

  /// Re-checks now (e.g. before a sync or after a request failed).
  Future<bool> check();
}
