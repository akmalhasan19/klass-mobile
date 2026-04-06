import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:klass_app/l10n/generated/app_localizations.dart';

enum ApiDebugOperation {
  networkRequestFailed,
  homeProjectsLoadFailed,
  homeFreelancersLoadFailed,
  workspaceMaterialsLoadFailed,
}

class ApiDebugInfo {
  static const String _operationPrefix = 'Operation: ';
  static const String _endpointPrefix = 'Endpoint: ';
  static const String _methodPrefix = 'Method: ';
  static const String _urlPrefix = 'URL: ';
  static const String _statusPrefix = 'Status: ';
  static const String _dioTypePrefix = 'Dio Type: ';
  static const String _errorPrefix = 'Error: ';
  static const String _backendMessagePrefix = 'Backend Message: ';
  static const String _responsePrefix = 'Response: ';
  static const String _exceptionPrefix = 'Exception: ';
  static const String _invalidResponseFormatList =
      'Invalid response format. Expected data as List.';
  static const String _unknownNetworkError = 'Unknown network error';

  static String build(
    Object error, {
    required ApiDebugOperation operation,
    required String endpoint,
  }) {
    if (error is DioException) {
      final requestOptions = error.requestOptions;
      final statusCode = error.response?.statusCode;
      final responseData = error.response?.data;

      String? backendMessage;
      String? responseSnippet;

      if (responseData is Map<String, dynamic>) {
        final message = responseData['message'];
        if (message is String && message.isNotEmpty) {
          backendMessage = message;
        }
        responseSnippet = jsonEncode(responseData);
      } else if (responseData != null) {
        responseSnippet = responseData.toString();
      }

      if (responseSnippet != null && responseSnippet.length > 300) {
        responseSnippet = '${responseSnippet.substring(0, 300)}...';
      }

      final technicalMessage = _extractTechnicalMessage(error.message);
      final lines = <String>[
        '$_operationPrefix${operation.name}',
        '$_endpointPrefix$endpoint',
        '$_methodPrefix${requestOptions.method}',
        '$_urlPrefix${requestOptions.uri}',
        '$_statusPrefix${statusCode ?? '-'}',
        '$_dioTypePrefix${error.type.name}',
        '$_errorPrefix$technicalMessage',
      ];

      if (backendMessage != null) {
        lines.add('$_backendMessagePrefix$backendMessage');
      }

      if (responseSnippet != null && responseSnippet.isNotEmpty) {
        lines.add('$_responsePrefix$responseSnippet');
      }

      return lines.join('\n');
    }

    return [
      '$_operationPrefix${operation.name}',
      '$_endpointPrefix$endpoint',
      '$_errorPrefix${_stripExceptionPrefix(error.toString())}',
    ].join('\n');
  }

  static String localize(Object error, AppLocalizations? localizations) {
    final resolvedLocalizations =
        localizations ?? lookupAppLocalizations(const Locale('en'));
    final raw = _stripExceptionPrefix(error.toString());
    final lines = raw
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return '';
    }

    return lines
        .map((line) => _localizeLine(line, resolvedLocalizations))
        .join('\n');
  }

  static String _localizeLine(String line, AppLocalizations localizations) {
    if (line.startsWith(_operationPrefix)) {
      return _localizedOperation(
        line.substring(_operationPrefix.length),
        localizations,
      );
    }

    if (line.startsWith(_endpointPrefix)) {
      return '${localizations.debugInfoEndpointLabel}: '
          '${line.substring(_endpointPrefix.length)}';
    }

    if (line.startsWith(_methodPrefix)) {
      return '${localizations.debugInfoMethodLabel}: '
          '${line.substring(_methodPrefix.length)}';
    }

    if (line.startsWith(_urlPrefix)) {
      return '${localizations.debugInfoUrlLabel}: '
          '${line.substring(_urlPrefix.length)}';
    }

    if (line.startsWith(_statusPrefix)) {
      return '${localizations.debugInfoStatusLabel}: '
          '${line.substring(_statusPrefix.length)}';
    }

    if (line.startsWith(_dioTypePrefix)) {
      return '${localizations.debugInfoDioTypeLabel}: '
          '${line.substring(_dioTypePrefix.length)}';
    }

    if (line.startsWith(_errorPrefix)) {
      final value = line.substring(_errorPrefix.length);
      return '${localizations.debugInfoErrorLabel}: '
          '${_localizedTechnicalValue(value, localizations)}';
    }

    if (line.startsWith(_backendMessagePrefix)) {
      return '${localizations.debugInfoBackendMessageLabel}: '
          '${line.substring(_backendMessagePrefix.length)}';
    }

    if (line.startsWith(_responsePrefix)) {
      return '${localizations.debugInfoResponseLabel}: '
          '${line.substring(_responsePrefix.length)}';
    }

    return _localizedTechnicalValue(line, localizations);
  }

  static String _localizedOperation(
    String operationCode,
    AppLocalizations localizations,
  ) {
    switch (operationCode) {
      case 'networkRequestFailed':
        return localizations.debugInfoNetworkRequestFailed;
      case 'homeProjectsLoadFailed':
        return localizations.debugInfoHomeProjectsLoadFailed;
      case 'homeFreelancersLoadFailed':
        return localizations.debugInfoHomeFreelancersLoadFailed;
      case 'workspaceMaterialsLoadFailed':
        return localizations.debugInfoWorkspaceMaterialsLoadFailed;
      default:
        return operationCode;
    }
  }

  static String _localizedTechnicalValue(
    String value,
    AppLocalizations localizations,
  ) {
    switch (value) {
      case _invalidResponseFormatList:
        return localizations.debugInfoInvalidResponseFormatList;
      case _unknownNetworkError:
        return localizations.debugInfoUnknownNetworkError;
      default:
        return value;
    }
  }

  static String _extractTechnicalMessage(String? rawMessage) {
    if (rawMessage == null || rawMessage.trim().isEmpty) {
      return _unknownNetworkError;
    }

    if (!rawMessage.contains('\n')) {
      return _stripExceptionPrefix(rawMessage);
    }

    final lines = rawMessage
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    for (final line in lines.reversed) {
      if (line.startsWith(_errorPrefix)) {
        return line.substring(_errorPrefix.length);
      }
    }

    return _stripExceptionPrefix(lines.last);
  }

  static String _stripExceptionPrefix(String raw) {
    if (raw.startsWith(_exceptionPrefix)) {
      return raw.substring(_exceptionPrefix.length);
    }

    return raw;
  }
}