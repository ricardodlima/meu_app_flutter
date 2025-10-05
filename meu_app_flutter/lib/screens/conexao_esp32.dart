import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/producao_service.dart';
import '../services/network_control_service.dart';
import '../services/esp32_connection_service.dart';

// Tela de Conexão ESP32 - Monitoramento do Contador
class ConexaoEsp32 extends StatefulWidget {
  const ConexaoEsp32({Key? key}) : super(key: key);

  @override
  State<ConexaoEsp32> createState() => _ConexaoEsp32State();
}

class _ConexaoEsp32State extends State<ConexaoEsp32> {
  String _statusConexao = 'Desconectado';
  int _contador1 = 0;
  bool _emProcessoDeConexao = false;
  bool _resetEmAndamento = false;

  late TextEditingController _ipController;
  late TextEditingController _portController;

  // Firebase
  final ProducaoService _producaoService = ProducaoService();
  int? _ultimoValorFirebase;
  
  // Controle de rede
  bool _networkControlSupported = false;
  bool _ethernetAvailable = false;
  bool _wifiAvailable = false;

  // Serviço compartilhado ESP32
  final Esp32ConnectionService _esp32Service = Esp32ConnectionService();

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: '192.168.1.100');
    _portController = TextEditingController(text: '8080');
    
    // Configurar listeners do serviço ESP32
    _esp32Service.addStatusListener(_onStatusChanged);
    _esp32Service.addContadorListener(_onContadorChanged);
    _esp32Service.addConnectionListener(_onConnectionChanged);
    
    _carregarContadorSalvo();
    _verificarControleDeRede();
    
    // Configurar e iniciar serviço ESP32
    print("Tela Conexão ESP32 - Configurando serviço..."); // DEBUG
    _esp32Service.setConfig(_ipController.text, _portController.text);
    _esp32Service.startAutoConnect();
    print("Tela Conexão ESP32 - Serviço iniciado"); // DEBUG
    
    // Usar o serviço compartilhado
    _statusConexao = _esp32Service.statusConexao;
    _contador1 = _esp32Service.contador1;
    _emProcessoDeConexao = _esp32Service.emProcessoDeConexao;
    
    // Forçar conexão após um pequeno delay se não estiver conectado
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!_esp32Service.isConnected) {
        print("Tela Conexão ESP32 - Forçando reconexão..."); // DEBUG
        _esp32Service.forceReconnect();
      }
    });
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

  Future<void> _verificarControleDeRede() async {
    try {
      final supported = await NetworkControlService.isNetworkControlSupported();
      final networkInfo = await NetworkControlService.getNetworkInfo();
      
      setState(() {
        _networkControlSupported = supported;
        _ethernetAvailable = networkInfo['hasEthernet'] ?? false;
        _wifiAvailable = networkInfo['hasWifi'] ?? false;
      });
      
      print('Controle de rede suportado: $_networkControlSupported');
      print('Ethernet disponível: $_ethernetAvailable');
      print('Wi-Fi disponível: $_wifiAvailable');
    } catch (e) {
      print('Erro ao verificar controle de rede: $e');
    }
  }

  Future<void> _forcarRedeEthernet() async {
    if (!_networkControlSupported || !_ethernetAvailable) {
      print('Controle de rede não disponível');
      return;
    }
    
    try {
      final success = await NetworkControlService.forceEthernetNetwork();
      if (success) {
        print('Rede Ethernet forçada com sucesso');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🌐 Rede Ethernet ativada para ESP32'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('Falha ao forçar rede Ethernet');
      }
    } catch (e) {
      print('Erro ao forçar rede Ethernet: $e');
    }
  }

  Future<void> _forcarRedeWifi() async {
    if (!_networkControlSupported || !_wifiAvailable) {
      print('Controle de rede não disponível');
      return;
    }
    
    try {
      final success = await NetworkControlService.forceWifiNetwork();
      if (success) {
        print('Rede Wi-Fi forçada com sucesso');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📶 Rede Wi-Fi ativada para internet'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('Falha ao forçar rede Wi-Fi');
      }
    } catch (e) {
      print('Erro ao forçar rede Wi-Fi: $e');
    }
  }


  @override
  void dispose() {
    // Remover listeners do serviço ESP32
    _esp32Service.removeStatusListener(_onStatusChanged);
    _esp32Service.removeContadorListener(_onContadorChanged);
    _esp32Service.removeConnectionListener(_onConnectionChanged);
    
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  // Callbacks do serviço ESP32
  void _onStatusChanged(String status) {
    if (mounted) {
      setState(() {
        _statusConexao = status;
      });
    }
  }

  void _onContadorChanged(int contador) {
    if (mounted) {
      setState(() {
        _contador1 = contador;
      });
      _salvarContador1(contador);
      if (contador != _ultimoValorFirebase) {
        _sincronizarComFirebase(contador);
      }
    }
  }

  void _onConnectionChanged(bool connected) {
    if (mounted) {
      setState(() {
        _emProcessoDeConexao = !connected && _esp32Service.emProcessoDeConexao;
      });
    }
  }


  Future<void> _sincronizarComFirebase(int novoValor) async {
    if (_networkControlSupported && _wifiAvailable) {
      await _forcarRedeWifi();
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    try {
      await _producaoService.atualizarEstadoGlobal(novoValor);
      _ultimoValorFirebase = novoValor;
    } catch (e) {
      print('Erro na sincronização Firebase: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    bool isConnected = _esp32Service.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conexão ESP32'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/configuracoes');
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Conexão ESP32', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text(_contador1.toString(), style: const TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          _esp32Service.incrementarContador();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('+1'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _resetEmAndamento = true;
                          });
                          _esp32Service.resetarContador();
                          Future.delayed(const Duration(milliseconds: 600), () async {
                            await _sincronizarComFirebase(0);
                            if (mounted) {
                              setState(() {
                                _resetEmAndamento = false;
                              });
                            }
                          });
                        },
                        child: const Text('Resetar Contador 1'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isConnected ? 'Conectado ao ESP32' : 'Desconectado do ESP32',
                    style: TextStyle(
                      color: isConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      _esp32Service.forcarAtualizacao();
                      if (!isConnected) {
                        _esp32Service.forceReconnect();
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Atualizar'),
                  ),
                  const SizedBox(height: 24),
                  
                  if (_networkControlSupported) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              '🌐 Controle de Rede',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _ethernetAvailable ? _forcarRedeEthernet : null,
                                  icon: const Icon(Icons.cable),
                                  label: const Text('Ethernet'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _wifiAvailable ? _forcarRedeWifi : null,
                                  icon: const Icon(Icons.wifi),
                                  label: const Text('Wi-Fi'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ethernet: ${_ethernetAvailable ? "✅" : "❌"} | Wi-Fi: ${_wifiAvailable ? "✅" : "❌"}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              '⚠️ Controle de Rede',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Controle programático de rede não suportado neste dispositivo',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/tela1');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'INICIO',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
