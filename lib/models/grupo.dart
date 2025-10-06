import 'package:flutter/foundation.dart';

@immutable
class Grupo {
  final String nome;
  final double valor;
  final int limiteDoadores;
  final int maxInvestimentos;
  final double percentualBonusBase;

  const Grupo({
    required this.nome,
    required this.valor,
    required this.limiteDoadores,
    required this.maxInvestimentos,
    required this.percentualBonusBase,
  });
}
