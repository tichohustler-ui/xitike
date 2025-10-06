import 'package:flutter/material.dart';


// Modelo de Grupo
class Grupo {
  final String nome;
  final int limiteDoadores;

  Grupo(this.nome, {this.limiteDoadores = 10});
}

// Estado de cada grupo (exemplo básico)
class GroupState {
  final Grupo grupo;
  int doadores = 0;

  GroupState({required this.grupo});
}

// Página Xitike
class XitikePage extends StatefulWidget {
  final List<Grupo> grupos;

  const XitikePage({Key? key, required this.grupos}) : super(key: key);

  @override
  State<XitikePage> createState() => _XitikePageState();
}

class _XitikePageState extends State<XitikePage> {
  late Map<String, GroupState> states;
  bool isFundadorRei = true;
  String? groupFromLink;
  bool firstInvestmentDoneInLinkedGroup = false;
 // ignore: unused_field
String _fundadorRecrutador = 'R';
  double userSaldo = 0.0;

  @override
  void initState() {
    super.initState();
    // Inicializa o estado de cada grupo
    states = {for (var g in widget.grupos) g.nome: GroupState(grupo: g)};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('XITIKE'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: widget.grupos
            .map((g) => ListTile(
                  title: Text(g.nome),
                  subtitle: Text(
                      'Limite de doadores: ${g.limiteDoadores}, Doadores atuais: ${states[g.nome]?.doadores ?? 0}'),
                ))
            .toList(),
      ),
    );
  }
}

// App principal
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XITIKE Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      home: XitikePage(
        grupos: [
          Grupo('Grupo A'),
          Grupo('Grupo B'),
          Grupo('Grupo C'),
          Grupo('Grupo D'),
        ],
      ),
    );
  }
}
