import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Tela5MotivoParada extends StatefulWidget {
  const Tela5MotivoParada({Key? key}) : super(key: key);

  @override
  _Tela5MotivoParadaState createState() => _Tela5MotivoParadaState();
}

class _Tela5MotivoParadaState extends State<Tela5MotivoParada> {
  late List<TextEditingController> _controllers;
  bool _isLoading = true;
  final int _totalMotivos = 50;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_totalMotivos, (index) => TextEditingController());
    _carregarMotivos();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _carregarMotivos() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (int i = 0; i < _totalMotivos; i++) {
        _controllers[i].text = prefs.getString('motivo_parada_${i + 1}') ?? '';
      }
      _isLoading = false;
    });
  }

  Future<void> _salvarMotivos() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < _totalMotivos; i++) {
      await prefs.setString('motivo_parada_${i + 1}', _controllers[i].text);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Motivos de parada salvos com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF303F9F),
        title: const Text('Cadastro de Motivo de Subtração do Valor Total'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/tela2');
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Espaço para o botão
              itemCount: _totalMotivos,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Text(
                        '${index + 1}:',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _controllers[index],
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _salvarMotivos,
        label: const Text('SALVAR'),
        icon: const Icon(Icons.save),
        backgroundColor: const Color(0xFFFFA000),
      ),
    );
  }
}

