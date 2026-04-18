import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper around [Connectivity] from `connectivity_plus`.
///
/// Centralises all connectivity checks so the rest of the app never imports
/// `connectivity_plus` directly.
///
/// ## Behaviour notes
/// - [isOnline] is a one-shot check of the current state.
/// - [onlineStream] emits `true` on any connection gained, `false` on loss.
/// - Connectivity is best-effort — a device can report wifi while behind a
///   captive portal with no real internet. The offline-cache sync strategy
///   therefore uses a try/catch fallback in addition to this check.
class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._();
  ConnectivityService._();

  final _connectivity = Connectivity();

  // ── Snapshot ─────────────────────────────────────────────────────────────────

  /// Returns `true` when at least one real network interface is available.
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return _hasConnection(results);
  }

  // ── Stream ───────────────────────────────────────────────────────────────────

  /// Broadcasts `true` when connectivity is gained and `false` when lost.
  ///
  /// Subscribe in [AppState] to trigger automatic re-fetches when the device
  /// comes back online after being offline.
  Stream<bool> get onlineStream =>
      _connectivity.onConnectivityChanged.map(_hasConnection);

  // ── Helper ────────────────────────────────────────────────────────────────────

  static bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn);
}
