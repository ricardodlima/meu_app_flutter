import 'package:cloud_firestore/cloud_firestore.dart';
import 'database_service.dart';

class DashboardService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Obtém estatísticas gerais de produção
  static Future<Map<String, dynamic>> getDashboardStats({
    String? dataInicio,
    String? dataFim,
    String? operadorId,
  }) async {
    try {
      Query query = _firestore.collection('producao');
      
      // Filtros opcionais
      if (dataInicio != null) {
        query = query.where('data', isGreaterThanOrEqualTo: dataInicio);
      }
      if (dataFim != null) {
        query = query.where('data', isLessThanOrEqualTo: dataFim);
      }
      if (operadorId != null) {
        query = query.where('operadorId', isEqualTo: operadorId);
      }

      final querySnapshot = await query.get();
      
      // Processa os dados
      Map<String, int> producaoPorDia = {};
      Map<String, int> producaoPorHora = {};
      Map<String, int> producaoPorOperador = {};
      int totalPecas = 0;
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final quantidade = data['quantidade'] as int? ?? 0;
        final dataProducao = data['data'] as String? ?? '';
        final hora = data['hora'] as String? ?? '';
        final operador = data['operadorId'] as String? ?? '';
        
        totalPecas += quantidade;
        
        // Produção por dia
        producaoPorDia[dataProducao] = (producaoPorDia[dataProducao] ?? 0) + quantidade;
        
        // Produção por hora (média de todos os dias)
        producaoPorHora[hora] = (producaoPorHora[hora] ?? 0) + quantidade;
        
        // Produção por operador
        producaoPorOperador[operador] = (producaoPorOperador[operador] ?? 0) + quantidade;
      }

      return {
        'totalPecas': totalPecas,
        'totalRegistros': querySnapshot.docs.length,
        'producaoPorDia': producaoPorDia,
        'producaoPorHora': producaoPorHora,
        'producaoPorOperador': producaoPorOperador,
        'periodo': {
          'inicio': dataInicio,
          'fim': dataFim,
        },
      };
    } catch (e) {
      print('Erro ao obter estatísticas do dashboard: $e');
      return {
        'totalPecas': 0,
        'totalRegistros': 0,
        'producaoPorDia': {},
        'producaoPorHora': {},
        'producaoPorOperador': {},
        'periodo': {
          'inicio': dataInicio,
          'fim': dataFim,
        },
      };
    }
  }

  /// Obtém dados para gráfico de produção por hora
  static Future<List<Map<String, dynamic>>> getProducaoPorHoraChart({
    String? data,
    String? operadorId,
  }) async {
    try {
      Query query = _firestore.collection('producao');
      
      if (data != null) {
        query = query.where('data', isEqualTo: data);
      }
      if (operadorId != null) {
        query = query.where('operadorId', isEqualTo: operadorId);
      }

      final querySnapshot = await query.get();
      
      // Agrupa por hora
      Map<String, int> producaoPorHora = {};
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final quantidade = data['quantidade'] as int? ?? 0;
        final hora = data['hora'] as String? ?? '';
        
        producaoPorHora[hora] = (producaoPorHora[hora] ?? 0) + quantidade;
      }

      // Converte para lista ordenada
      List<Map<String, dynamic>> chartData = [];
      producaoPorHora.forEach((hora, quantidade) {
        chartData.add({
          'hora': hora,
          'quantidade': quantidade,
        });
      });

      // Ordena por hora
      chartData.sort((a, b) => a['hora'].compareTo(b['hora']));

      return chartData;
    } catch (e) {
      print('Erro ao obter dados do gráfico por hora: $e');
      return [];
    }
  }

  /// Obtém dados para gráfico de produção por operador
  static Future<List<Map<String, dynamic>>> getProducaoPorOperadorChart({
    String? dataInicio,
    String? dataFim,
  }) async {
    try {
      Query query = _firestore.collection('producao');
      
      if (dataInicio != null) {
        query = query.where('data', isGreaterThanOrEqualTo: dataInicio);
      }
      if (dataFim != null) {
        query = query.where('data', isLessThanOrEqualTo: dataFim);
      }

      final querySnapshot = await query.get();
      
      // Agrupa por operador
      Map<String, int> producaoPorOperador = {};
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final quantidade = data['quantidade'] as int? ?? 0;
        final operador = data['operadorId'] as String? ?? '';
        
        producaoPorOperador[operador] = (producaoPorOperador[operador] ?? 0) + quantidade;
      }

      // Converte para lista
      List<Map<String, dynamic>> chartData = [];
      producaoPorOperador.forEach((operador, quantidade) {
        chartData.add({
          'operador': operador,
          'quantidade': quantidade,
        });
      });

      // Ordena por quantidade (maior primeiro)
      chartData.sort((a, b) => b['quantidade'].compareTo(a['quantidade']));

      return chartData;
    } catch (e) {
      print('Erro ao obter dados do gráfico por operador: $e');
      return [];
    }
  }

  /// Obtém dados para gráfico de produção por dia
  static Future<List<Map<String, dynamic>>> getProducaoPorDiaChart({
    String? dataInicio,
    String? dataFim,
    String? operadorId,
  }) async {
    try {
      Query query = _firestore.collection('producao');
      
      if (dataInicio != null) {
        query = query.where('data', isGreaterThanOrEqualTo: dataInicio);
      }
      if (dataFim != null) {
        query = query.where('data', isLessThanOrEqualTo: dataFim);
      }
      if (operadorId != null) {
        query = query.where('operadorId', isEqualTo: operadorId);
      }

      final querySnapshot = await query.get();
      
      // Agrupa por dia
      Map<String, int> producaoPorDia = {};
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final quantidade = data['quantidade'] as int? ?? 0;
        final dataProducao = data['data'] as String? ?? '';
        
        producaoPorDia[dataProducao] = (producaoPorDia[dataProducao] ?? 0) + quantidade;
      }

      // Converte para lista ordenada
      List<Map<String, dynamic>> chartData = [];
      producaoPorDia.forEach((data, quantidade) {
        chartData.add({
          'data': data,
          'quantidade': quantidade,
        });
      });

      // Ordena por data
      chartData.sort((a, b) => a['data'].compareTo(b['data']));

      return chartData;
    } catch (e) {
      print('Erro ao obter dados do gráfico por dia: $e');
      return [];
    }
  }

  /// Obtém ranking de operadores
  static Future<List<Map<String, dynamic>>> getOperadoresRanking({
    String? dataInicio,
    String? dataFim,
    int limit = 10,
  }) async {
    try {
      final chartData = await getProducaoPorOperadorChart(
        dataInicio: dataInicio,
        dataFim: dataFim,
      );

      // Limita o número de resultados
      if (chartData.length > limit) {
        chartData.removeRange(limit, chartData.length);
      }

      return chartData;
    } catch (e) {
      print('Erro ao obter ranking de operadores: $e');
      return [];
    }
  }

  /// Obtém métricas de performance
  static Future<Map<String, dynamic>> getPerformanceMetrics({
    String? dataInicio,
    String? dataFim,
  }) async {
    try {
      final stats = await getDashboardStats(
        dataInicio: dataInicio,
        dataFim: dataFim,
      );

      final totalPecas = stats['totalPecas'] as int;
      final totalRegistros = stats['totalRegistros'] as int;
      final producaoPorDia = stats['producaoPorDia'] as Map<String, int>;
      final producaoPorOperador = stats['producaoPorOperador'] as Map<String, int>;

      // Calcula métricas
      final diasComProducao = producaoPorDia.length;
      final operadoresAtivos = producaoPorOperador.length;
      final mediaPecasPorDia = diasComProducao > 0 ? totalPecas / diasComProducao : 0.0;
      final mediaPecasPorOperador = operadoresAtivos > 0 ? totalPecas / operadoresAtivos : 0.0;

      // Encontra melhor dia e melhor operador
      String melhorDia = '';
      int melhorDiaPecas = 0;
      producaoPorDia.forEach((dia, pecas) {
        if (pecas > melhorDiaPecas) {
          melhorDia = dia;
          melhorDiaPecas = pecas;
        }
      });

      String melhorOperador = '';
      int melhorOperadorPecas = 0;
      producaoPorOperador.forEach((operador, pecas) {
        if (pecas > melhorOperadorPecas) {
          melhorOperador = operador;
          melhorOperadorPecas = pecas;
        }
      });

      return {
        'totalPecas': totalPecas,
        'totalRegistros': totalRegistros,
        'diasComProducao': diasComProducao,
        'operadoresAtivos': operadoresAtivos,
        'mediaPecasPorDia': mediaPecasPorDia,
        'mediaPecasPorOperador': mediaPecasPorOperador,
        'melhorDia': {
          'data': melhorDia,
          'pecas': melhorDiaPecas,
        },
        'melhorOperador': {
          'id': melhorOperador,
          'pecas': melhorOperadorPecas,
        },
      };
    } catch (e) {
      print('Erro ao obter métricas de performance: $e');
      return {
        'totalPecas': 0,
        'totalRegistros': 0,
        'diasComProducao': 0,
        'operadoresAtivos': 0,
        'mediaPecasPorDia': 0.0,
        'mediaPecasPorOperador': 0.0,
        'melhorDia': {'data': '', 'pecas': 0},
        'melhorOperador': {'id': '', 'pecas': 0},
      };
    }
  }
}

