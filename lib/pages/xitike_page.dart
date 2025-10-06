import 'package:flutter/material.dart';
import '../models/grupo.dart';

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

  @override
  void initState() {
    super.initState();
    states = {for (var g in widget.grupos) g.nome: GroupState(grupo: g)};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Xitike Groups")),
      body: ListView(
        children: widget.grupos.map((g) {
          return ListTile(
            title: Text(g.nome),
            subtitle: Text("Limite: ${g.limiteDoadores}"),
          );
        }).toList(),
      ),
    );
  }
}

/// Modelo simples de estado do grupo
class GroupState {
  final Grupo grupo;
  GroupState({required this.grupo});
}
