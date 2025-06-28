import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/producao_service.dart';

class TelaDeProducao extends StatefulWidget {
  const TelaDeProducao({Key? key}) : super(key: key);

  @override
  State<TelaDeProducao> createState() => _TelaDeProducaoState();
}

class _TelaDeProducaoState extends State<TelaDeProducao> {
  String _statusConexao = 'Desconectado';
  int _contador1 = 0;
  bool _emProcessoDeConexao = false;

  Socket? _socket;
  Timer? _pollingTimer;
  Timer? _reconnectTimer;
  late TextEditingController _ipController;
  late TextEditingController _portController;

  // Firebase
  final ProducaoService _producaoService = ProducaoService();
  int? _ultimoValorFirebase;
  String? _loteAtualId;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: '192.168.1.100');
    _portController = TextEditingController(text: '8080');
    _carregarContadorSalvo();
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

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _reconnectTimer?.cancel();
    _socket?.destroy();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
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
      _atualizarStatus('Conectando a ${_ipController.text}:${_portController.text}...');
    });
    
    try {
      final ip = _ipController.text;
      final port = int.tryParse(_portController.text) ?? 8080;

      _socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      _atualizarStatus('Conectado a $ip:$port');
      
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
        cancelOnError: true,
      );

      _iniciarPolling();
      
    } catch (e) {
      _handleDesconexao(erro: e.toString());
    } finally {
      if(mounted) setState(() => _emProcessoDeConexao = false);
    }
  }

  void _handleDesconexao({String? erro}) {
    _pollingTimer?.cancel();
    _socket?.destroy();
    _socket = null;
    if (mounted) {
      setState(() {
        _emProcessoDeConexao = false;
        String erroMsg = erro != null ? erro.split(':').last.trim() : 'Desconectado';
        if (erroMsg.contains("errno = 101")) erroMsg = "Rede inalcançável. Verifique o IP e a rede da IHM.";
        if (erroMsg.contains("errno = 111")) erroMsg = "Conexão recusada. Verifique o IP/Porta e se o ESP32 está ligado.";
        if (erroMsg.contains("timed out")) erroMsg = "Tempo esgotado. Verifique o IP e a rede.";
        _statusConexao = erro != null ? 'Erro: $erroMsg' : 'Desconectado';
      });
    }
  }

  void _iniciarPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_socket != null) {
        _enviarComando('getcounts');
      } else {
        timer.cancel();
      }
    });
  }

  void _enviarComando(String comando) {
    if (_socket != null) {
      _socket!.writeln(comando);
    } else {
      _atualizarStatus("Erro: Não conectado.");
    }
  }

  // Função cérebro: sincroniza com o Firestore
  Future<void> _sincronizarComFirebase(int novoValor) async {
    // Início de lote
    if ((_ultimoValorFirebase == null || _ultimoValorFirebase == 0) && novoValor > 0) {
      _loteAtualId = await _producaoService.criarNovoLote();
      await _producaoService.atualizarEstadoGlobal(novoValor, _loteAtualId);
    }
    // Fim de lote
    else if (_ultimoValorFirebase != null && _ultimoValorFirebase! > 0 && novoValor == 0 && _loteAtualId != null) {
      await _producaoService.finalizarLote(_loteAtualId!, _ultimoValorFirebase!);
      await _producaoService.atualizarEstadoGlobal(novoValor, null);
      _loteAtualId = null;
    }
    // Atualização normal
    else if (_loteAtualId != null) {
      await _producaoService.atualizarEstadoGlobal(novoValor, _loteAtualId);
    }
    _ultimoValorFirebase = novoValor;
  }

  void _processarResposta(String resposta) {
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
              // Integração Firestore: só sincroniza se mudou
              if (_contador1 != _ultimoValorFirebase) {
                _sincronizarComFirebase(_contador1);
              }
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
      appBar: AppBar(
        title: const Text('Tela de Produção'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/configuracoes');
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Contador 1', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(_contador1.toString(), style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: isConnected ? () => _enviarComando('r1') : null,
                child: const Text('Resetar Contador 1'),
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
                onPressed: _tryConnect,
                icon: const Icon(Icons.refresh),
                label: const Text('Atualizar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 