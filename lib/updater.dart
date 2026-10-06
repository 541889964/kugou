import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bridge.dart';

class Updater {
  static final Updater I = Updater._();
  Updater._();
  static const url =
      'https://raw.githubusercontent.com/541889964/kugou/main/cloud/version.json';

  Future<void> check() async {
    try {
      final r = await Dio().get(url,
          options: Options(responseType: ResponseType.plain));
      final m = jsonDecode(r.data);
      final ver = int.tryParse('${m['engine']?['version']}') ?? 0;
      final sp = await SharedPreferences.getInstance();
      final local = sp.getInt('engine_ver') ?? 0;
      if (ver > local) {
        await Bridge.I.refresh();
        await sp.setInt('engine_ver', ver);
      }
    } catch (_) {}
  }
}
