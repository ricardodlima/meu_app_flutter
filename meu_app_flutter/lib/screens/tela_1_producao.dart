import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Supondo que este seja o caminho correto para o seu serviço
// import '../services/network_control_service.dart';

// --- INÍCIO: Bloco de código para simular o serviço ausente ---
// Remova ou comente este bloco se você tiver o arquivo network_control_service.dart
class NetworkControlService {
  static Future<bool> isNetworkControlSupported() async => false;
  static Future<Map<String, bool>> getNetworkInfo() async =>
      {'hasEthernet': false, 'hasWifi': false};
  static Future<void> forceEthernetNetwork() async {}
}
// --- FIM: Bloco de código para simular o serviço ausente ---

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
  late TextEditingController _numeroProgramaController;
  String _statusMaquinaSelecionado = '1';
  String _motivoSelecionado = '1';

  // Lista para armazenar os motivos de parada carregados
  List<Map<String, String>> _opcoesMotivoParada = [];
  // Variável para armazenar o motivo de parada selecionado
  String? _motivoParadaSelecionado;

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
    for (int i = 8; i <= 50; i++) {
      opcoes.add({'value': i.toString(), 'label': '$i - Opção $i'});
    }
    return opcoes;
  }

  List<Map<String, String>> get _opcoesMotivo {
    List<Map<String, String>> opcoes = [
      {'value': '1', 'label': '1 - Dimensão'},
      {'value': '2', 'label': '2 - Quebra'},
    ];
    // ALTERADO: Loop agora vai até 50
    for (int i = 3; i <= 50; i++) {
      opcoes.add({'value': i.toString(), 'label': '$i -'});
    }
    return opcoes;
  }

  bool _networkControlSupported = false;
  bool _ethernetAvailable = false;
  bool _wifiAvailable = false;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: '192.18.1.100');
    _portController = TextEditingController(text: '8080');
    _operadorController = TextEditingController(text: '00000');
    _modeloPecaController = TextEditingController();
    _numeroProgramaController = TextEditingController();
    _operadorController.addListener(() {
      setState(() {});
    });
    _carregarDadosIniciais();
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
    _numeroProgramaController.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosIniciais() async {
    await _carregarContadorSalvo();
    await _carregarOperadorSalvo();
    await _carregarModeloPecaSalvo();
    await _carregarNumeroProgramaSalvo();
    await _carregarMotivosDeParada(); // Carrega os motivos de parada
    _verificarControleDeRede();
    _startAutoConnect();
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
    setState(() {});
  }

  Future<void> _salvarOperador(String operador) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('operador', operador);
  }

  Future<void> _carregarModeloPecaSalvo() async {
    final prefs = await SharedPreferences.getInstance();
    final modeloSalvo = prefs.getString('modelo_peca') ?? 'N/A';
    _modeloPecaController.text = modeloSalvo;
    setState(() {});
  }

  Future<void> _carregarNumeroProgramaSalvo() async {
    final prefs = await SharedPreferences.getInstance();
    final numProgSalvo = prefs.getString('numero_programa') ?? 'N/A';
    _numeroProgramaController.text = numProgSalvo;
    setState(() {});
  }

  Future<void> _salvarModeloPeca(String modelo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('modelo_peca', modelo);
  }

  // --- MÉTODOS ADICIONADOS ---

  /// Carrega os motivos de parada salvos na tela 5.
  Future<void> _carregarMotivosDeParada() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, String>> motivosCarregados = [];
    for (int i = 1; i <= 50; i++) {
      final motivo = prefs.getString('motivo_parada_$i');
      if (motivo != null && motivo.isNotEmpty) {
        motivosCarregados.add({'value': i.toString(), 'label': '$i - $motivo'});
      }
    }
    setState(() {
      _opcoesMotivoParada = motivosCarregados;
      // Define o primeiro motivo como selecionado, se houver algum
      if (_opcoesMotivoParada.isNotEmpty) {
        _motivoParadaSelecionado = _opcoesMotivoParada.first['value'];
      }
    });
  }

  /// Salva o registro da subtração no Firestore.
  Future<void> _salvarSubtracaoNoFirestore() async {
    if (_motivoParadaSelecionado == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione um motivo de parada.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final motivoLabel = _opcoesMotivoParada
        .firstWhere((element) => element['value'] == _motivoParadaSelecionado,
            orElse: () => {'label': 'Motivo não encontrado'})['label'];

    try {
      await FirebaseFirestore.instance.collection('subtracoes').add({
        'contador_valor_apos_subtracao': _contador1,
        'motivo_id': _motivoParadaSelecionado,
        'motivo_label': motivoLabel,
        'timestamp': FieldValue.serverTimestamp(),
        'operador': _operadorController.text,
        'modelo_peca': _modeloPecaController.text,
        'numero_programa': _numeroProgramaController.text,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subtração salva no banco de dados.'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar no banco de dados: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- MÉTODO ALTERADO ---
  void _subtrairContagem() {
    if (_contador1 > 0) {
      setState(() {
        _contador1--;
      });
      _salvarContador1(_contador1);

      // Salva a informação no Firestore
      _salvarSubtracaoNoFirestore();

      if (_socket != null) {
        // Se precisar enviar um comando para o ESP32, mantenha aqui
        // _enviarComando('subtrair_c1'); por exemplo
      }
    }
  }

  // --- RESTANTE DO CÓDIGO (sem alterações) ---

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
      if (_networkControlSupported && _ethernetAvailable) {
        await _forcarRedeEthernet();
      }
      final ip = _ipController.text;
      final port = int.tryParse(_portController.text) ?? 8080;
      _socket =
          await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
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
    resposta.split('\n').where((linha) => linha.trim().isNotEmpty).forEach((
      linha,
    ) {
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
      backgroundColor: const Color(0xFF262526),
      body: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLeftColumn(),
            const SizedBox(width: 20),
            _buildRightColumn(),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftColumn() {
    return SizedBox(
      width: 298,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Caixa 1: Valor da Produção e Zerar
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: const Color(0xFF303F9F),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInfoColumn(
                  'Valor Atual da Produção',
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFADFF2F),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      _contador1.toString().padLeft(5, '0'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 40,
                          fontFamily: 'Roboto'),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
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
                        borderRadius: BorderRadius.circular(5)),
                  ),
                  child: const Text('Zerar Contagem',
                      style: TextStyle(fontSize: 24, fontFamily: 'Roboto')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Caixa 2: Subtrair e Motivo
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: const Color(0xFF303F9F),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
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
                  child: const Text('Subtrair Contagem 1',
                      style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                _buildDropdown('Motivo', _motivoSelecionado, _opcoesMotivo,
                    (val) {
                  if (val != null) {
                    setState(() {
                      _motivoSelecionado = val;
                    });
                  }
                }),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Caixa 3: Motivo de Parada
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: const Color(0xFF303F9F),
              borderRadius: BorderRadius.circular(5),
            ),
            // Alteração aqui para usar os motivos de parada carregados
            child: _buildDropdown(
                'Motivo de Parada', _motivoParadaSelecionado, _opcoesMotivoParada,
                (val) {
              if (val != null) {
                setState(() {
                  _motivoParadaSelecionado = val;
                });
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildRightColumn() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: const Color(0xFF303F9F),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildInfoColumn(
                    'NUMERO DO PROGRAMA',
                    child: Container(
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border:
                            Border.all(color: const Color(0xFF2DA8D1), width: 3),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: TextField(
                        controller: _numeroProgramaController,
                        readOnly: true,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                            border: InputBorder.none, isDense: true),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildInfoColumn(
                    'MODELO PEÇA',
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border:
                            Border.all(color: const Color(0xFF2DA8D1), width: 3),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: _ModeloPecaInputField(
                        controller: _modeloPecaController,
                        onChanged: _salvarModeloPeca,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildInfoColumn(
                    'Nº operador',
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border:
                            Border.all(color: const Color(0xFF00FF00), width: 3),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: _OperadorInputField(
                        controller: _operadorController,
                        onChanged: _salvarOperador,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 250,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/tela3');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                      ),
                      child: const Text('HORA E TURNO',
                          style: TextStyle(
                              fontSize: 20,
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 250,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/tela2');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2DA8D1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                      ),
                      child: const Text('CONF.',
                          style: TextStyle(
                              fontSize: 20,
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  Widget _buildDropdown(String label, String? value,
      List<Map<String, String>> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
              items: items.map((Map<String, String> item) {
                return DropdownMenuItem<String>(
                  value: item['value'],
                  child: Text(item['label']!,
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

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
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: TextField(
        controller: widget.controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 5,
        onChanged: (value) {
          widget.onChanged(value);
        },
        style: const TextStyle(
          color: Colors.black,
          fontSize: 24,
          fontFamily: 'Roboto',
          fontWeight: FontWeight.bold,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: '',
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

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
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.text,
      maxLength: 20,
      textCapitalization: TextCapitalization.characters,
      onChanged: (value) {
        widget.onChanged(value);
      },
      style: const TextStyle(
        color: Colors.black,
        fontSize: 20,
        fontFamily: 'Roboto',
        fontWeight: FontWeight.bold,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        counterText: '',
        hintText: 'ABC-123',
        hintStyle: TextStyle(
          color: Colors.black54,
          fontSize: 20,
          fontFamily: 'Roboto',
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
