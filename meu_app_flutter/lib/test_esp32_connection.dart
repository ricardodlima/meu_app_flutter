import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Script de teste para verificar conectividade com ESP32
/// Execute com: dart run lib/test_esp32_connection.dart
void main() async {
  final ip = '192.168.1.100';
  final port = 8080;
  
  print('=== TESTE DE CONEXÃO ESP32 ===');
  print('IP: $ip');
  print('Porta: $port');
  print('');
  
  Socket? socket;
  
  try {
    print('1. Tentando conectar ao ESP32...');
    socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
    print('✓ Conexão estabelecida com sucesso!');
    print('');
    
    // Configurar listener para receber dados
    socket.listen(
      (List<int> dados) {
        final resposta = utf8.decode(dados).trim();
        print('← Resposta recebida: $resposta');
      },
      onError: (error) {
        print('✗ Erro no socket: $error');
      },
      onDone: () {
        print('✓ Conexão fechada pelo ESP32');
      },
    );
    
    // Aguardar um pouco para estabilizar
    await Future.delayed(const Duration(seconds: 1));
    
    // Enviar comando getcounts
    print('2. Enviando comando "getcounts"...');
    socket.writeln('getcounts');
    print('→ Comando enviado');
    print('');
    
    // Aguardar resposta
    print('3. Aguardando resposta do ESP32...');
    await Future.delayed(const Duration(seconds: 3));
    
    // Enviar comando +1
    print('4. Enviando comando "+1"...');
    socket.writeln('+1');
    print('→ Comando enviado');
    print('');
    
    // Aguardar resposta
    await Future.delayed(const Duration(seconds: 2));
    
    // Enviar getcounts novamente
    print('5. Enviando comando "getcounts" novamente...');
    socket.writeln('getcounts');
    print('→ Comando enviado');
    print('');
    
    // Aguardar resposta
    await Future.delayed(const Duration(seconds: 3));
    
    print('=== TESTE CONCLUÍDO ===');
    
  } catch (e) {
    print('✗ Erro ao conectar: $e');
    print('');
    print('POSSÍVEIS CAUSAS:');
    print('1. ESP32 não está ligado ou não está na rede');
    print('2. IP incorreto (verifique se é 192.18.1.100)');
    print('3. Porta incorreta (verifique se é 8080)');
    print('4. Firewall bloqueando a conexão');
    print('5. ESP32 não está executando o servidor TCP');
  } finally {
    socket?.destroy();
    exit(0);
  }
}
