import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';

class Tela03HoraTurno extends StatefulWidget {
  const Tela03HoraTurno({Key? key}) : super(key: key);

  @override
  State<Tela03HoraTurno> createState() => _Tela03HoraTurnoState();
}

class _Tela03HoraTurnoState extends State<Tela03HoraTurno> {
  // --- NOVA PALETA DE CORES HMI ---
  static const Color scaffoldBackground = Color(0xFF1A1A1A);
  static const Color containerBackground = Color(0xFF2B2B2B);
  static const Color headerColor = Color(0xFF2B2B2B);
  static const Color primaryTextColor = Color(0xFFD0D0D0);
  static const Color activeGreen = Color(0xFF2ECC71); // Verde para inputs e botões ativos
  static const Color highlightOrange = Color(0xFFF39C12); // Laranja para seleção
  static const Color inputFieldTextColor = Colors.white; // Texto para inputs verdes
  static const Color borderColor = Color(0xFF404040);
  // --- FIM DA NOVA PALETA ---

  // Controladores para os campos de entrada dos turnos (formato HH:mm)
  late final TextEditingController _entrada1Controller;
  late final TextEditingController _saida1Controller;
  late final TextEditingController _entrada2Controller;
  late final TextEditingController _saida2Controller;
  late final TextEditingController _entrada3Controller;
  late final TextEditingController _saida3Controller;

  // Controladores para os campos de hora (24 horas)
  late final List<TextEditingController> _horaInicioControllers;
  late final List<TextEditingController> _horaFimControllers;
  // Controladores para os campos de produção (24 horas)
  late final List<TextEditingController> _produzidaControllers;
  // Controladores para os campos de operador (24 horas)
  late final List<TextEditingController> _operadorControllers;
  // Controladores para os campos de modelo da peça (24 horas)
  late final List<TextEditingController> _modeloPecaControllers;

  // Formatador de máscara para os campos de produção
  final MaskTextInputFormatter _produzidaFormatter = MaskTextInputFormatter(
    mask: '#####', // Permite até 5 dígitos
    filter: {"#": RegExp(r'[0-9]')},
  );

   final MaskTextInputFormatter _timeFormatter = MaskTextInputFormatter(
    mask: '##:##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadTurnoValues();
  }

  void _initializeControllers() {
    // Inicializa controladores dos turnos
    _entrada1Controller = TextEditingController();
    _saida1Controller = TextEditingController();
    _entrada2Controller = TextEditingController();
    _saida2Controller = TextEditingController();
    _entrada3Controller = TextEditingController();
    _saida3Controller = TextEditingController();
    
    // Inicializa controladores de hora início (valores serão definidos pela lógica dos turnos)
    _horaInicioControllers = List.generate(24, (index) {
      final controller = TextEditingController();
      controller.text = '00:00'; // Valor temporário, será atualizado pela lógica dos turnos
      controller.addListener(() {
        _updateHoraFim(index);
      });
      return controller;
    });

    // Inicializa controladores de hora fim (valores serão definidos pela lógica dos turnos)
    _horaFimControllers = List.generate(24, (index) {
      final controller = TextEditingController();
      controller.text = '00:00'; // Valor temporário, será atualizado pela lógica dos turnos
      return controller;
    });

    // Inicializa controladores de produção
    _produzidaControllers = List.generate(24, (index) {
      final controller = TextEditingController();
      controller.text = '0';
      return controller;
    });
    
    // Inicializa controladores de operador
    _operadorControllers = List.generate(24, (index) {
      final controller = TextEditingController();
      controller.text = '';
      return controller;
    });
    
    // Inicializa controladores de modelo da peça
    _modeloPecaControllers = List.generate(24, (index) {
      final controller = TextEditingController();
      controller.text = '';
      return controller;
    });
  }

  Future<void> _loadTurnoValues() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Carrega valores salvos ou usa padrão
    _entrada1Controller.text = prefs.getString('turno1_entrada') ?? '00:00';
    _saida1Controller.text = prefs.getString('turno1_saida') ?? '00:00';
    _entrada2Controller.text = prefs.getString('turno2_entrada') ?? '00:00';
    _saida2Controller.text = prefs.getString('turno2_saida') ?? '00:00';
    _entrada3Controller.text = prefs.getString('turno3_entrada') ?? '00:00';
    _saida3Controller.text = prefs.getString('turno3_saida') ?? '00:00';
    
    // Adiciona listeners para salvar automaticamente quando mudar
    _entrada1Controller.addListener(() => _saveTurnoValue('turno1_entrada', _entrada1Controller.text));
    _saida1Controller.addListener(() => _saveTurnoValue('turno1_saida', _saida1Controller.text));
    _entrada2Controller.addListener(() => _saveTurnoValue('turno2_entrada', _entrada2Controller.text));
    _saida2Controller.addListener(() => _saveTurnoValue('turno2_saida', _saida2Controller.text));
    _entrada3Controller.addListener(() => _saveTurnoValue('turno3_entrada', _entrada3Controller.text));
    _saida3Controller.addListener(() => _saveTurnoValue('turno3_saida', _saida3Controller.text));
    
    print('Valores carregados:');
    print('Turno 1 - Entrada: ${_entrada1Controller.text}');
    print('Turno 1 - Saída: ${_saida1Controller.text}');
    print('Turno 2 - Entrada: ${_entrada2Controller.text}');
    print('Turno 2 - Saída: ${_saida2Controller.text}');
    print('Turno 3 - Entrada: ${_entrada3Controller.text}');
    print('Turno 3 - Saída: ${_saida3Controller.text}');
    
    // Atualiza a tabela baseada nos turnos carregados
    _updateTableFromTurns();
  }

  Future<void> _saveTurnoValue(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    print('Salvando $key: $value');
    
    // Atualiza a tabela quando um turno é alterado
    _updateTableFromTurns();
    
    // Salva no banco de dados
    await _saveTurnosToDatabase();
  }

  Future<void> _saveTurnosToDatabase() async {
    try {
      await DatabaseService.saveTurnosConfig(
        turno1Entrada: _entrada1Controller.text,
        turno1Saida: _saida1Controller.text,
        turno2Entrada: _entrada2Controller.text,
        turno2Saida: _saida2Controller.text,
        turno3Entrada: _entrada3Controller.text,
        turno3Saida: _saida3Controller.text,
      );
      print('Turnos salvos no banco de dados');
    } catch (e) {
      print('Erro ao salvar turnos no banco: $e');
    }
  }

  void _updateTableFromTurns() {
    // Pega o horário de início do primeiro turno
    final primeiroTurnoInicio = _entrada1Controller.text;
    
    if (primeiroTurnoInicio.isNotEmpty && primeiroTurnoInicio.length == 5) {
      try {
        final parts = primeiroTurnoInicio.split(':');
        final startHour = int.parse(parts[0]);
        final startMinute = int.parse(parts[1]);
        
        // Atualiza a tabela começando pelo horário do primeiro turno
        for (int i = 0; i < 24; i++) {
          final currentHour = (startHour + i) % 24;
          final currentMinute = startMinute;
          
          final horaInicio = '${currentHour.toString().padLeft(2, '0')}:${currentMinute.toString().padLeft(2, '0')}';
          final horaFim = '${((currentHour + 1) % 24).toString().padLeft(2, '0')}:${currentMinute.toString().padLeft(2, '0')}';
          
          _horaInicioControllers[i].text = horaInicio;
          _horaFimControllers[i].text = horaFim;
        }
        
        print('Tabela atualizada baseada no primeiro turno: $primeiroTurnoInicio');
      } catch (e) {
        print('Erro ao atualizar tabela: $e');
      }
    }
  }

  // Método para definir valores padrão (pode ser chamado se necessário)
  Future<void> _setDefaultTurnoValues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('turno1_entrada', '05:40');
    await prefs.setString('turno1_saida', '12:40');
    await prefs.setString('turno2_entrada', '12:40');
    await prefs.setString('turno2_saida', '22:00');
    await prefs.setString('turno3_entrada', '22:40');
    await prefs.setString('turno3_saida', '05:40');
    
    // Recarrega os valores
    _loadTurnoValues();
  }

  // Salva a produção da tabela no banco de dados
  Future<void> _saveProducaoToDatabase() async {
    try {
      // Obtém o número do operador salvo localmente
      final prefs = await SharedPreferences.getInstance();
      final operadorNumero = prefs.getString('operador') ?? '00000';
      final operadorId = 'operador_$operadorNumero';
      
      final hoje = DateTime.now();
      final data = '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}';
      
      List<Map<String, dynamic>> producaoData = [];
      
      for (int i = 0; i < 24; i++) {
        final quantidade = int.tryParse(_produzidaControllers[i].text) ?? 0;
        if (quantidade > 0) {
          producaoData.add({
            'hora': _horaInicioControllers[i].text,
            'quantidade': quantidade,
          });
        }
      }
      
      if (producaoData.isNotEmpty) {
        // Salva informações do operador no banco
        await DatabaseService.saveOperador(
          operadorId: operadorId,
          nome: 'Operador $operadorNumero',
          numero: operadorNumero,
        );
        
        // Salva a produção
        await DatabaseService.saveProducaoLote(
          data: data,
          producaoData: producaoData,
          operadorId: operadorId,
        );
        
        // Mostra mensagem de sucesso
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Produção salva: ${producaoData.length} registros - Operador: $operadorNumero'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nenhuma produção para salvar'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Erro ao salvar produção: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateHoraFim(int index) {
    if (index < 23) {
      final text = _horaInicioControllers[index].text;
      if (text.length == 5) {
        try {
          final parts = text.split(':');
          final hour = int.parse(parts[0]);
          final nextHour = (hour + 1).toString().padLeft(2, '0');
          _horaFimControllers[index].text = '$nextHour:00';
        } catch (e) {
          // Lida com formatação inválida
        }
      }
    }
  }

  @override
  void dispose() {
    _entrada1Controller.dispose();
    _saida1Controller.dispose();
    _entrada2Controller.dispose();
    _saida2Controller.dispose();
    _entrada3Controller.dispose();
    _saida3Controller.dispose();
    for (int i = 0; i < 24; i++) {
      _horaInicioControllers[i].dispose();
      _horaFimControllers[i].dispose();
      _produzidaControllers[i].dispose();
      _operadorControllers[i].dispose();
      _modeloPecaControllers[i].dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackground,
      appBar: AppBar(
        backgroundColor: headerColor,
        title: const Text(
          'Tabela de Horas e Produção',
          style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: primaryTextColor),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildTurnoSection(),
                const SizedBox(height: 20),
                _buildProducaoTable(),
              ],
            ),
          ),
          // Botão INICIO posicionado conforme a imagem
          Positioned(
            top: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/tela1');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4), // Azul vibrante
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 4,
                shadowColor: const Color(0x33000000),
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
          // Botão SALVAR PRODUÇÃO
          Positioned(
            bottom: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: _saveProducaoToDatabase,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50), // Verde
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 4,
                shadowColor: const Color(0x33000000),
              ),
              child: const Text(
                'SALVAR PRODUÇÃO',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTurnoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: containerBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Definição de Turnos',
            style: TextStyle(
                color: primaryTextColor,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildTurnoRow('1º Turno', _entrada1Controller, _saida1Controller),
          _buildTurnoRow('2º Turno', _entrada2Controller, _saida2Controller),
          _buildTurnoRow('3º Turno', _entrada3Controller, _saida3Controller),
        ],
      ),
    );
  }

  Widget _buildTurnoRow(
      String label, TextEditingController entrada, TextEditingController saida) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          // Label do turno
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(color: primaryTextColor, fontSize: 16)),
          ),
          const SizedBox(width: 16),
          // Grupo de campos Início e Fim
          Row(
            children: [
              const Text('Início:', style: TextStyle(color: primaryTextColor)),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: _TimeCell(controller: entrada),
              ),
              const SizedBox(width: 20),
              const Text('Fim:', style: TextStyle(color: primaryTextColor)),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: _TimeCell(controller: saida),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProducaoTable() {
    return Column(
      children: [
        _buildTableHeader(),
        Container(
          decoration: const BoxDecoration(
            color: containerBackground,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
          child: Row(
            children: [
              // Coluna Início
              Expanded(
                flex: 1,
                child: Column(
                  children: List.generate(24, (index) {
                    return _buildTimeColumn(
                      _horaInicioControllers[index],
                      index,
                    );
                  }),
                ),
              ),
              // Coluna Fim
              Expanded(
                flex: 1,
                child: Column(
                  children: List.generate(24, (index) {
                    return _buildTimeColumn(
                      _horaFimControllers[index],
                      index,
                    );
                  }),
                ),
              ),
              // Coluna Nº operador
              Expanded(
                flex: 1,
                child: Column(
                  children: List.generate(24, (index) {
                    return _buildOperadorColumn(
                      _operadorControllers[index],
                      index,
                    );
                  }),
                ),
              ),
              // Coluna Modelo da peça
              Expanded(
                flex: 1,
                child: Column(
                  children: List.generate(24, (index) {
                    return _buildModeloPecaColumn(
                      _modeloPecaControllers[index],
                      index,
                    );
                  }),
                ),
              ),
              // Coluna Produzida
              Expanded(
                flex: 1,
                child: Column(
                  children: List.generate(24, (index) {
                    return _buildProduzidaColumn(
                      _produzidaControllers[index],
                      index,
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: headerColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: const Row(
        children: [
          Expanded(
              flex: 1,
              child: Center(
                  child: Text('Início',
                      style: TextStyle(
                          color: primaryTextColor, fontWeight: FontWeight.bold)))),
          Expanded(
              flex: 1,
              child: Center(
                  child: Text('Fim',
                       style: TextStyle(
                          color: primaryTextColor, fontWeight: FontWeight.bold)))),
          Expanded(
              flex: 1,
              child: Center(
                  child: Text('Nº operador',
                      style: TextStyle(
                          color: primaryTextColor, fontWeight: FontWeight.bold)))),
          Expanded(
              flex: 1,
              child: Center(
                  child: Text('Modelo da peça',
                      style: TextStyle(
                          color: primaryTextColor, fontWeight: FontWeight.bold)))),
          Expanded(
              flex: 1,
              child: Center(
                  child: Text('Produzida',
                      style: TextStyle(
                          color: primaryTextColor, fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }

  Widget _buildTimeColumn(TextEditingController controller, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      child: _TimeCell(controller: controller),
    );
  }

  Widget _buildOperadorColumn(TextEditingController controller, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      child: _OperadorCell(controller: controller),
    );
  }

  Widget _buildModeloPecaColumn(TextEditingController controller, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      child: _ModeloPecaCell(controller: controller),
    );
  }

  Widget _buildProduzidaColumn(TextEditingController controller, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      child: _ProduzidaCell(controller: controller, formatter: _produzidaFormatter),
    );
  }
}

// Célula de tempo (VISUAL COMPLETAMENTE MODIFICADO)
class _TimeCell extends StatefulWidget {
  final TextEditingController controller;
  const _TimeCell({required this.controller});

  @override
  State<_TimeCell> createState() => _TimeCellState();
}

class _TimeCellState extends State<_TimeCell> {
  @override
  void initState() {
    super.initState();
    // Adiciona listener para atualizar a interface quando o valor mudar
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    // Remove o listener quando o widget for destruído
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    print('Listener detectou mudança no texto: ${widget.controller.text}');
    if (mounted) {
      setState(() {});
      print('setState chamado pelo listener');
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    // Tenta obter a hora atual do campo, se não conseguir usa a hora atual
    TimeOfDay initialTime = TimeOfDay.now();
    if (widget.controller.text.isNotEmpty && widget.controller.text.length == 5) {
      try {
        final parts = widget.controller.text.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        initialTime = TimeOfDay(hour: hour, minute: minute);
      } catch (e) {
        // Se houver erro, usa a hora atual
        initialTime = TimeOfDay.now();
      }
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      final String formattedTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      print('Horário selecionado: $formattedTime');
      widget.controller.text = formattedTime;
      print('Valor no controlador após definir: ${widget.controller.text}');
      // Força a atualização da interface
      if (mounted) {
        setState(() {});
        print('setState chamado');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _selectTime(context);
      },
      child: Container(
        height: 22,
        decoration: BoxDecoration(
          color: _Tela03HoraTurnoState.activeGreen,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            widget.controller.text.isEmpty ? '00:00' : widget.controller.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _Tela03HoraTurnoState.inputFieldTextColor,
                fontSize: 13,
                fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// Célula de produção (VISUAL COMPLETAMENTE MODIFICADO)
class _ProduzidaCell extends StatelessWidget {
  final TextEditingController controller;
  final MaskTextInputFormatter formatter;
  const _ProduzidaCell({required this.controller, required this.formatter});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      decoration: BoxDecoration(
        color: _Tela03HoraTurnoState.activeGreen, // MODIFICADO
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: TextField(
          controller: controller,
          textAlign: TextAlign.center,
          style: const TextStyle( // MODIFICADO
              color: _Tela03HoraTurnoState.inputFieldTextColor,
              fontSize: 14,
              fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
              border: InputBorder.none, contentPadding: EdgeInsets.only(bottom: 12)),
          keyboardType: TextInputType.number,
          inputFormatters: [formatter],
        ),
      ),
    );
  }
}

// Célula de operador
class _OperadorCell extends StatelessWidget {
  final TextEditingController controller;

  const _OperadorCell({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 5,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: '',
          hintText: '00000',
          hintStyle: TextStyle(
            color: Colors.black54,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// Célula de modelo da peça
class _ModeloPecaCell extends StatelessWidget {
  final TextEditingController controller;

  const _ModeloPecaCell({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.text,
        maxLength: 10,
        textCapitalization: TextCapitalization.characters,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: '',
          hintText: 'ABC-123',
          hintStyle: TextStyle(
            color: Colors.black54,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}