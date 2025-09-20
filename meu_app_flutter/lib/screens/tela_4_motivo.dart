import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Tela4Motivo extends StatefulWidget {
  const Tela4Motivo({Key? key}) : super(key: key);

  @override
  _Tela4MotivoState createState() => _Tela4MotivoState();
}

class _Tela4MotivoState extends State<Tela4Motivo> {
  late List<TextEditingController> _controllers;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(50, (index) => TextEditingController());
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
      for (int i = 0; i < 50; i++) {
        _controllers[i].text = prefs.getString('motivo_${i + 1}') ?? '';
      }
      _isLoading = false;
    });
  }

  Future<void> _salvarMotivos() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < 50; i++) {
      await prefs.setString('motivo_${i + 1}', _controllers[i].text);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Motivos salvos com sucesso!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF303F9F),
        title: const Text('Cadastro de Motivos de Parada'),
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
              padding: const EdgeInsets.all(16.0),
              itemCount: 50,
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


