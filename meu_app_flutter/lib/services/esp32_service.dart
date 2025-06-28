import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Esp32Service {
  static final Esp32Service _instance = Esp32Service._internal();
  factory Esp32Service() => _instance;
  Esp32Service._internal();

  String ip = '192.168.1.100';
  String porta = '8080';
  bool conectado = false;

  Future<bool> conectar() async {
    final url = Uri.parse('http://$ip:$porta/status');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        conectado = true;
        return true;
      }
    } catch (_) {}
    conectado = false;
    return false;
  }

  Future<int?> getContador1() async {
    final url = Uri.parse('http://$ip:$porta/contador1');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['contador1'] as int?;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> resetContador1() async {
    final url = Uri.parse('http://$ip:$porta/reset_contador1');
    try {
      final response = await http.post(url).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {}
    return false;
  }

  void setConfig(String newIp, String newPorta) {
    ip = newIp;
    porta = newPorta;
  }
} 