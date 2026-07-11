import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

mixin CancelableState<T extends StatefulWidget> on State<T> {
  CancelToken? _cancelToken;

  CancelToken get cancelToken => _cancelToken ??= CancelToken();

  @override
  void dispose() {
    _cancelToken?.cancel('Screen disposed');
    super.dispose();
  }
}
