import 'package:flutter/services.dart';

/// Serviço para controle programático de redes no Android
/// Permite forçar o uso de Ethernet para ESP32 e Wi-Fi para internet
class NetworkControlService {
  static const MethodChannel _channel = MethodChannel('network_control');

  /// Força o uso da rede Ethernet para comunicação local
  /// Ideal para comunicação com ESP32 na rede 192.168.1.x
  static Future<bool> forceEthernetNetwork() async {
    try {
      final result = await _channel.invokeMethod('forceEthernetNetwork');
      print('Rede Ethernet forçada: $result');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Erro ao forçar rede Ethernet: ${e.message}');
      return false;
    }
  }

  /// Força o uso da rede Wi-Fi para internet
  /// Ideal para comunicação com Firebase e outros serviços online
  static Future<bool> forceWifiNetwork() async {
    try {
      final result = await _channel.invokeMethod('forceWifiNetwork');
      print('Rede Wi-Fi forçada: $result');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Erro ao forçar rede Wi-Fi: ${e.message}');
      return false;
    }
  }

  /// Retorna informações sobre as redes disponíveis
  static Future<Map<String, dynamic>> getNetworkInfo() async {
    try {
      final result = await _channel.invokeMethod('getNetworkInfo');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      print('Erro ao obter informações de rede: ${e.message}');
      return {};
    }
  }

  /// Verifica se o dispositivo suporta controle programático de rede
  static Future<bool> isNetworkControlSupported() async {
    try {
      final result = await _channel.invokeMethod('isNetworkControlSupported');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Controle de rede não suportado: ${e.message}');
      return false;
    }
  }

  /// Testa a conectividade com uma rede específica
  static Future<bool> testNetworkConnectivity(String networkType) async {
    try {
      final result = await _channel.invokeMethod('testNetworkConnectivity', {
        'networkType': networkType,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Erro ao testar conectividade: ${e.message}');
      return false;
    }
  }
} 