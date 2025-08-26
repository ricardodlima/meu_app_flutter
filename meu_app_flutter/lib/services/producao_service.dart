import 'package:cloud_firestore/cloud_firestore.dart';

/// Serviço responsável por toda a comunicação com o Firestore
/// para o controle do estado global de produção.
class ProducaoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Atualiza o estado global do contador no documento 'ihmPrincipal'
  /// dentro da coleção 'estadoGlobal'.
  /// Usa merge para não sobrescrever outros campos.
  Future<void> atualizarEstadoGlobal(int contadorAtual) async {
    await _db.collection('estadoGlobal').doc('ihmPrincipal').set({
      'contadorAtual': contadorAtual,
    }, SetOptions(merge: true));
  }
} 