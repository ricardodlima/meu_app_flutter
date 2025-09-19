import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:async';

class ContadorScreen extends StatefulWidget {
  const ContadorScreen({Key? key}) : super(key: key);

  @override
  State<ContadorScreen> createState() => _ContadorScreenState();
}

class _ContadorScreenState extends State<ContadorScreen> {
  // --- Estado da UI ---
  String _statusConexao = 'Desconectado';
  final Map<String, int> _contadores = {'C1': 0, 'C2': 0, 'C3': 0, 'C4': 0};
  bool _emProcessoDeConexao = false;

  // --- Lógica de Conexão ---
  Socket? _socket;
  Timer? _pollingTimer;
  Timer? _reconnectTimer;
  late TextEditingController _ipController;
  late TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    // Inicializa os controladores com os valores padrão
    _ipController = TextEditingController(text: '192.168.1.100');
    _portController = TextEditingController(text: '8080');
    _startAutoConnect();
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
          print("Recebido do ESP32: $resposta");
          _processarResposta(resposta);
        },
        onError: (error) {
          print("Erro de socket: $error");
          _handleDesconexao(erro: error.toString());
        },
        onDone: () {
          print("Conexão encerrada pelo servidor.");
          _handleDesconexao();
        },
        cancelOnError: true,
      );

      _iniciarPolling();
      
    } catch (e) {
      print("Falha na conexão: $e");
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
        
        _contadores.updateAll((key, value) => 0);
      });
    }
    // Após desconexão, a reconexão automática já está ativa pelo timer
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
      print("Enviando comando: $comando");
      _socket!.writeln(comando);
    } else {
      _atualizarStatus("Erro: Não conectado.");
    }
  }

  void _processarResposta(String resposta) {
    resposta.split('\n').where((linha) => linha.trim().isNotEmpty).forEach((linha) {
      if (linha.startsWith('C1:')) {
        final dados = linha.split(',');
        final Map<String, int> novosContadores = {};
        for (var dado in dados) {
          final partes = dado.split(':');
          if (partes.length == 2) {
            novosContadores[partes[0]] = int.tryParse(partes[1]) ?? 0;
          }
        }
        if (mounted) {
          setState(() {
            _contadores.addAll(novosContadores);
          });
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
        title: const Text('IHM Contadores KC868-A16'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildConnectionCard(isConnected),
            const SizedBox(height: 12),
            _buildStatusChip(isConnected),
            const SizedBox(height: 20),
            _buildCountersGrid(isConnected),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete_sweep),
                label: const Text('RESETAR TODOS'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: isConnected ? () => _enviarComando('rall') : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard(bool isConnected){
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Configuração do Servidor", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.black87)),
            const SizedBox(height: 16),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(labelText: 'Endereço IP do ESP32', hintText: '192.168.1.100'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              enabled: !_emProcessoDeConexao,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(labelText: 'Porta TCP', hintText: '8080'),
              keyboardType: TextInputType.number,
              enabled: !_emProcessoDeConexao,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Reconectar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                padding: const EdgeInsets.symmetric(vertical: 14)
              ),
              onPressed: _emProcessoDeConexao ? null : () {
                FocusScope.of(context).unfocus();
                _tryConnect();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isConnected){
     return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isConnected ? Colors.green : Colors.orange),
      ),
      child: Text(
        'Status: $_statusConexao',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isConnected ? Colors.green[800] : Colors.orange[800],
        ),
      ),
    );
  }

  Widget _buildCountersGrid(bool isConnected) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.0,
      children: [
        _buildContadorCard('Contador 1', 'C1', isConnected),
        _buildContadorCard('Contador 2', 'C2', isConnected),
        _buildContadorCard('Contador 3', 'C3', isConnected),
        _buildContadorCard('Contador 4', 'C4', isConnected),
      ],
    );
  }

  Widget _buildContadorCard(String titulo, String chave, bool isConnected) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                (_contadores[chave] ?? 0).toString(),
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: isConnected ? Colors.indigo[900] : Colors.grey[400],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isConnected ? () => _enviarComando('r${chave.substring(1)}') : null,
                child: const Text('Reset'),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 