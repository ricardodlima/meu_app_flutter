import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Enum para representar o status da produção de forma clara e segura.
// Usar um enum é melhor do que usar Strings ("PRODUZINDO", "PARADA")
// porque evita erros de digitação.
enum StatusProducao { produzindo, parada }


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
  String _motivoSelecionado = '1';
  String _motivoParadaSelecionado = '1';

  // NOVA VARIÁVEL DE ESTADO para controlar o status da máquina.
  // Ela começa com o valor 'produzindo'.
  StatusProducao _statusProducao = StatusProducao.produzindo;

  // Variáveis para monitoramento de tempo de ciclo
  Timer? _timerCiclo;
  Timer? _timerPiscar;
  int _segundosCiclo = 0;
  bool _emAlerta = false;
  bool _piscando = false;
  int _tempoCicloLimite = 11; // Valor padrão, será atualizado dinamicamente da linha ativa


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

  List<Map<String, String>> get _opcoesMotivoParada {
    List<Map<String, String>> opcoes = [
      {'value': '1', 'label': '1 - ALMOCO'},
      {'value': '2', 'label': '2 - BANHEIRO'},
      {'value': '3', 'label': '3 - Setup'},
      {'value': '4', 'label': '4 - Limpeza'},
      {'value': '5', 'label': '5 - Outro'},
    ];
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recarrega tempo limite quando a tela é reconstruída
    _recarregarTempoLimite();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _reconnectTimer?.cancel();
    _timerCiclo?.cancel();
    _timerPiscar?.cancel();
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
    await _carregarTempoLimiteDinamico();
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

  // Converte tempo HH:MM:SS para segundos
  int _converterTempoParaSegundos(String tempo) {
    final parts = tempo.split(':');
    if (parts.length == 3) {
      int horas = int.tryParse(parts[0]) ?? 0;
      int minutos = int.tryParse(parts[1]) ?? 0;
      int segundos = int.tryParse(parts[2]) ?? 0;
      return horas * 3600 + minutos * 60 + segundos;
    }
    return 0;
  }

  Future<void> _carregarTempoLimiteDinamico() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Carrega tempo de ciclo e tempo max de parada da linha ativa
    final tempoCiclo = prefs.getString('tempo_ciclo_ativo') ?? '00:00:00';
    final tempoMaxParada = prefs.getString('tempo_max_parada') ?? '00:00:00';
    
    // Converte para segundos e soma
    final segundosCiclo = _converterTempoParaSegundos(tempoCiclo);
    final segundosMaxParada = _converterTempoParaSegundos(tempoMaxParada);
    
    setState(() {
      _tempoCicloLimite = segundosCiclo + segundosMaxParada;
    });
    
    print('Tempo limite carregado: ${segundosCiclo}s + ${segundosMaxParada}s = ${_tempoCicloLimite}s');
  }

  // Método para recarregar tempo limite (útil quando voltar da tela de ajuste)
  Future<void> _recarregarTempoLimite() async {
    await _carregarTempoLimiteDinamico();
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
    resposta
        .split('\n')
        .where((linha) => linha.trim().isNotEmpty)
        .forEach((linha) {
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
              // ZERAR TIMER DE CICLO quando recebe pulso ESP32
              _zerarTimerCiclo();
            }
          }
        }
      } else {
        _atualizarStatus(linha);
      }
    });
  }

  // Métodos para controle do timer de ciclo
  void _iniciarTimerCiclo() {
    if (_statusProducao == StatusProducao.produzindo && !_emAlerta) {
      _timerCiclo?.cancel();
      _timerCiclo = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _statusProducao == StatusProducao.produzindo) {
          setState(() {
            _segundosCiclo++;
          });
          _verificarLimiteTempo();
        }
      });
    }
  }

  void _pararTimerCiclo() {
    _timerCiclo?.cancel();
  }

  void _zerarTimerCiclo() {
    setState(() {
      _segundosCiclo = 0;
      // NÃO remove o alerta automaticamente - só remove quando motivo for selecionado
    });
    _pararTimerCiclo();
    _iniciarTimerCiclo();
  }

  void _zerarTimerEAlerta() {
    setState(() {
      _segundosCiclo = 0;
      _emAlerta = false;
    });
    _pararPiscar();
    _pararTimerCiclo();
    _iniciarTimerCiclo();
  }

  void _verificarLimiteTempo() {
    if (_segundosCiclo > _tempoCicloLimite && !_emAlerta) {
      setState(() {
        _emAlerta = true;
      });
      _iniciarPiscar();
      // Não mostrar diálogo - usar dropdown existente
    }
  }

  void _iniciarPiscar() {
    _timerPiscar?.cancel();
    _timerPiscar = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted && _emAlerta) {
        setState(() {
          _piscando = !_piscando;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _pararPiscar() {
    _timerPiscar?.cancel();
    setState(() {
      _piscando = false;
    });
  }



  void _confirmarMotivoParadaDropdown(String motivoValue) {
    // Encontrar o motivo correspondente ao valor selecionado
    String motivo = _opcoesMotivoParada.firstWhere(
      (opcao) => opcao['value'] == motivoValue,
      orElse: () => {'value': motivoValue, 'label': 'Motivo desconhecido'}
    )['label']!;
    
    // Usar o método que zera timer E remove alerta
    _zerarTimerEAlerta();
    
    // Salvar motivo e timestamp no histórico
    print('Motivo da parada: $motivo - Tempo: ${_formatarTempo(_segundosCiclo)}');
    
    // Mostrar confirmação visual
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Motivo registrado: $motivo'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatarTempo(int segundos) {
    int horas = segundos ~/ 3600;
    int minutos = (segundos % 3600) ~/ 60;
    int segs = segundos % 60;
    return '${horas.toString().padLeft(2, '0')}:${minutos.toString().padLeft(2, '0')}:${segs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF262526),
      body: Column(
        children: [
          // Barra de alerta piscante
          if (_emAlerta) _buildBarraAlerta(),
          Expanded(
            child: SingleChildScrollView(
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
          ),
        ],
      ),
    );
  }

  // Widget para barra de alerta piscante
  Widget _buildBarraAlerta() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: _piscando ? Colors.red : Colors.green,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'Tempo de ciclo excedido. Selecione o motivo na caixa "Motivo de Parada".',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
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
            padding: const EdgeInsets.all(6.0),
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
                    height: 35,
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
                          fontSize: 28,
                          fontFamily: 'Roboto'),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _buildTempoCicloDisplayCompact(),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
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
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5)),
                        ),
                        child: const Text('Zerar Contagem',
                            style: TextStyle(fontSize: 14, fontFamily: 'Roboto')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Caixa 2: Subtrair e Motivo
          Container(
            padding: const EdgeInsets.all(6.0),
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
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                      side: const BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  child: const Text('Subtrair Contagem 1',
                      style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 6),
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
          const SizedBox(height: 6),
          // Caixa 3: Motivo de Parada
          Container(
            padding: const EdgeInsets.all(6.0),
            decoration: BoxDecoration(
              color: const Color(0xFF303F9F),
              borderRadius: BorderRadius.circular(5),
            ),
            child: _buildDropdown(
                'Motivo de Parada', _motivoParadaSelecionado, _opcoesMotivoParada,
                (val) {
              if (val != null) {
                setState(() {
                  _motivoParadaSelecionado = val;
                });
                // Se está em alerta, confirmar motivo e zerar timer
                if (_emAlerta) {
                  _confirmarMotivoParadaDropdown(val);
                }
              }
            }),
          ),
          const SizedBox(height: 6), // Espaçamento antes do novo widget
          
          // Botão de Status da Produção - Movido para coluna esquerda
          Container(
            padding: const EdgeInsets.all(6.0),
            decoration: BoxDecoration(
              color: const Color(0xFF303F9F),
              borderRadius: BorderRadius.circular(5),
            ),
            child: _buildStatusSelector(),
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
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 250,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _contador1++;
                        });
                        _salvarContador1(_contador1);
                        // Zera o timer de ciclo porque uma peça foi produzida manualmente
                        _zerarTimerCiclo();
                        if (_socket != null) {
                          _enviarComando('+1');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                      ),
                      child: const Text('+ +1',
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

  // Widget compacto para mostrar o tempo de ciclo (no lugar do botão +1)
  Widget _buildTempoCicloDisplayCompact() {
    return Container(
      height: 35,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _emAlerta ? Colors.red.withOpacity(0.3) : const Color(0xFF2D3980),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: _emAlerta ? Colors.red : const Color(0xFF2D3980),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _formatarTempo(_segundosCiclo),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _emAlerta ? Colors.white : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_statusProducao == StatusProducao.produzindo && !_emAlerta)
            Text(
              'Lim: ${_formatarTempo(_tempoCicloLimite)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 8,
              ),
            ),
        ],
      ),
    );
  }

  // NOVO WIDGET para criar o seletor de status
  Widget _buildStatusSelector() {
    return Center(
      child: ToggleButtons(
        // Define quais botões estão selecionados
        isSelected: [
          _statusProducao == StatusProducao.produzindo,
          _statusProducao == StatusProducao.parada,
        ],
        // Função chamada quando um botão é pressionado
        onPressed: (int index) {
          setState(() {
            // Atualiza a variável de estado com base no botão clicado
            _statusProducao =
                index == 0 ? StatusProducao.produzindo : StatusProducao.parada;
            
            // Controla o timer de ciclo baseado no status
            if (_statusProducao == StatusProducao.produzindo) {
              _iniciarTimerCiclo();
            } else {
              _pararTimerCiclo();
              _pararPiscar();
              setState(() {
                _segundosCiclo = 0;
                _emAlerta = false;
              });
            }
          });
        },
        // Estilização dinâmica baseada no status selecionado
        color: Colors.white.withOpacity(0.7), // Cor do texto não selecionado
        selectedColor: Colors.white,         // Cor do texto selecionado
        fillColor: _statusProducao == StatusProducao.produzindo 
            ? Colors.green  // Verde para PRODUZINDO
            : Colors.red,   // Vermelho para PARADA
        borderColor: _statusProducao == StatusProducao.produzindo 
            ? Colors.green 
            : Colors.red,
        selectedBorderColor: Colors.white,
        borderRadius: BorderRadius.circular(5.0),
        borderWidth: 2,
        children: <Widget>[
          // Botão "PRODUZINDO"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('PRODUZINDO', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          // Botão "PARADA"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('PARADA', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildDropdown(String label, String value,
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
          height: 40,
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
