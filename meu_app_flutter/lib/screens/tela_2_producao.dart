import 'package:flutter/material.dart';

class Tela2Producao extends StatelessWidget {
  const Tela2Producao({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF212121), // Fundo escuro
      body: SafeArea(
        child: Column(
          children: [
            // Título no canto superior esquerdo
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'tela 2 Producao',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // Área de conteúdo principal (expandida)
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16.0),
                padding: const EdgeInsets.all(16.0), // Padding interno para os botões
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    // Coluna de botões alinhada à direita
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 34.0, right: 34.0), // Espaçamento da borda
                        child: Column(
                          mainAxisSize: MainAxisSize.min, // A coluna ocupa apenas o espaço necessário
                          crossAxisAlignment: CrossAxisAlignment.end, // Alinha os botões à direita
                          children: [
                            _buildMenuButton(
                              context: context,
                              label: 'Ajuste de\nProdução',
                              onPressed: () {
                                Navigator.pushReplacementNamed(context, '/ajuste_producao');
                              },
                              backgroundColor: const Color(0xFF00BCD4), // Azul vibrante
                            ),
                            const SizedBox(height: 20),
                            _buildMenuButton(
                              context: context,
                              label: 'Cadastro de motivos\nde Subtrair peça', // TEXTO ALTERADO
                              onPressed: () {
                                Navigator.pushReplacementNamed(context, '/tela4');
                              },
                              backgroundColor: const Color(0xFFFFA000), // Laranja
                            ),
                            const SizedBox(height: 20),
                            _buildMenuButton(
                              context: context,
                              label: 'Cadastrar\nMotivos Parada',
                              onPressed: () {
                                Navigator.pushReplacementNamed(context, '/tela5');
                              },
                              backgroundColor: const Color(0xFFF44336), // Vermelho
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Botão INICIO no canto inferior esquerdo
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/tela1');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BCD4),
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
                    
                    
                    // Botão Telas 102-106 no canto inferior direito
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF80DEEA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/producao');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'PRO VERSION',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Telas 102 a 106',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward,
                                    color: Colors.grey[800],
                                    size: 16,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para criar os botões do menu com estilo padronizado
  Widget _buildMenuButton({
    required BuildContext context,
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
  }) {
    return SizedBox(
      width: 240, // Largura fixa para todos os botões
      height: 80,  // Altura fixa para todos os botões
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            height: 1.2, // Ajuste de altura da linha para o texto
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

