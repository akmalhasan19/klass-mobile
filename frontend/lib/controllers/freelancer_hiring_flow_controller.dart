import 'package:flutter/foundation.dart';

import '../services/media_generation_service.dart';

enum HiringMode { autoSuggest, manualTask, unset }

class FreelancerHiringFlowController extends ChangeNotifier {
  final MediaGenerationService apiService;
  final String generationId;

  String _refinementDescription = '';
  HiringMode _selectedMode = HiringMode.unset;
  int? _selectedFreelancerId;
  bool _isLoading = false;
  String? _errorMessage;

  FreelancerHiringFlowController({
    required this.apiService,
    required this.generationId,
  });

  String get refinementDescription => _refinementDescription;
  HiringMode get selectedMode => _selectedMode;
  int? get selectedFreelancerId => _selectedFreelancerId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setRefinementDescription(String description) {
    _refinementDescription = description;
    notifyListeners();
  }

  void selectMode(HiringMode mode) {
    _selectedMode = mode;
    notifyListeners();
  }

  void selectFreelancer(int id) {
    _selectedFreelancerId = id;
    notifyListeners();
  }

  Future<bool> submitHiring() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_selectedMode == HiringMode.unset) {
        throw Exception('Mode belum dipilih');
      }

      await apiService.hireFreelancer(
        generationId,
        mode: _selectedMode == HiringMode.autoSuggest ? 'auto_suggest' : 'manual_task',
        refinementDescription: _refinementDescription,
        selectedFreelancerId: _selectedFreelancerId,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void resetFlow() {
    _refinementDescription = '';
    _selectedMode = HiringMode.unset;
    _selectedFreelancerId = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
