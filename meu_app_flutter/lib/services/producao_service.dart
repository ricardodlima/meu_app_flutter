import 'package:cloud_firestore/cloud_firestore.dart';

/// Serviço responsável por toda a comunicação com o Firestore
/// para o controle de produção (lotes e estado global).
class ProducaoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Cria um novo lote de produção na coleção 'lotesDeProducao'.
  /// Retorna o ID do documento criado.
  Future<String> criarNovoLote() async {
    final doc = await _db.collection('lotesDeProducao').add({
      'status': 'Em Andamento',
      'inicioTimestamp': FieldValue.serverTimestamp(),
      'fimTimestamp': null,
      'contagemFinal': 0,
    });
    return doc.id;
  }

  /// Finaliza um lote de produção existente, atualizando seu status,
  /// timestamp de fim e contagem final.
  Future<void> finalizarLote(String loteId, int contagemFinal) async {
    await _db.collection('lotesDeProducao').doc(loteId).update({
      'status': 'Finalizado',
      'fimTimestamp': FieldValue.serverTimestamp(),
      'contagemFinal': contagemFinal,
    });
  }

  /// Atualiza o estado global do contador no documento 'ihmPrincipal'
  /// dentro da coleção 'estadoGlobal'.
  /// Usa merge para não sobrescrever outros campos.
  Future<void> atualizarEstadoGlobal(int contadorAtual, String? loteAtualId) async {
    await _db.collection('estadoGlobal').doc('ihmPrincipal').set({
      'contadorAtual': contadorAtual,
      'loteAtualId': loteAtualId,
    }, SetOptions(merge: true));
  }
} 