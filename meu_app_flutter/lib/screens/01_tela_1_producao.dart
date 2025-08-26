import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import '../services/network_control_service.dart';

class Tela1Producao extends StatefulWidget {
  const Tela1Producao({Key? key}) : super(key: key);

  @override
  State<Tela1Producao> createState() => _Tela1ProducaoState();
}

class _Tela1ProducaoState extends State<Tela1Producao> {
  int _contador1 = 0;
  String _statusConexao = 'Desconectado';
  bool _emProcessoDeConexao = false;
  
  Socket? _socket;
  Timer? _pollingTimer;
  Timer? _reconnectTimer;
  late TextEditingController _ipController;
  late TextEditingController _portController;

  // Controle de rede
  bool _networkControlSupported = false;
  bool _ethernetAvailable = false;
  bool _wifiAvailable = false;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: '192.168.1.100');
    _portController = TextEditingController(text: '8080');
    _carregarContadorSalvo();
    _verificarControleDeRede();
    _startAutoConnect();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _reconnectTimer?.cancel();
    _socket?.destroy();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _carregarContadorSalvo() async {
    final prefs = await SharedPreferences.getInstance();
    final valorSalvo = prefs.getInt('contador1') ?? 0;
    setState(() {
      _contador1 = valorSalvo;
    });
  }

  Future<void> _salvarContador1(int valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('contador1', valor);
  }

  /// Verifica se o controle programático de rede é suportado
  Future<void> _verificarControleDeRede() async {
    try {
      final supported = await NetworkControlService.isNetworkControlSupported();
      final networkInfo = await NetworkControlService.getNetworkInfo();
      
      setState(() {
        _networkControlSupported = supported;
        _ethernetAvailable = networkInfo['hasEthernet'] ?? false;
        _wifiAvailable = networkInfo['hasWifi'] ?? false;
      });
    } catch (e) {
      print('Erro ao verificar controle de rede: $e');
    }
  }

  /// Força o uso da rede Ethernet para comunicação com ESP32
  Future<void> _forcarRedeEthernet() async {
    if (!_networkControlSupported || !_ethernetAvailable) {
      return;
    }
    
    try {
      await NetworkControlService.forceEthernetNetwork();
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print('Erro ao forçar rede Ethernet: $e');
    }
  }

  void _startAutoConnect() {
    _tryConnect();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_socket == null && !_emProcessoDeConexao) {
        _tryConnect();
      }
    });
  }

  void _tryConnect() {
    if (!_emProcessoDeConexao && _socket == null) {
      _iniciarConexao();
    }
  }

  void _atualizarStatus(String status) {
    if (mounted) {
      setState(() {
        _statusConexao = status;
      });
    }
  }

  Future<void> _iniciarConexao() async {
    if (_emProcessoDeConexao || _socket != null) return;

    setState(() {
      _emProcessoDeConexao = true;
      _atualizarStatus('Conectando...');
    });
    
    try {
      // Força rede Ethernet para ESP32
      if (_networkControlSupported && _ethernetAvailable) {
        await _forcarRedeEthernet();
      }
      
      final ip = _ipController.text;
      final port = int.tryParse(_portController.text) ?? 8080;

      _socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      _atualizarStatus('Conectado');
      
      _socket!.listen(
        (List<int> dados) {
          final resposta = utf8.decode(dados).trim();
          _processarResposta(resposta);
        },
        onError: (error) {
          _handleDesconexao(erro: error.toString());
        },
        onDone: () {
          _handleDesconexao();
        },
      );

      // Inicia polling para manter conexão ativa
      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (_socket != null) {
          _enviarComando('getcounts');
        } else {
          timer.cancel();
        }
      });

    } catch (e) {
      _handleDesconexao(erro: e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _emProcessoDeConexao = false;
        });
      }
    }
  }

  void _handleDesconexao({String? erro}) {
    _socket?.destroy();
    _socket = null;
    _pollingTimer?.cancel();
    
    if (mounted) {
      setState(() {
        _emProcessoDeConexao = false;
      });
      _atualizarStatus(erro ?? 'Desconectado');
    }
  }

  void _enviarComando(String comando) {
    if (_socket != null) {
      try {
        _socket!.writeln(comando);
      } catch (e) {
        print('Erro ao enviar comando: $e');
      }
    }
  }

  void _processarResposta(String resposta) {
    if (!mounted) return;
    
    resposta.split('\n').where((linha) => linha.trim().isNotEmpty).forEach((linha) {
      if (linha.startsWith('C1:')) {
        final dados = linha.split(',');
        for (var dado in dados) {
          final partes = dado.split(':');
          if (partes.length == 2 && partes[0] == 'C1') {
            if (mounted) {
              setState(() {
                _contador1 = int.tryParse(partes[1]) ?? 0;
              });
              _salvarContador1(_contador1);
            }
          }
        }
      } else {
        _atualizarStatus(linha);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isConnected = _socket != null;
    
    return Scaffold(
      backgroundColor: const Color(0xFF212121), // Fundo escuro
      body: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              // Título no canto superior esquerdo
              Positioned(
                top: 16,
                left: 16,
                child: Text(
                  'Valor Atual da Produção',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Status de conexão no canto superior direito
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isConnected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isConnected ? Colors.green : Colors.red,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isConnected ? 'ESP32 OK' : 'ESP32 OFF',
                    style: TextStyle(
                      color: isConnected ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Display do contador no canto superior esquerdo
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  width: 246,
                  height: 82,
                  decoration: BoxDecoration(
                    color: const Color(0xFF80DEEA), // Azul claro
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      _contador1.toString().padLeft(4, '0'),
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),

              // Botão CONF no canto inferior direito
              Positioned(
                bottom: 16,
                right: 16,
                child: ElevatedButton(
                  onPressed: () {
                    // Navega para a Tela 2
                    Navigator.pushReplacementNamed(context, '/tela2');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BCD4), // Azul vibrante
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'CONF.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
