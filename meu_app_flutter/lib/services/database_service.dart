import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Coleções do Firestore
  static const String _turnosCollection = 'turnos';
  static const String _producaoCollection = 'producao';
  static const String _operadoresCollection = 'operadores';

  /// Salva a configuração dos turnos
  static Future<void> saveTurnosConfig({
    required String turno1Entrada,
    required String turno1Saida,
    required String turno2Entrada,
    required String turno2Saida,
    required String turno3Entrada,
    required String turno3Saida,
  }) async {
    try {
      final turnosData = {
        'turno1': {
          'entrada': turno1Entrada,
          'saida': turno1Saida,
        },
        'turno2': {
          'entrada': turno2Entrada,
          'saida': turno2Saida,
        },
        'turno3': {
          'entrada': turno3Entrada,
          'saida': turno3Saida,
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(_turnosCollection)
          .doc('config')
          .set(turnosData, SetOptions(merge: true));

      print('Configuração dos turnos salva com sucesso');
    } catch (e) {
      print('Erro ao salvar configuração dos turnos: $e');
      rethrow;
    }
  }

  /// Salva dados de produção por hora
  static Future<void> saveProducaoHora({
    required String data, // formato: YYYY-MM-DD
    required String hora, // formato: HH:mm
    required int quantidade,
    required String operadorId,
  }) async {
    try {
      final producaoData = {
        'data': data,
        'hora': hora,
        'quantidade': quantidade,
        'operadorId': operadorId,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(_producaoCollection)
          .add(producaoData);

      print('Produção salva: $quantidade peças às $hora do dia $data');
    } catch (e) {
      print('Erro ao salvar produção: $e');
      rethrow;
    }
  }

  /// Salva dados de produção em lote (para toda a tabela)
  static Future<void> saveProducaoLote({
    required String data,
    required List<Map<String, dynamic>> producaoData,
    required String operadorId,
  }) async {
    try {
      final batch = _firestore.batch();
      
      for (var item in producaoData) {
        final docRef = _firestore.collection(_producaoCollection).doc();
        batch.set(docRef, {
          'data': data,
          'hora': item['hora'],
          'quantidade': item['quantidade'],
          'operadorId': operadorId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('Produção em lote salva: ${producaoData.length} registros');
    } catch (e) {
      print('Erro ao salvar produção em lote: $e');
      rethrow;
    }
  }

  /// Salva informações do operador
  static Future<void> saveOperador({
    required String operadorId,
    required String nome,
    required String numero,
  }) async {
    try {
      final operadorData = {
        'nome': nome,
        'numero': numero,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(_operadoresCollection)
          .doc(operadorId)
          .set(operadorData, SetOptions(merge: true));

      print('Operador salvo: $nome (ID: $operadorId)');
    } catch (e) {
      print('Erro ao salvar operador: $e');
      rethrow;
    }
  }

  /// Carrega configuração dos turnos
  static Future<Map<String, dynamic>?> loadTurnosConfig() async {
    try {
      final doc = await _firestore
          .collection(_turnosCollection)
          .doc('config')
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Erro ao carregar configuração dos turnos: $e');
      return null;
    }
  }

  /// Carrega dados de produção por data
  static Future<List<Map<String, dynamic>>> loadProducaoByDate(String data) async {
    try {
      final querySnapshot = await _firestore
          .collection(_producaoCollection)
          .where('data', isEqualTo: data)
          .orderBy('hora')
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Erro ao carregar produção por data: $e');
      return [];
    }
  }

  /// Carrega dados de produção por operador
  static Future<List<Map<String, dynamic>>> loadProducaoByOperador(String operadorId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_producaoCollection)
          .where('operadorId', isEqualTo: operadorId)
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Erro ao carregar produção por operador: $e');
      return [];
    }
  }

  /// Carrega dados de produção por hora
  static Future<List<Map<String, dynamic>>> loadProducaoByHora(String data, String hora) async {
    try {
      final querySnapshot = await _firestore
          .collection(_producaoCollection)
          .where('data', isEqualTo: data)
          .where('hora', isEqualTo: hora)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Erro ao carregar produção por hora: $e');
      return [];
    }
  }

  /// Obtém estatísticas de produção por dia
  static Future<Map<String, dynamic>> getProducaoStatsByDay(String data) async {
    try {
      final querySnapshot = await _firestore
          .collection(_producaoCollection)
          .where('data', isEqualTo: data)
          .get();

      int totalPecas = 0;
      Map<String, int> producaoPorHora = {};
      Map<String, int> producaoPorOperador = {};

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final quantidade = data['quantidade'] as int? ?? 0;
        final hora = data['hora'] as String? ?? '';
        final operadorId = data['operadorId'] as String? ?? '';

        totalPecas += quantidade;
        
        producaoPorHora[hora] = (producaoPorHora[hora] ?? 0) + quantidade;
        producaoPorOperador[operadorId] = (producaoPorOperador[operadorId] ?? 0) + quantidade;
      }

      return {
        'totalPecas': totalPecas,
        'producaoPorHora': producaoPorHora,
        'producaoPorOperador': producaoPorOperador,
        'totalRegistros': querySnapshot.docs.length,
      };
    } catch (e) {
      print('Erro ao obter estatísticas de produção: $e');
      return {
        'totalPecas': 0,
        'producaoPorHora': {},
        'producaoPorOperador': {},
        'totalRegistros': 0,
      };
    }
  }

  /// Obtém o ID do operador atual (salvo localmente)
  static Future<String> getCurrentOperadorId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_operador_id') ?? 'operador_001';
  }

  /// Salva o ID do operador atual
  static Future<void> setCurrentOperadorId(String operadorId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_operador_id', operadorId);
  }

  /// Gera ID único para operador
  static String generateOperadorId() {
    return 'operador_${DateTime.now().millisecondsSinceEpoch}';
  }
}

