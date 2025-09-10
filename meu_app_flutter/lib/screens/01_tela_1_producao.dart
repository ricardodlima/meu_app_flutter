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
  late TextEditingController _operadorController;
  late TextEditingController _modeloPecaController;
  String _statusMaquinaSelecionado = '1';
  String _motivoSelecionado = '1';

  // Lista de opções para o status da máquina
  List<Map<String, String>> get _opcoesStatusMaquina {
    List<Map<String, String>> opcoes = [
      {'value': '1', 'label': '1 - Maquina em produção'},
      {'value': '2', 'label': '2 - Maquina Parada'},
      {'value': '3', 'label': '3 - Em Preparação'},
      {'value': '4', 'label': '4 - Em ajuste de Programa'},
      {'value': '5', 'label': '5 - Em Manutenção'},
      {'value': '6', 'label': '6 - Parada Banheiro'},
      {'value': '7', 'label': '7 - Para Refeição'},
    ];
    
    // Adiciona opções de 8 a 50 numeradas
    for (int i = 8; i <= 50; i++) {
      opcoes.add({'value': i.toString(), 'label': '$i - Opção $i'});
    }
    
    return opcoes;
  }

  // Lista de opções para o motivo
  List<Map<String, String>> get _opcoesMotivo {
    List<Map<String, String>> opcoes = [
      {'value': '1', 'label': '1 - Dimensão'},
      {'value': '2', 'label': '2 - Quebra'},
    ];
    
    // Adiciona opções de 3 a 10 vazias
    for (int i = 3; i <= 10; i++) {
      opcoes.add({'value': i.toString(), 'label': '$i -'});
    }
    
    return opcoes;
  }

  // Controle de rede
  bool _networkControlSupported = false;
  bool _ethernetAvailable = false;
  bool _wifiAvailable = false;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: '192.168.1.100');
    _portController = TextEditingController(text: '8080');
    _operadorController = TextEditingController(text: '00000');
    _modeloPecaController = TextEditingController(text: 'ABC-123');
    
    // Adiciona listener para o controlador do operador
    _operadorController.addListener(() {
      setState(() {
        // Força a atualização quando o controlador muda
      });
    });
    
    _carregarContadorSalvo();
    _carregarOperadorSalvo();
    _carregarModeloPecaSalvo();
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
    _operadorController.dispose();
    _modeloPecaController.dispose();
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

  Future<void> _carregarOperadorSalvo() async {
    final prefs = await SharedPreferences.getInstance();
    final operadorSalvo = prefs.getString('operador') ?? '00000';
    _operadorController.text = operadorSalvo;
    setState(() {
      // Força a atualização da interface
    });
  }

  Future<void> _salvarOperador(String operador) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('operador', operador);
  }

  Future<void> _carregarModeloPecaSalvo() async {
    final prefs = await SharedPreferences.getInstance();
    final modeloSalvo = prefs.getString('modelo_peca') ?? 'ABC-123';
    _modeloPecaController.text = modeloSalvo;
    setState(() {
      // Força a atualização da interface
    });
  }

  Future<void> _salvarModeloPeca(String modelo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('modelo_peca', modelo);
  }

  void _subtrairContagem() {
    if (_contador1 > 0) {
      setState(() {
        _contador1--;
      });
      _salvarContador1(_contador1);
      if (_socket != null) {
        _enviarComando('r1');
      }
    }
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
    return Scaffold(
      backgroundColor: const Color(0xFF262526), // Fundo cinza escuro como na imagem
      body: Container(
        width: 1024,
        height: 600,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(color: Color(0xFF262526)),
        child: Stack(
          children: [


            // Display "Valor Atual da Produção" (azul) - Lado esquerdo
            Positioned(
              left: 45,
              top: 50,
              child: Column(
                children: [
                  Text(
                    'Valor Atual da Produção',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 298,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2DA8D1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      _contador1.toString().padLeft(5, '0'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 64,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                ],
              ),
            ),


            // Display lado a lado - Nº operador e MODELO PEÇA
            Positioned(
              right: 50,
              top: 50,
              child: Row(
                children: [
                  // Nº operador (lado esquerdo)
                  Column(
                    children: [
                      Text(
                        'Nº operador',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 200, // Mesmo tamanho
                        height: 50, // Altura fixa
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFF00FF00), width: 3),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: _OperadorInputField(
                          controller: _operadorController,
                          onChanged: _salvarOperador,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  // MODELO PEÇA (lado direito) - mesmo tamanho
                  Column(
                    children: [
                      Text(
                        'MODELO PEÇA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 400, // Dobrou a largura (era 200, agora 400)
                        height: 50, // Altura fixa igual ao operador
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFF2DA8D1), width: 3),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: _ModeloPecaInputField(
                          controller: _modeloPecaController,
                          onChanged: _salvarModeloPeca,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Botão "CONF." - navega para tela2
            Positioned(
              left: 850,
              top: 450,
              child: ElevatedButton(
                onPressed: () {
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

            // Botão "Zerar Contagem"
            Positioned(
              left: 45,
              top: 180,
              child: SizedBox(
                width: 298,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _contador1 = 0;
                    });
                    _salvarContador1(0);
                    if (_socket != null) {
                      _enviarComando('r1');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: const Text(
                    'Zerar Contagem',
                    style: TextStyle(
                      fontSize: 24,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
              ),
            ),

            // Botão "HORA E TURNO"
            Positioned(
              left: 45,
              top: 250,
              child: SizedBox(
                width: 298,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/tela3');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800), // Laranja
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    elevation: 4,
                    shadowColor: const Color(0x33000000),
                  ),
                  child: const Text(
                    'HORA E TURNO',
                    style: TextStyle(
                      fontSize: 24,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            // Botão "Subtrair Contagem 1"
            Positioned(
              left: 360,
              top: 250,
              child: SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: _subtrairContagem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                      side: const BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  child: const Text(
                    'Subtrair Contagem 1',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            // Campo "Status da maquina" - DropdownButton
            Positioned(
              left: 45,
              top: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status da maquina',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 300,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.white, width: 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusMaquinaSelecionado,
                        isExpanded: true,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        items: _opcoesStatusMaquina.map((Map<String, String> opcao) {
                          return DropdownMenuItem<String>(
                            value: opcao['value'],
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                opcao['label']!,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? novoValor) {
                          if (novoValor != null) {
                            setState(() {
                              _statusMaquinaSelecionado = novoValor;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Campo "Motivo" - DropdownButton
            Positioned(
              left: 360,
              top: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Motivo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 200,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.white, width: 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _motivoSelecionado,
                        isExpanded: true,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        items: _opcoesMotivo.map((Map<String, String> opcao) {
                          return DropdownMenuItem<String>(
                            value: opcao['value'],
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                opcao['label']!,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? novoValor) {
                          if (novoValor != null) {
                            setState(() {
                              _motivoSelecionado = novoValor;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }
}

// Widget separado para o campo do operador
class _OperadorInputField extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onChanged;

  const _OperadorInputField({
    required this.controller,
    required this.onChanged,
  });

  @override
  State<_OperadorInputField> createState() => _OperadorInputFieldState();
}

class _OperadorInputFieldState extends State<_OperadorInputField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      setState(() {
        // Força a atualização quando o controlador muda
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      maxLength: 5,
      onChanged: (value) {
        print('Valor do operador alterado para: $value');
        setState(() {
          // Força a atualização da interface
        });
        widget.onChanged(value);
      },
      style: const TextStyle(
        color: Colors.black,
        fontSize: 24, // Reduzido de 64 para 24 (proporcional à caixa)
        fontFamily: 'Roboto',
        fontWeight: FontWeight.bold,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        counterText: '', // Remove o contador de caracteres
        hintText: '00000',
        hintStyle: TextStyle(
          color: Colors.black54,
          fontSize: 24, // Reduzido de 64 para 24 (proporcional à caixa)
          fontFamily: 'Roboto',
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// Widget para o campo de entrada do modelo da peça
class _ModeloPecaInputField extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onChanged;

  const _ModeloPecaInputField({
    required this.controller,
    required this.onChanged,
  });

  @override
  State<_ModeloPecaInputField> createState() => _ModeloPecaInputFieldState();
}

class _ModeloPecaInputFieldState extends State<_ModeloPecaInputField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      setState(() {
        // Força a atualização quando o controlador muda
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.text, // Aceita tanto números quanto letras
      maxLength: 20,
      textCapitalization: TextCapitalization.characters, // Converte para maiúsculas automaticamente
      onChanged: (value) {
        setState(() {
          // Força a atualização da interface
        });
        widget.onChanged(value);
      },
      style: const TextStyle(
        color: Colors.black,
        fontSize: 20, // Reduzido de 32 para 20 (mais fino)
        fontFamily: 'Roboto',
        fontWeight: FontWeight.bold,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        counterText: '', // Remove o contador de caracteres
        hintText: 'ABC-123',
        hintStyle: TextStyle(
          color: Colors.black54,
          fontSize: 20, // Reduzido de 32 para 20 (mais fino)
          fontFamily: 'Roboto',
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

