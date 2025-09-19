import 'package:flutter/material.dart';

class ConfiguracoesScreen extends StatelessWidget {
  const ConfiguracoesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: Stack(
        children: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/conf-ethernet');
              },
              child: const Text('Conf Ethernet'),
            ),
          ),
          // Botão INICIO no canto inferior esquerdo
          Positioned(
            bottom: 16,
            left: 16,
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