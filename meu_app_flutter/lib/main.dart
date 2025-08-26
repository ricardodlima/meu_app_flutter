import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/01_tela_1_producao.dart';
import 'screens/05_tela_2_producao.dart';
import 'screens/106_tela_de_producao.dart';
import 'screens/103_configuracoes_screen.dart';
import 'screens/102_config_ethernet_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

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
      initialRoute: '/tela1',
      routes: {
        '/tela1': (context) => const Tela1Producao(),
        '/tela2': (context) => const Tela2Producao(),
        '/producao': (context) => const TelaDeProducao(),
        '/configuracoes': (context) => const ConfiguracoesScreen(),
        '/conf-ethernet': (context) => const ConfigEthernetScreen(),
      },
    );
  }
}
