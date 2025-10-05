import 'dart:async';
import 'dart:io';

/// Script para encontrar o ESP32 na rede local
/// Execute com: dart run lib/find_esp32.dart
void main() async {
  print('=== PROCURANDO ESP32 NA REDE ===');
  print('');
  
  // Faixas de IP comuns para ESP32
  final List<String> ipRanges = [
    '192.168.0.',    // Rede Wi-Fi padrão
    '192.168.1.',    // Rede alternativa
    '192.18.1.',     // IP original do app
    '10.0.0.',       // Rede alternativa
    '172.16.0.',     // Rede alternativa
  ];
  
  final List<int> commonPorts = [8080, 80, 23, 1234];
  
  for (final range in ipRanges) {
    print('Testando faixa: $range');
    
    for (int i = 100; i <= 110; i++) {
      final ip = '$range$i';
      
      for (final port in commonPorts) {
        try {
          final socket = await Socket.connect(ip, port, timeout: const Duration(milliseconds: 500));
          print('✓ ENCONTRADO! IP: $ip, Porta: $port');
          socket.destroy();
          
          // Testar se responde aos comandos ESP32
          await _testEsp32Commands(ip, port);
          
        } catch (e) {
          // Ignorar erros silenciosamente
        }
      }
    }
    print('');
  }
  
  print('=== FIM DA BUSCA ===');
  print('');
  print('SE NÃO ENCONTROU O ESP32:');
  print('1. Verifique se o ESP32 está ligado');
  print('2. Verifique se está conectado à mesma rede Wi-Fi');
  print('3. Verifique se o servidor TCP está rodando no ESP32');
  print('4. Verifique se não há firewall bloqueando');
}

Future<void> _testEsp32Commands(String ip, int port) async {
  try {
    print('  Testando comandos ESP32...');
    
    final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 2));
    
    // Enviar comando getcounts
    socket.writeln('getcounts');
    
    // Aguardar resposta
    final completer = Completer<String>();
    final subscription = socket.listen(
      (data) {
        final response = String.fromCharCodes(data).trim();
        print('  → Resposta: $response');
        if (!completer.isCompleted) {
          completer.complete(response);
        }
      },
      onError: (e) => print('  ✗ Erro: $e'),
    );
    
    // Aguardar resposta por 2 segundos
    try {
      await completer.future.timeout(const Duration(seconds: 2));
      print('  ✓ ESP32 respondeu aos comandos!');
    } catch (e) {
      print('  ✗ ESP32 não respondeu aos comandos');
    }
    
    subscription.cancel();
    socket.destroy();
    
  } catch (e) {
    print('  ✗ Erro ao testar comandos: $e');
  }
}
