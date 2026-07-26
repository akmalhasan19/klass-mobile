import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionChangeController =
      StreamController<bool>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isConnected = true;

  bool get isConnected => _isConnected;
  Stream<bool> get onConnectionChange => _connectionChangeController.stream;

  void initialize() {
    try {
      _subscription = _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
        onError: (err) {
          debugPrint('ConnectivityService: stream error: $err');
        },
      );
    } catch (e) {
      debugPrint('ConnectivityService: failed to listen to connectivity stream: $e');
    }
    _checkInitialConnection();
  }


  Future<void> _checkInitialConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      debugPrint('ConnectivityService: failed to check initial connection: $e');
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    _updateConnectionStatus(results);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasConnected = _isConnected;
    _isConnected = results.any((r) => r != ConnectivityResult.none);

    if (wasConnected != _isConnected) {
      _connectionChangeController.add(_isConnected);
    }
  }

  void dispose() {
    _subscription?.cancel();
    _connectionChangeController.close();
  }
}
