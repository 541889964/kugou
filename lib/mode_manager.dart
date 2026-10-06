import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
class ModeManager extends ChangeNotifier {
  static final ModeManager I = ModeManager._();
  ModeManager._();
  bool _lite = true;
  bool get isLite => _lite;
  int get port => _lite ? 3000 : 3001;
  String get backendUrl => 'http://127.0.0.1:$port';
  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    _lite = (sp.getString('mode') ?? 'lite') != 'standard';
    notifyListeners();
  }
  Future<void> switchMode(bool lite) async {
    _lite = lite;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('mode', lite ? 'lite' : 'standard');
    notifyListeners();
  }
}
