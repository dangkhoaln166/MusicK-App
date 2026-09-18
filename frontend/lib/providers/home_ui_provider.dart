import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:convert';

class TextElementConfig {
  String? text;
  String? fontFamily;
  int? color;
  double? size;
  double? dx;
  double? dy;

  TextElementConfig({this.text, this.fontFamily, this.color, this.size, this.dx, this.dy});

  Map<String, dynamic> toJson() => {
        'text': text,
        'fontFamily': fontFamily,
        'color': color,
        'size': size,
        'dx': dx,
        'dy': dy,
      };

  static TextElementConfig fromJson(Map<String, dynamic> json) {
    return TextElementConfig(
      text: json['text'],
      fontFamily: json['fontFamily'],
      color: json['color'],
      size: json['size']?.toDouble(),
      dx: json['dx']?.toDouble(),
      dy: json['dy']?.toDouble(),
    );
  }
}

class HomeUiProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isEditMode = false;
  
  double _bannerHeight = 300.0;
  double? _bannerWidth;
  double _imageOffsetX = 0.0;
  double _imageOffsetY = 0.0;
  TextElementConfig _greetingConfig = TextElementConfig();
  TextElementConfig _bannerTitleConfig = TextElementConfig();
  TextElementConfig _bannerSubtitleConfig = TextElementConfig();

  bool get isEditMode => _isEditMode;
  double get bannerHeight => _bannerHeight;
  double? get bannerWidth => _bannerWidth;
  double get imageOffsetX => _imageOffsetX;
  double get imageOffsetY => _imageOffsetY;
  TextElementConfig get greetingConfig => _greetingConfig;
  TextElementConfig get bannerTitleConfig => _bannerTitleConfig;
  TextElementConfig get bannerSubtitleConfig => _bannerSubtitleConfig;

  HomeUiProvider() {
    _loadSettings();
  }

  void toggleEditMode() {
    _isEditMode = !_isEditMode;
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final settings = await _apiService.getSettings();
    
    _bannerHeight = double.tryParse(settings['home_ui_bannerHeight'] ?? '') ?? 300.0;
    _bannerWidth = double.tryParse(settings['home_ui_bannerWidth'] ?? '');
    _imageOffsetX = double.tryParse(settings['home_ui_imageOffsetX'] ?? '') ?? 0.0;
    _imageOffsetY = double.tryParse(settings['home_ui_imageOffsetY'] ?? '') ?? 0.0;
    
    final greetingStr = settings['home_ui_greeting'];
    if (greetingStr != null && greetingStr.isNotEmpty) _greetingConfig = TextElementConfig.fromJson(jsonDecode(greetingStr));
    
    final titleStr = settings['home_ui_bannerTitle'];
    if (titleStr != null && titleStr.isNotEmpty) _bannerTitleConfig = TextElementConfig.fromJson(jsonDecode(titleStr));
    
    final subStr = settings['home_ui_bannerSubtitle'];
    if (subStr != null && subStr.isNotEmpty) _bannerSubtitleConfig = TextElementConfig.fromJson(jsonDecode(subStr));
    
    notifyListeners();
  }

  Future<void> _saveConfig(String key, TextElementConfig config) async {
    await _apiService.updateSetting(key, jsonEncode(config.toJson()));
  }

  void updateBannerHeight(double height) async {
    _bannerHeight = height;
    notifyListeners();
    await _apiService.updateSetting('home_ui_bannerHeight', height.toString());
  }

  void updateBannerWidth(double width) async {
    _bannerWidth = width;
    notifyListeners();
    await _apiService.updateSetting('home_ui_bannerWidth', width.toString());
  }

  void updateImageOffset(double dx, double dy) async {
    _imageOffsetX = dx;
    _imageOffsetY = dy;
    notifyListeners();
    await _apiService.updateSetting('home_ui_imageOffsetX', dx.toString());
    await _apiService.updateSetting('home_ui_imageOffsetY', dy.toString());
  }

  void updateGreeting(TextElementConfig config) {
    _greetingConfig = config;
    notifyListeners();
    _saveConfig('home_ui_greeting', config);
  }

  void updateBannerTitle(TextElementConfig config) {
    _bannerTitleConfig = config;
    notifyListeners();
    _saveConfig('home_ui_bannerTitle', config);
  }

  void updateBannerSubtitle(TextElementConfig config) {
    _bannerSubtitleConfig = config;
    notifyListeners();
    _saveConfig('home_ui_bannerSubtitle', config);
  }
}
