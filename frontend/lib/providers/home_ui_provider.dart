import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    final prefs = await SharedPreferences.getInstance();
    
    _bannerHeight = prefs.getDouble('home_ui_bannerHeight') ?? 300.0;
    _bannerWidth = prefs.getDouble('home_ui_bannerWidth');
    _imageOffsetX = prefs.getDouble('home_ui_imageOffsetX') ?? 0.0;
    _imageOffsetY = prefs.getDouble('home_ui_imageOffsetY') ?? 0.0;
    
    final greetingStr = prefs.getString('home_ui_greeting');
    if (greetingStr != null) _greetingConfig = TextElementConfig.fromJson(jsonDecode(greetingStr));
    
    final titleStr = prefs.getString('home_ui_bannerTitle');
    if (titleStr != null) _bannerTitleConfig = TextElementConfig.fromJson(jsonDecode(titleStr));
    
    final subStr = prefs.getString('home_ui_bannerSubtitle');
    if (subStr != null) _bannerSubtitleConfig = TextElementConfig.fromJson(jsonDecode(subStr));
    
    notifyListeners();
  }

  Future<void> _saveConfig(String key, TextElementConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(config.toJson()));
  }

  void updateBannerHeight(double height) async {
    _bannerHeight = height;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('home_ui_bannerHeight', height);
  }

  void updateBannerWidth(double width) async {
    _bannerWidth = width;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('home_ui_bannerWidth', width);
  }

  void updateImageOffset(double dx, double dy) async {
    _imageOffsetX = dx;
    _imageOffsetY = dy;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('home_ui_imageOffsetX', dx);
    await prefs.setDouble('home_ui_imageOffsetY', dy);
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
