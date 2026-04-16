import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_service.dart';

enum HistoryViewState {
  idle,
  loading,
  success,
  error,
}

class GenerationHistoryService extends ChangeNotifier {
  static final GenerationHistoryService _instance = GenerationHistoryService._internal();

  factory GenerationHistoryService() {
    return _instance;
  }

  GenerationHistoryService._internal();

  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _generationHistory = [];
  String? _parentGenerationId;
  String? _errorMessage;
  HistoryViewState _viewState = HistoryViewState.idle;

  HistoryViewState get viewState => _viewState;
  List<Map<String, dynamic>> get generationHistory => _generationHistory;
  bool get isLoading => _viewState == HistoryViewState.loading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchParentChainHistory(String parentGenerationId) async {
    if (parentGenerationId.isEmpty) return;

    _viewState = HistoryViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.dio.get(
        '/media-generations',
        queryParameters: {'parent_id': parentGenerationId},
      );

      final List<dynamic>? data = response.data['data'];
      if (data == null) {
        _generationHistory = [];
      } else {
        _generationHistory = data.map((e) => e as Map<String, dynamic>).toList();
        // Sort by created_at ascending (oldest first)
        _generationHistory.sort((a, b) {
          final aDate = DateTime.parse(a['created_at']);
          final bDate = DateTime.parse(b['created_at']);
          return aDate.compareTo(bDate);
        });
      }

      _parentGenerationId = parentGenerationId;
      _viewState = HistoryViewState.success;
      notifyListeners();
    } on DioException catch (e) {
      _errorMessage = _resolveErrorMessage(e);
      _viewState = HistoryViewState.error;
      notifyListeners();
      rethrow;
    } catch (e) {
      _errorMessage = 'Gagal memuat riwayat generasi: $e';
      _viewState = HistoryViewState.error;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> refreshHistory() async {
    if (_parentGenerationId != null) {
      await fetchParentChainHistory(_parentGenerationId!);
    }
  }

  Future<void> getHistoryForGeneration(String generationId) async {
    _viewState = HistoryViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // First, get the generation details to find its parent_id
      final response = await _apiService.dio.get('/media-generations/$generationId');
      final Map<String, dynamic>? data = response.data['data'];
      
      if (data == null) {
        throw Exception('Generasi tidak ditemukan.');
      }

      final String? parentId = data['generated_from_id']?.toString();
      
      // If it's a child, fetch history for parent. If it's parent, fetch for itself.
      if (parentId != null && parentId.isNotEmpty) {
        await fetchParentChainHistory(parentId);
      } else {
        await fetchParentChainHistory(generationId);
      }
    } on DioException catch (e) {
      _errorMessage = _resolveErrorMessage(e);
      _viewState = HistoryViewState.error;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Gagal mengambil informasi generasi: $e';
      _viewState = HistoryViewState.error;
      notifyListeners();
    }
  }

  String _resolveErrorMessage(DioException error) {
    final responseData = error.response?.data;
    if (responseData is Map) {
      final structuredErrorMessage = responseData['error']?['message'];
      if (structuredErrorMessage != null && structuredErrorMessage.toString().isNotEmpty) {
        return structuredErrorMessage.toString();
      }

      final topLevelMessage = responseData['message'];
      if (topLevelMessage != null && topLevelMessage.toString().isNotEmpty) {
        return topLevelMessage.toString();
      }
    }

    return 'Terjadi kesalahan jaringan saat menghubungi server.';
  }
}
