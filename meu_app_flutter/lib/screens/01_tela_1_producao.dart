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
      backgroundColor: const Color(0xFF262526), // Fundo cinza escuro como no B.txt
      body: Container(
        width: 1024,
        height: 600,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(color: Color(0xFF262526)),
        child: Stack(
          children: [
            // Título "Valor Atual da Produção" - canto superior esquerdo
            Positioned(
              left: 16,
              top: 20,
              child: SizedBox(
                width: 360,
                child: Text(
                  'Valor Atual da Produção',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ),

            // Título "Nº operador" - canto superior direito
            Positioned(
              left: 677,
              top: 18,
              child: SizedBox(
                width: 360,
                child: Text(
                  'Nº operador',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ),

            // Display "0000" (azul) - esquerda, abaixo do título
            Positioned(
              left: 45,
              top: 75,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: const Color(0xFF2DA8D1), // Azul como no B.txt
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  _contador1.toString().padLeft(4, '0'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 64,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ),

            // Display "00000" (verde) - direita, abaixo do título
            Positioned(
              left: 740,
              top: 75,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF00), // Verde brilhante como no B.txt
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  '00000',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 64,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ),

            // Botão "CONF." - canto inferior direito
            Positioned(
              left: 850,
              top: 450,
              child: ElevatedButton(
                onPressed: () {
                  // Navegar para a tela 2 (05_tela_2_producao)
                  Navigator.pushReplacementNamed(context, '/tela2');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2DA8D1),
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                    side: const BorderSide(
                      width: 2,
                      color: Color(0xFF2DA9D2),
                    ),
                  ),
                  elevation: 4,
                  shadowColor: const Color(0x33000000),
                ),
                child: const Text(
                  'CONF.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
