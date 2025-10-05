import 'dart:async';
import 'dart:convert';
import 'dart:io';

class Esp32ConnectionService {
  static final Esp32ConnectionService _instance = Esp32ConnectionService._internal();
  factory Esp32ConnectionService() => _instance;
  Esp32ConnectionService._internal();

  // Estado da conexão
  Socket? _socket;
  Timer? _pollingTimer;
  Timer? _reconnectTimer;
  String _statusConexao = 'Desconectado';
  bool _emProcessoDeConexao = false;
  int _contador1 = 0;

  // Configurações
  String _ip = '192.168.1.100';
  String _port = '8080';

  // Listeners para notificar mudanças
  final List<Function(String)> _statusListeners = [];
  final List<Function(int)> _contadorListeners = [];
  final List<Function(bool)> _connectionListeners = [];

  // Getters
  bool get isConnected => _socket != null;
  String get statusConexao => _statusConexao;
  int get contador1 => _contador1;
  bool get emProcessoDeConexao => _emProcessoDeConexao;

  // Métodos para adicionar listeners
  void addStatusListener(Function(String) listener) {
    _statusListeners.add(listener);
  }

  void addContadorListener(Function(int) listener) {
    _contadorListeners.add(listener);
  }

  void addConnectionListener(Function(bool) listener) {
    _connectionListeners.add(listener);
  }

  // Métodos para remover listeners
  void removeStatusListener(Function(String) listener) {
    _statusListeners.remove(listener);
  }

  void removeContadorListener(Function(int) listener) {
    _contadorListeners.remove(listener);
  }

  void removeConnectionListener(Function(bool) listener) {
    _connectionListeners.remove(listener);
  }

  // Notificar listeners
  void _notifyStatusListeners(String status) {
    for (var listener in _statusListeners) {
      listener(status);
    }
  }

  void _notifyContadorListeners(int contador) {
    for (var listener in _contadorListeners) {
      listener(contador);
    }
  }

  void _notifyConnectionListeners(bool connected) {
    for (var listener in _connectionListeners) {
      listener(connected);
    }
  }

  // Configurar conexão
  void setConfig(String ip, String port) {
    _ip = ip;
    _port = port;
  }

  // Iniciar conexão automática
  void startAutoConnect() {
    _tryConnect();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_socket == null && !_emProcessoDeConexao) {
        print("Tentando reconectar ao ESP32..."); // DEBUG
        _tryConnect();
      }
    });
  }

  // Forçar reconexão imediata
  void forceReconnect() {
    print("Forçando reconexão ao ESP32..."); // DEBUG
    _handleDesconexao();
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!_emProcessoDeConexao) {
        _iniciarConexao();
      }
    });
  }

  void _tryConnect() {
    if (!_emProcessoDeConexao && _socket == null) {
      _iniciarConexao();
    }
  }

  Future<void> _iniciarConexao() async {
    if (_emProcessoDeConexao || _socket != null) return;

    _emProcessoDeConexao = true;
    _notifyStatusListeners('Conectando...');

    try {
      final port = int.tryParse(_port) ?? 8080;
      print("Tentando conectar ao ESP32 em $_ip:$port"); // DEBUG
      _socket = await Socket.connect(_ip, port, timeout: const Duration(seconds: 5));
      
      _notifyStatusListeners('Conectado ao ESP32');
      _notifyConnectionListeners(true);

      _socket!.listen(
        (List<int> dados) {
          final resposta = utf8.decode(dados).trim();
          print("ESP32 Response: $resposta"); // DEBUG
          _processarResposta(resposta);
        },
        onError: (error) {
          print("Socket Error: $error"); // DEBUG
          _handleDesconexao(erro: error.toString());
        },
        onDone: () {
          print("Socket Connection Closed"); // DEBUG
          _handleDesconexao();
        },
      );

      _iniciarPollingAtivo();
    } catch (e) {
      print("Connection Error: $e"); // DEBUG
      _handleDesconexao(erro: e.toString());
    } finally {
      _emProcessoDeConexao = false;
    }
  }

  void _handleDesconexao({String? erro}) {
    _socket?.destroy();
    _socket = null;
    _pollingTimer?.cancel();
    _emProcessoDeConexao = false;
    
    String status = erro ?? 'Desconectado';
    _notifyStatusListeners(status);
    _notifyConnectionListeners(false);
  }

  void _iniciarPollingAtivo() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_socket != null) {
        print("Enviando comando getcounts"); // DEBUG
        _enviarComando('getcounts');
      } else {
        timer.cancel();
      }
    });
    
    // Timer para verificar se a conexão ainda está ativa
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_socket == null) {
        timer.cancel();
        return;
      }
      
      // Verificar se a conexão ainda está ativa
      try {
        _socket!.add([]); // Teste simples de conectividade
      } catch (e) {
        print("Conexão perdida, tentando reconectar...");
        _handleDesconexao();
      }
    });
  }

  void _enviarComando(String comando) {
    if (_socket != null) {
      try {
        print("Enviando comando: $comando"); // DEBUG
        _socket!.writeln(comando);
      } catch (e) {
        print('Erro ao enviar comando: $e');
      }
    }
  }

  void _processarResposta(String resposta) {
    print("Processando resposta: $resposta"); // DEBUG
    
    resposta
        .split('\n')
        .where((linha) => linha.trim().isNotEmpty)
        .forEach((linha) {
      print("Processando linha: $linha"); // DEBUG
      
      if (linha.startsWith('C1:')) {
        final dados = linha.split(',');
        for (var dado in dados) {
          final partes = dado.split(':');
          if (partes.length == 2 && partes[0] == 'C1') {
            final novoValor = int.tryParse(partes[1]) ?? 0;
            print("Novo valor C1 recebido: $novoValor (atual: $_contador1)"); // DEBUG
            
            if (novoValor != _contador1) {
              _contador1 = novoValor;
              print("Contador atualizado para: $_contador1"); // DEBUG
              _notifyContadorListeners(_contador1);
            }
          }
        }
      } else {
        print("Status update: $linha"); // DEBUG
        _notifyStatusListeners(linha);
      }
    });
  }

  // Métodos públicos para controle
  void incrementarContador() {
    _contador1++;
    _notifyContadorListeners(_contador1);
    _enviarComando('+1');
  }

  void decrementarContador() {
    if (_contador1 > 0) {
      _contador1--;
      _notifyContadorListeners(_contador1);
      _enviarComando('r1');
    }
  }

  void resetarContador() {
    _contador1 = 0;
    _notifyContadorListeners(_contador1);
    _enviarComando('r1');
  }

  void forcarAtualizacao() {
    _enviarComando('getcounts');
  }

  void desconectar() {
    _reconnectTimer?.cancel();
    _pollingTimer?.cancel();
    _socket?.destroy();
    _socket = null;
    _emProcessoDeConexao = false;
    _notifyStatusListeners('Desconectado');
    _notifyConnectionListeners(false);
  }

  void dispose() {
    desconectar();
    _statusListeners.clear();
    _contadorListeners.clear();
    _connectionListeners.clear();
  }
}
