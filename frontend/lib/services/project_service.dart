import 'package:flutter/material.dart';

class ProjectService extends ChangeNotifier {
  static final ProjectService _instance = ProjectService._internal();
  factory ProjectService() => _instance;
  ProjectService._internal();

  final List<Map<String, dynamic>> _addedProjects = [];

  List<Map<String, dynamic>> get addedProjects => List.unmodifiable(_addedProjects);

  void addProject(Map<String, dynamic> project) {
    // Add logic to avoid duplicates if necessary
    _addedProjects.add(project);
    notifyListeners();
  }
}
