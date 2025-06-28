import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/tela_de_producao.dart';
import 'screens/configuracoes_screen.dart';
import 'screens/config_ethernet_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Contadores KC868-A16',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        scaffoldBackgroundColor: const Color(0xFFEFEFEF), // Fundo cinza claro
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF003366), // Azul escuro
          foregroundColor: Colors.white,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      initialRoute: '/producao',
      routes: {
        '/producao': (context) => const TelaDeProducao(),
        '/configuracoes': (context) => const ConfiguracoesScreen(),
        '/conf-ethernet': (context) => const ConfigEthernetScreen(),
      },
    );
  }
}
