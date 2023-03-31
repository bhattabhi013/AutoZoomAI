import 'package:flutter/material.dart';

class ImageProviderLocal extends ChangeNotifier {
  List<String> _imagePaths = [];

  void setPath(List<String> paths) {
    _imagePaths = paths;
    notifyListeners();
  }

  List<String> getPath() {
    return _imagePaths;
  }
}
