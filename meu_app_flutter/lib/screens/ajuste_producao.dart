import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AjusteProducao extends StatefulWidget {
  const AjusteProducao({Key? key}) : super(key: key);

  @override
  _AjusteProducaoState createState() => _AjusteProducaoState();
}

class _AjusteProducaoState extends State<AjusteProducao> {
  int? _linhaAtivaIndex;
  final int _totalLinhas = 20;
  // Alterado para 5 colunas de dados para incluir "T. max de Parada"
  late List<List<TextEditingController>> _controllers;

  @override
  void initState() {
    super.initState();
    _inicializarDados();
  }

  Future<void> _inicializarDados() async {
    // Agora gera 5 controllers por linha
    _controllers = List.generate(
      _totalLinhas,
      (i) => List.generate(5, (j) => TextEditingController()),
    );
    await _carregarDadosSalvos();
  }

  Future<void> _carregarDadosSalvos() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _linhaAtivaIndex = prefs.getInt('linhaAtivaIndex');
      for (int i = 0; i < _totalLinhas; i++) {
        _controllers[i][0].text = prefs.getString('linha_${i}_numProg') ?? '${i + 1}';
        _controllers[i][1].text = prefs.getString('linha_${i}_modelo') ?? 'PEÇA-${i + 1}';
        _controllers[i][2].text = prefs.getString('linha_${i}_tempo') ?? '00:00:00';
        _controllers[i][3].text = prefs.getString('linha_${i}_qtd') ?? '0';
        // Carrega o novo campo "T. max de Parada"
        _controllers[i][4].text = prefs.getString('linha_${i}_tempo_parada') ?? '00:00:00';
      }
    });
  }

  Future<void> _salvarDados() async {
    final prefs = await SharedPreferences.getInstance();
    if (_linhaAtivaIndex != null) {
      await prefs.setInt('linhaAtivaIndex', _linhaAtivaIndex!);
      
      final modeloAtivo = _controllers[_linhaAtivaIndex!][1].text;
      await prefs.setString('modelo_peca', modeloAtivo);
      
      final numProgramaAtivo = _controllers[_linhaAtivaIndex!][0].text;
      await prefs.setString('numero_programa', numProgramaAtivo);

      // Salva o "T. max de Parada" da linha ativa para uso em outras telas
      final tempoMaxParadaAtivo = _controllers[_linhaAtivaIndex!][4].text;
      await prefs.setString('tempo_max_parada', tempoMaxParadaAtivo);

    } else {
      await prefs.remove('linhaAtivaIndex');
      await prefs.remove('modelo_peca');
      await prefs.remove('numero_programa');
      await prefs.remove('tempo_max_parada'); // Remove também se nada for selecionado
    }

    for (int i = 0; i < _totalLinhas; i++) {
      await prefs.setString('linha_${i}_numProg', _controllers[i][0].text);
      await prefs.setString('linha_${i}_modelo', _controllers[i][1].text);
      await prefs.setString('linha_${i}_tempo', _controllers[i][2].text);
      await prefs.setString('linha_${i}_qtd', _controllers[i][3].text);
      // Salva o novo campo
      await prefs.setString('linha_${i}_tempo_parada', _controllers[i][4].text);
    }
  }

  @override
  void dispose() {
    for (var row in _controllers) {
      for (var controller in row) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _onLinhaAtivaChanged(int? index) {
    setState(() {
      _linhaAtivaIndex = (_linhaAtivaIndex == index) ? null : index;
    });
  }

  // Função genérica para selecionar o tempo
  Future<void> _selecionarTempo(int index, int controllerIndex) async {
    Duration duracaoInicial = Duration.zero;
    final tempoAtual = _controllers[index][controllerIndex].text;
    
    final parts = tempoAtual.split(':');
    if (parts.length == 3) {
      duracaoInicial = Duration(
        hours: int.tryParse(parts[0]) ?? 0,
        minutes: int.tryParse(parts[1]) ?? 0,
        seconds: int.tryParse(parts[2]) ?? 0,
      );
    }

    Duration? novaDuracao = duracaoInicial;

    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SizedBox(
          height: 250,
          child: Column(
            children: [
              Expanded(
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.hms,
                  initialTimerDuration: duracaoInicial,
                  onTimerDurationChanged: (Duration changedTimer) {
                    novaDuracao = changedTimer;
                  },
                ),
              ),
              TextButton(
                child: const Text('Confirmar'),
                onPressed: () {
                  setState(() {
                    _controllers[index][controllerIndex].text = _formatarDuracao(novaDuracao ?? Duration.zero);
                  });
                  Navigator.pop(context);
                },
              )
            ],
          ),
        );
      },
    );
  }

  String _formatarDuracao(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildTableHeader(),
              Expanded(child: _buildTableBody()),
              const SizedBox(height: 16),
              _buildBotaoInicio(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Align(
      alignment: Alignment.topLeft,
      child: Text(
        'Ajuste de Produção',
        style: TextStyle(
          color: Color(0xFFD0D0D0),
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  Widget _buildTableHeader() {
    const headerTextStyle = TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      decoration: const BoxDecoration(
        color: Color(0xFF333333),
        border: Border(bottom: BorderSide(color: Colors.grey)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Center(child: Text('Ativa', style: headerTextStyle))),
          Expanded(flex: 3, child: Center(child: Text('Numero do programa', style: headerTextStyle, textAlign: TextAlign.center,))),
          Expanded(flex: 4, child: Center(child: Text('MODELO PEÇA', style: headerTextStyle))),
          Expanded(flex: 3, child: Center(child: Text('Tempo ciclo', style: headerTextStyle))),
          // Novo Cabeçalho
          Expanded(flex: 3, child: Center(child: Text('T. max de Parada', style: headerTextStyle, textAlign: TextAlign.center,))),
          Expanded(flex: 3, child: Center(child: Text('Qtd p/ ciclo', style: headerTextStyle, textAlign: TextAlign.center,))),
          Expanded(flex: 2, child: Center(child: Text('Ferramentas', style: headerTextStyle))),
        ],
      ),
    );
  }
  
  Widget _buildTableBody() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        border: Border.all(color: Colors.grey),
      ),
      child: ListView.builder(
        itemCount: _totalLinhas,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: index % 2 == 0 ? const Color(0xFF2A2A2A) : const Color(0xFF212121),
              border: const Border(bottom: BorderSide(color: Colors.grey)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 2, child: _buildCheckbox(index)),
                  Expanded(flex: 3, child: _buildNumericCell(_controllers[index][0])),
                  Expanded(flex: 4, child: _buildEditableCell(_controllers[index][1])),
                  Expanded(flex: 3, child: _buildTempoCell(index, 2)), // Tempo de Ciclo
                  // Nova célula para T. max de Parada
                  Expanded(flex: 3, child: _buildTempoCell(index, 4)), // T. max de Parada
                  Expanded(flex: 3, child: _buildNumericCell(_controllers[index][3])),
                  Expanded(flex: 2, child: _buildBotaoFerramenta(index)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCheckbox(int index) {
    bool isSelected = _linhaAtivaIndex == index;
    return InkWell(
      onTap: () => _onLinhaAtivaChanged(index),
      child: Container(
        alignment: Alignment.center,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.grey.shade600),
          ),
          child: isSelected ? const Icon(Icons.check, color: Colors.green, size: 20) : null,
        ),
      ),
    );
  }
  
  Widget _buildEditableCell(TextEditingController controller) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4)
      ),
      child: TextFormField(
        controller: controller,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black, fontSize: 10),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        ),
      ),
    );
  }

  Widget _buildNumericCell(TextEditingController controller) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4)
      ),
      child: TextFormField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(color: Colors.black, fontSize: 10),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        ),
      ),
    );
  }

  // Célula genérica para os campos de tempo
  Widget _buildTempoCell(int index, int controllerIndex) {
    return InkWell(
      onTap: () => _selecionarTempo(index, controllerIndex),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4)
        ),
        alignment: Alignment.center,
        child: Text(
          _controllers[index][controllerIndex].text,
          style: const TextStyle(color: Colors.black, fontSize: 10),
        ),
      ),
    );
  }

  Widget _buildBotaoFerramenta(int index) {
    return InkWell(
       onTap: () {
         print('Botão Ferramenta da linha $index pressionado.');
       },
       child: const Center(
        child: Icon(Icons.arrow_forward_ios, color: Colors.red, size: 20),
      ),
    );
  }

  Widget _buildBotaoInicio() {
    return Align(
      alignment: Alignment.bottomLeft,
      child: ElevatedButton(
        onPressed: () async {
          await _salvarDados();
          Navigator.pushReplacementNamed(context, '/tela1');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00BCD4),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          'INICIO',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

