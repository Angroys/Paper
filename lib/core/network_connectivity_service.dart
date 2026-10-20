import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/services/connectivity_service.dart';
import 'streams.dart';

/// Lists the active network interfaces (connectivity_plus). Injectable.
typedef InterfaceCheck = Future<bool> Function();

/// Lightweight reachability probe. Injectable.
typedef ReachabilityPing = Future<bool> Function();

/// [ConnectivityService] = an interface is up (connectivity_plus) AND a
/// lightweight ping reaches the backend. Any HTTP answer counts as
/// reachable (even 401/404); only a network error / timeout is offline.
///
/// Re-checks on every interface change, and every [recheckInterval] while
/// offline (captive portals, server outages).
class NetworkConnectivityService implements ConnectivityService {
  NetworkConnectivityService({
    required this._hasInterface,
    required Stream<void> interfaceChanges,
    required this._ping,
    this.recheckInterval = const Duration(seconds: 30),
  }) : _changes = interfaceChanges;

  /// Production wiring: connectivity_plus + `GET <pingUri>`.
  factory NetworkConnectivityService.create({
    required Uri pingUri,
    http.Client? httpClient,
    Connectivity? connectivity,
  }) {
    final c = connectivity ?? Connectivity();
    final client = httpClient ?? http.Client();
    return NetworkConnectivityService(
      hasInterface: () async {
        try {
          final r = await c.checkConnectivity();
          return r.any((x) => x != ConnectivityResult.none);
        } on Object {
          return true; // Plugin unavailable: let the ping decide.
        }
      },
      interfaceChanges: _safeChanges(c),
      ping: () => httpPing(client, pingUri),
    );
  }

  static Stream<void> _safeChanges(Connectivity c) {
    try {
      return c.onConnectivityChanged.map((_) {});
    } on Object catch (e) {
      debugPrint('connectivity: change stream unavailable ($e)');
      return const Stream<void>.empty();
    }
  }

  /// `HEAD`-like probe: true on any HTTP response within [timeout].
  static Future<bool> httpPing(
    http.Client client,
    Uri uri, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      await client.get(uri).timeout(timeout);
      return true;
    } on Object {
      return false;
    }
  }

  final InterfaceCheck _hasInterface;
  final Stream<void> _changes;
  final ReachabilityPing _ping;
  final Duration recheckInterval;

  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<void>? _sub;
  Timer? _recheck;
  bool _online = true;
  bool _listening = false;

  @override
  bool get isOnline => _online;

  @override
  Stream<bool> watchOnline() {
    _ensureListening();
    return currentThenChanges(() => _online, _controller.stream);
  }

  void _ensureListening() {
    if (_listening) return;
    _listening = true;
    _sub = _changes.listen((_) => unawaited(check()));
    unawaited(check());
  }

  @override
  Future<bool> check() async {
    final online = await _hasInterface() && await _ping();
    _set(online);
    return online;
  }

  void _set(bool online) {
    _recheck?.cancel();
    if (!online) {
      _recheck = Timer(recheckInterval, () => unawaited(check()));
    }
    if (online == _online) return;
    _online = online;
    if (!_controller.isClosed) _controller.add(online);
  }

  Future<void> dispose() async {
    _recheck?.cancel();
    await _sub?.cancel();
    await _controller.close();
  }
}
