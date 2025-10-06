import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:teste_app/utils/logger.dart';
import 'package:flutter/services.dart'; // ← ADICIONE ESTA LINHA

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// -------------------- MODELS --------------------
class UserLocal {
  final String nomeCompleto;
  final String nomeUsuario;
  final String? email;
  final String telefone;
  final String senha;

  const UserLocal({
    required this.nomeCompleto,
    required this.nomeUsuario,
    this.email,
    required this.telefone,
    required this.senha,
  });
}

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

class FounderNode {
  final String id;
  final String name;
  final double balance;
  final double bonusAcumulado;
  final double bonusRede;
  final double totalInvestido;
  final List<Map<String, dynamic>> donors;
  final String? uplineId;

  FounderNode({
    required this.id,
    required this.name,
    this.balance = 0.0,
    this.bonusAcumulado = 0.0,
    this.bonusRede = 0.0,
    this.totalInvestido = 0.0,
    List<Map<String, dynamic>>? donors,
    this.uplineId,
  }) : donors = donors ?? [];

  FounderNode copyWith({
    double? balance,
    double? bonusAcumulado,
    double? bonusRede,
    double? totalInvestido,
    List<Map<String, dynamic>>? donors,
    String? uplineId,
  }) {
    return FounderNode(
      id: id,
      name: name,
      balance: balance ?? this.balance,
      bonusAcumulado: bonusAcumulado ?? this.bonusAcumulado,
      bonusRede: bonusRede ?? this.bonusRede,
      totalInvestido: totalInvestido ?? this.totalInvestido,
      donors: donors ?? this.donors,
      uplineId: uplineId ?? this.uplineId,
    );
  }
}

class GroupState {
  final Grupo grupo;
  final List<FounderNode> founders;
  final int investmentsCount;
  final int donorsPending;

  GroupState({required this.grupo})
      : founders = [
          FounderNode(id: 'R', name: 'Ticho', uplineId: null),
          FounderNode(id: 'F1', name: 'Fundador 1', uplineId: 'R'),
          FounderNode(id: 'F2', name: 'Fundador 2', uplineId: 'F1'),
          FounderNode(id: 'F3', name: 'Fundador 3', uplineId: 'F2'),
        ],
        investmentsCount = 0,
        donorsPending = 0;

  GroupState._({
    required this.grupo,
    required this.founders,
    required this.investmentsCount,
    required this.donorsPending,
  });

  GroupState copyWith({
    List<FounderNode>? founders,
    int? investmentsCount,
    int? donorsPending,
  }) {
    return GroupState._(
      grupo: grupo,
      founders: founders ?? this.founders,
      investmentsCount: investmentsCount ?? this.investmentsCount,
      donorsPending: donorsPending ?? this.donorsPending,
    );
  }

  bool get atingiuLimiteInvestimentos =>
      investmentsCount >= grupo.maxInvestimentos;
}

// ---------------------- MODELS DE PAGAMENTO ----------------------
class Payment {
  final String phoneNumber;
  final double amount;

  Payment({required this.phoneNumber, required this.amount});
}

// ---------------------- REPOSITORY SIMULADO ----------------------
class PaymentRepository {
  // Função simulada de pagamento
  Future<Map<String, dynamic>> initiatePayment(Payment payment) async {
    await Future.delayed(const Duration(seconds: 2)); // simula delay
    return {'success': true, 'message': 'Pagamento simulado com sucesso'};
  }
}

// ---------------------- USE CASE ----------------------
class ProcessPaymentUseCase {
  final PaymentRepository repository;

  ProcessPaymentUseCase(this.repository);

  Future<Map<String, dynamic>> execute({
    required String phoneNumber,
    required String amountString,
  }) async {
    if (phoneNumber.isEmpty || amountString.isEmpty) {
      return {'success': false, 'message': 'Telefone e valor são obrigatórios'};
    }

    // REMOVI a validação de 9 dígitos - agora aceita qualquer número completo
    if (!RegExp(r'^[0-9]+$').hasMatch(phoneNumber)) {
      return {'success': false, 'message': 'Número de telefone inválido'};
    }

    double? amount = double.tryParse(amountString);
    if (amount == null || amount <= 0) {
      return {
        'success': false,
        'message': 'Digite um valor válido maior que 0'
      };
    }

    final payment = Payment(phoneNumber: phoneNumber, amount: amount);
    return await repository.initiatePayment(payment);
  }
}

// --- CONTROLADOR SIMPLES ---
class UserAccount with ChangeNotifier {
  double _adminBalance = 0.0;
  double _bonusRedeAdmin = 0.0;

  double get adminBalance => _adminBalance;
  double get bonusRedeAdmin => _bonusRedeAdmin;

  void addToBalance(double valor) {
    _adminBalance += valor;
    notifyListeners();
  }

  void addBonusRede(double valor) {
    _bonusRedeAdmin += valor;
    notifyListeners();
  }

  void sacarBonusRedeAdmin() {
    _adminBalance += _bonusRedeAdmin;
    _bonusRedeAdmin = 0.0;
    notifyListeners();
  }
}

// --- SISTEMA HIERÁRQUICO E DISTRIBUIÇÃO ---
class SistemaHierarquico {
  static Map<String, double> calcularDistribuicaoHierarquica({
    required Grupo grupo,
    required List<FounderNode> founders,
    required String fundadorRecrutadorId,
    required UserAccount admin,
  }) {
    final distribuicao = <String, double>{};
    final valor = grupo.valor;
    final base = grupo.percentualBonusBase.clamp(0.0, 1.0);
    final baseValor = valor * base;

    distribuicao[fundadorRecrutadorId] = baseValor;
    double restante = valor - baseValor;

    final recrutador = founders.firstWhere(
      (f) => f.id == fundadorRecrutadorId,
      orElse: () => FounderNode(id: '', name: ''),
    );

    String? currentUplineId = recrutador.uplineId;

    if (currentUplineId != null && restante > 0) {
      final upline1Valor = restante * 0.10;
      distribuicao[currentUplineId] =
          (distribuicao[currentUplineId] ?? 0.0) + upline1Valor;
      restante -= upline1Valor;

      List<double> percentSeq = [0.08, 0.05, 0.04, 0.03, 0.02, 0.01];
      var nivel = 0;

      while (currentUplineId != null && restante > 0) {
        final currentFounder = founders.firstWhere(
          (f) => f.id == currentUplineId,
          orElse: () => FounderNode(id: '', name: ''),
        );

        currentUplineId = currentFounder.uplineId;
        if (currentUplineId == null) break;

        final pct =
            (nivel < percentSeq.length) ? percentSeq[nivel] : percentSeq.last;
        final valorRede = restante * pct;

        if (currentUplineId == 'R') {
          admin.addBonusRede(valorRede);
          distribuicao['bonus_rede_admin'] =
              (distribuicao['bonus_rede_admin'] ?? 0.0) + valorRede;
        } else {
          distribuicao['rede_$currentUplineId'] =
              (distribuicao['rede_$currentUplineId'] ?? 0.0) + valorRede;
        }

        restante -= valorRede;
        nivel++;
      }
    }

    if (restante > 0) {
      admin.addToBalance(restante);
      distribuicao['admin_restante'] =
          (distribuicao['admin_restante'] ?? 0.0) + restante;
    }

    return distribuicao;
  }
}

// --- SERVIÇOS DE INVESTIMENTO ---
class InvestmentService {
  static GroupState processInvestmentRei({
    required Grupo grupo,
    required GroupState groupState,
    required UserAccount admin,
  }) {
    if (groupState.atingiuLimiteInvestimentos) return groupState;

    admin.addToBalance(grupo.valor);
    final founder = groupState.founders[0];
    final updatedFounder =
        founder.copyWith(totalInvestido: founder.totalInvestido + grupo.valor);

    final updatedFounders = groupState.founders.map((f) {
      if (f.id == founder.id) return updatedFounder;
      return f;
    }).toList();

    return groupState.copyWith(
      founders: updatedFounders,
      investmentsCount: groupState.investmentsCount + 1,
      donorsPending: groupState.donorsPending + grupo.limiteDoadores,
    );
  }

  static GroupState processInvestmentViaLink({
    required Grupo grupo,
    required GroupState groupState,
    required UserAccount admin,
    required String fundadorRecrutadorId,
  }) {
    if (groupState.atingiuLimiteInvestimentos) return groupState;

    final distribuicao = SistemaHierarquico.calcularDistribuicaoHierarquica(
      grupo: grupo,
      founders: groupState.founders,
      fundadorRecrutadorId: fundadorRecrutadorId,
      admin: admin,
    );

    final atualizadoFundadores = groupState.founders.map((f) {
      final bonusAcumuladoAdd = distribuicao[f.id] ?? 0.0;
      final bonusRedeAdd = distribuicao['rede_${f.id}'] ?? 0.0;

      if (bonusAcumuladoAdd > 0 || bonusRedeAdd > 0) {
        return f.copyWith(
          bonusAcumulado: f.bonusAcumulado + bonusAcumuladoAdd,
          bonusRede: f.bonusRede + bonusRedeAdd,
        );
      }
      return f;
    }).toList();

    final fundador = atualizadoFundadores[0];
    final newFounder = fundador.copyWith(
        totalInvestido: fundador.totalInvestido + grupo.valor);
    atualizadoFundadores[0] = newFounder;

    return groupState.copyWith(
      founders: atualizadoFundadores,
      investmentsCount: groupState.investmentsCount + 1,
      donorsPending: groupState.donorsPending + grupo.limiteDoadores,
    );
  }

  static GroupState addDonor({
    required Grupo grupo,
    required GroupState groupState,
    required UserAccount admin,
    required String fundadorRecrutadorId,
  }) {
    if (groupState.donorsPending <= 0) return groupState;

    final founderIndex =
        groupState.founders.indexWhere((f) => f.id == fundadorRecrutadorId);
    if (founderIndex == -1) return groupState;

    final founder = groupState.founders[founderIndex];
    final newDonors = List<Map<String, dynamic>>.from(founder.donors);
    final idx = founder.donors.length + 1;
    newDonors.add({'nome': 'Doador $idx', 'data': DateTime.now()});

    final distribuicao = SistemaHierarquico.calcularDistribuicaoHierarquica(
      grupo: grupo,
      founders: groupState.founders,
      fundadorRecrutadorId: fundadorRecrutadorId,
      admin: admin,
    );

    final atualizadoFundadores = groupState.founders.map((f) {
      final bonusAcumuladoAdd = distribuicao[f.id] ?? 0.0;
      final bonusRedeAdd = distribuicao['rede_${f.id}'] ?? 0.0;

      if (bonusAcumuladoAdd > 0 || bonusRedeAdd > 0) {
        return f.copyWith(
          bonusAcumulado: f.bonusAcumulado + bonusAcumuladoAdd,
          bonusRede: f.bonusRede + bonusRedeAdd,
          donors: f.id == fundadorRecrutadorId ? newDonors : f.donors,
        );
      }
      return f.id == fundadorRecrutadorId ? f.copyWith(donors: newDonors) : f;
    }).toList();

    return groupState.copyWith(
      founders: atualizadoFundadores,
      donorsPending: groupState.donorsPending - 1,
    );
  }

  static GroupState withdrawBonus({
    required Grupo grupo,
    required GroupState groupState,
  }) {
    final founder = groupState.founders[0];
    final limite = grupo.limiteDoadores;

    if (founder.donors.length < limite) return groupState;

    final valorCicloCompleto = limite * grupo.valor * grupo.percentualBonusBase;
    if (founder.bonusAcumulado < valorCicloCompleto) return groupState;

    final newBalance = founder.balance + valorCicloCompleto;
    final newBonus = founder.bonusAcumulado - valorCicloCompleto;
    final newDonors = List<Map<String, dynamic>>.from(founder.donors);
    newDonors.removeRange(0, limite);

    final updatedFounder = founder.copyWith(
      balance: newBalance,
      bonusAcumulado: newBonus,
      donors: newDonors,
    );

    final updatedFounders = groupState.founders.map((f) {
      if (f.id == founder.id) return updatedFounder;
      return f;
    }).toList();

    return groupState.copyWith(founders: updatedFounders);
  }
}

// ---------------------- PROVIDER ----------------------
class PaymentProvider extends ChangeNotifier {
  final ProcessPaymentUseCase useCase;

  PaymentProvider(this.useCase);

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void resetState() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  Future<void> processPayment({
    required String phoneNumber,
    required String amount,
  }) async {
    resetState();
    _isLoading = true;
    notifyListeners();

    final result =
        await useCase.execute(phoneNumber: phoneNumber, amountString: amount);

    _isLoading = false;

    if (result['success'] == true) {
      _successMessage = result['message'];
    } else {
      _errorMessage = result['message'];
    }
    notifyListeners();
  }
}

// -------------------- APP ROOT --------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> _termoLido() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('termo_lido') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final repository = PaymentRepository();
    final useCase = ProcessPaymentUseCase(repository);

    final grupos = [
      const Grupo(
        nome: 'Curioso',
        valor: 50,
        limiteDoadores: 10,
        maxInvestimentos: 10,
        percentualBonusBase: 0.40,
      ),
      const Grupo(
        nome: 'Focado',
        valor: 100,
        limiteDoadores: 6,
        maxInvestimentos: 20,
        percentualBonusBase: 0.50,
      ),
      const Grupo(
        nome: 'Determinado',
        valor: 500,
        limiteDoadores: 4,
        maxInvestimentos: 50,
        percentualBonusBase: 0.60,
      ),
      const Grupo(
        nome: 'Visionário',
        valor: 1000,
        limiteDoadores: 2,
        maxInvestimentos: 100,
        percentualBonusBase: 0.80,
      ),
    ];

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserAccount()),
        ChangeNotifierProvider(create: (_) => PaymentProvider(useCase)),
      ],
      child: MaterialApp(
        title: 'XITIKE',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        home: FutureBuilder<bool>(
          future: _termoLido(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snap.data == true) {
              return XitikePage(grupos: grupos);
            }

            return const LoginPage();
          },
        ),
      ),
    );
  }
}

// -------------------- TELA DE LOGIN (BOAS-VINDAS) --------------------
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet,
                  size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                'XITIKE',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sistema de Investimento em Rede',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              _buildLoginButton(
                icon: Icons.person,
                text: 'Entrar como Usuário',
                color: Colors.blue,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PossuiCadastroPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton({
    required IconData icon,
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(text, style: const TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// -------------------- POSSUI CADASTRO PAGE --------------------
class PossuiCadastroPage extends StatelessWidget {
  const PossuiCadastroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_add, size: 60, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              'Você já possui cadastro?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginFormPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'SIM, quero entrar na minha conta',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CadastroPage(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Colors.blue),
                ),
                child: const Text(
                  'NÃO, quero me cadastrar',
                  style: TextStyle(fontSize: 16, color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------- LOGIN FORM PAGE --------------------
class LoginFormPage extends StatefulWidget {
  const LoginFormPage({super.key});

  @override
  State<LoginFormPage> createState() => _LoginFormPageState();
}

class _LoginFormPageState extends State<LoginFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _senhaController = TextEditingController();
  String _tipoLogin = 'telefone';
  bool _isLoading = false;

  Future<bool> _termoLido() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('termo_lido') ?? false;
  }

  @override
  void dispose() {
    _idController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _entrarSimulado() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    setState(() => _isLoading = false);

    final termo = await _termoLido();
    if (termo) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (_) => XitikePage(grupos: const [
  Grupo(
    nome: 'Curioso',
    valor: 50,
    limiteDoadores: 10,
    maxInvestimentos: 10,
    percentualBonusBase: 0.40,
  ),
  Grupo(
    nome: 'Focado',
    valor: 100,
    limiteDoadores: 6,
    maxInvestimentos: 20,
    percentualBonusBase: 0.50,
  ),
  Grupo(
    nome: 'Determinado',
    valor: 500,
    limiteDoadores: 4,
    maxInvestimentos: 50,
    percentualBonusBase: 0.60,
  ),
  Grupo(
    nome: 'Visionário',
    valor: 1000,
    limiteDoadores: 2,
    maxInvestimentos: 100,
    percentualBonusBase: 0.80,
  ),
])),

        (_) => false,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const TermoResponsabilidadePage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _tipoLogin == 'telefone'
        ? 'Número de Telefone'
        : _tipoLogin == 'usuario'
            ? 'Nome de Usuário'
            : 'Email';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrar na Conta'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Text(
                      'Faça login na sua conta',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'telefone',
                          label: Text('Telefone'),
                          icon: Icon(Icons.phone),
                        ),
                        ButtonSegment(
                          value: 'usuario',
                          label: Text('Usuário'),
                          icon: Icon(Icons.person),
                        ),
                        ButtonSegment(
                          value: 'email',
                          label: Text('Email'),
                          icon: Icon(Icons.email),
                        ),
                      ],
                      selected: {_tipoLogin},
                      onSelectionChanged: (set) => setState(() {
                        _tipoLogin = set.first;
                        _idController.clear();
                      }),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _idController,
                      decoration: InputDecoration(
                        labelText: label,
                        prefixText: _tipoLogin == 'telefone' ? '+258 ' : null,
                        border: const OutlineInputBorder(),
                        fillColor: Colors.grey[100],
                        filled: true,
                      ),
                      keyboardType: _tipoLogin == 'telefone'
                          ? TextInputType.phone
                          : _tipoLogin == 'email'
                              ? TextInputType.emailAddress
                              : TextInputType.text,
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Por favor, preencha este campo'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _senhaController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Senha',
                        border: OutlineInputBorder(),
                        fillColor: Color(0xFFF5F5F5),
                        filled: true,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty)  { 
                          return 'Digite sua senha';
                        }
                        if (v.length < 6) {
                          return 'A senha deve ter pelo menos 6 caracteres';
                          }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _entrarSimulado,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Colors.blue[700],
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                'ENTRAR',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Ou entre com:',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _entrarSimulado,
                            icon: const Icon(Icons.g_translate,
                                color: Colors.red),
                            label: const Text('Google'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _entrarSimulado,
                            icon:
                                const Icon(Icons.facebook, color: Colors.blue),
                            label: const Text('Facebook'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// -------------------- CADASTRO PAGE --------------------
class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _usuarioController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _usuarioController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  void _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    setState(() => _isLoading = false);

    // Criar usuário
    final user = UserLocal(
      nomeCompleto: _nomeController.text,
      nomeUsuario: _usuarioController.text,
      email: _emailController.text.isNotEmpty ? _emailController.text : null,
      telefone: _telefoneController.text,
      senha: _senhaController.text,
    );

    logger.i('✅ Usuário cadastrado: ${user.nomeCompleto}');

    // Vai para termo
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const TermoResponsabilidadePage(),
      ),
    );
  }

  bool _validarNomeCompleto(String nome) => nome.trim().split(' ').length >= 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Cadastro'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Icon(Icons.person_add, size: 60, color: Colors.blue),
                    const SizedBox(height: 16),
                    const Text(
                      'Crie sua conta',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome Completo *',
                        hintText: 'Ex: Maria Silva',
                        border: OutlineInputBorder(),
                        fillColor: Color(0xFFF5F5F5),
                        filled: true,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Digite seu nome completo';
                          }
                        if (!_validarNomeCompleto(v)) {
                          return 'Digite pelo menos nome e sobrenome';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usuarioController,
                      decoration: const InputDecoration(
                        labelText: 'Nome de Usuário *',
                        hintText: 'Ex: maria123',
                        border: OutlineInputBorder(),
                        fillColor: Color(0xFFF5F5F5),
                        filled: true,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Digite um nome de usuário';
                          }
                        if (v.length < 3) {
                        return 'Mínimo 3 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email (opcional)',
                        hintText: 'Ex: maria@email.com',
                        border: OutlineInputBorder(),
                        fillColor: Color(0xFFF5F5F5),
                        filled: true,
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _telefoneController,
                      decoration: const InputDecoration(
                        labelText: 'Número de Telefone *',
                        prefixText: '+258 ',
                        hintText: '84 123 4567',
                        border: OutlineInputBorder(),
                        fillColor: Color(0xFFF5F5F5),
                        filled: true,
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Digite seu número';
                        if (v.length < 8) return 'Número inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _senhaController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Senha *',
                        border: OutlineInputBorder(),
                        fillColor: Color(0xFFF5F5F5),
                        filled: true,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Digite uma senha';
                        if (v.length < 6) return 'Mínimo 6 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmarSenhaController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar Senha *',
                        border: OutlineInputBorder(),
                        fillColor: Color(0xFFF5F5F5),
                        filled: true,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Confirme sua senha';
                        if (v != _senhaController.text) {
                          return 'As senhas não coincidem';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _cadastrar,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Colors.blue[700],
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                'CRIAR CONTA',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// -------------------- TERMO DE RESPONSABILIDADE PAGE --------------------
class TermoResponsabilidadePage extends StatefulWidget {
  const TermoResponsabilidadePage({super.key});

  @override
  State<TermoResponsabilidadePage> createState() =>
      _TermoResponsabilidadePageState();
}

class _TermoResponsabilidadePageState extends State<TermoResponsabilidadePage> {
  bool _aceitou = false;
  bool _isLoading = false;

  Future<void> _marcarTermoLido() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('termo_lido', true);
  }

  void _aceitarTermo() async {
    if (!_aceitou) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    await _marcarTermoLido();
    setState(() => _isLoading = false);

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
          builder: (_) => XitikePage(grupos: [
                const Grupo(
                  nome: 'Curioso',
                  valor: 50,
                  limiteDoadores: 10,
                  maxInvestimentos: 10,
                  percentualBonusBase: 0.40,
                ),
                const Grupo(
                  nome: 'Focado',
                  valor: 100,
                  limiteDoadores: 6,
                  maxInvestimentos: 20,
                  percentualBonusBase: 0.50,
                ),
                const Grupo(
                  nome: 'Determinado',
                  valor: 500,
                  limiteDoadores: 4,
                  maxInvestimentos: 50,
                  percentualBonusBase: 0.60,
                ),
                const Grupo(
                  nome: 'Visionário',
                  valor: 1000,
                  limiteDoadores: 2,
                  maxInvestimentos: 100,
                  percentualBonusBase: 0.80,
                ),
              ])),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Termo de Responsabilidade'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child:
                        Icon(Icons.description, size: 60, color: Colors.blue),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'TERMO DE RESPONSABILIDADE E ESCLARECIMENTO',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'IMPORTANTE: LEIA COM ATENÇÃO',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Este sistema de investimento em rede (XITIKE) funciona com base na colaboração mútua entre participantes. É fundamental entender que:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    '📌 COMO FUNCIONA:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                      '• Você faz um investimento inicial em um dos grupos disponíveis'),
                  const Text(
                      '• Para receber retorno, precisa recrutar doadores para sua rede'),
                  const Text(
                      '• O sistema distribui percentuais conforme a hierarquia estabelecida'),
                  const SizedBox(height: 10),
                  const Text(
                    '⚠️ ALERTAS IMPORTANTES:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                      '• NINGUÉM recebe dinheiro "do nada" ou sem trabalho'),
                  const Text(
                      '• O sucesso depende diretamente do seu esforço em recrutar doadores'),
                  const Text(
                      '• Você deve trabalhar ativamente para construir sua rede'),
                  const Text('• Não há garantias de retorno financeiro'),
                  const Text(
                      '• O sistema requer comprometimento e trabalho contínuo'),
                  const SizedBox(height: 10),
                  const Text(
                    '🎯 SUA RESPONSABILIDADE:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text('• Procurar ativamente por novos doadores'),
                  const Text(
                      '• Divulgar o sistema de forma ética e transparente'),
                  const Text(
                      '• Entender que os ganhos dependem do seu trabalho'),
                  const Text(
                      '• Não prometer ganhos fáceis ou garantidos a outras pessoas'),
                  const Text(
                      '• Assumir total responsabilidade pelo seu desempenho'),
                  const SizedBox(height: 15),
                  const Text(
                    '⚠️ POLÍTICA DE INATIVIDADE:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Contas inativas por período superior a 12 meses terão seus saldos zerados automaticamente',
                    style: TextStyle(fontSize: 14, color: Colors.red),
                  ),
                  const Text(
                    '• É de responsabilidade do usuário manter atividade regular no sistema',
                    style: TextStyle(fontSize: 14),
                  ),
                  const Text(
                    '• Notificações serão enviadas antes da aplicação da política de inatividade',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Ao prosseguir, você declara que:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text('• Leu e compreendeu completamente este termo'),
                  const Text(
                      '• Entende que precisa trabalhar para obter resultados'),
                  const Text('• Assume toda a responsabilidade por suas ações'),
                  const Text('• Não espera ganhos sem esforço próprio'),
                  const Text(
                      '• Concorda com a política de inatividade de 12 meses'),
                  const SizedBox(height: 25),
                  Card(
                    color: _aceitou
                        ? const Color(0xFFE8F5E8)
                        : const Color(0xFFF5F5F5),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _aceitou,
                            onChanged: (v) =>
                                setState(() => _aceitou = v ?? false),
                          ),
                          const Expanded(
                            child: Text(
                              'Li, entendi e concordo com os termos acima. Estou ciente de que preciso trabalhar ativamente para recrutar doadores e que não receberei dinheiro sem esforço.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _aceitou ? _aceitarTermo : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: _aceitou ? Colors.green : Colors.grey,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'CONCORDO E QUERO PROSSEGUIR',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// --- PÁGINA XITIKE ---
// --- PÁGINA XITIKE ---
// --- PÁGINA XITIKE ---
class XitikePage extends StatefulWidget {
  final List<Grupo> grupos;
  final UserAccount? user;

  const XitikePage({Key? key, required this.grupos, this.user}) : super(key: key);

  @override
  State<XitikePage> createState() => _XitikePageState();
}

class _XitikePageState extends State<XitikePage> {
  late Map<String, GroupState> states;
  bool isFundadorRei = true;
  String? groupFromLink;
  bool firstInvestmentDoneInLinkedGroup = false;
  String _fundadorRecrutador = 'R';
  UserAccount? _user;

  @override
  void initState() {
    super.initState();

    // CORREÇÃO: Inicializar states ANTES de qualquer uso
    states = {};
    
    // Inicializa os estados dos grupos
    for (var g in widget.grupos) {
      states[g.nome] = GroupState(grupo: g);
    }

    // Só acessa o Provider depois do build inicial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _user = Provider.of<UserAccount>(context, listen: false);
      _user?.addListener(_updateUI);
    });
  }

  @override
  void dispose() {
    _user?.removeListener(_updateUI);
    super.dispose();
  }

  void _updateUI() => setState(() {});

  bool _grupoHabilitadoParaInvestir(Grupo g) {
    if (groupFromLink == null) return true;
    if (!firstInvestmentDoneInLinkedGroup) return g.nome == groupFromLink;
    return true;
  }

  // ------------------ POPUPS COM INTEGRAÇÃO DE PAGAMENTO ------------------
  void showInvestPopup(Grupo grupo) {
    // Números fixos para depósito (não aparecem para o usuário)
    final numeroEmola = '258879494890'; // Número fixo para Emola
    final numeroMpesa = '258844451349'; // Número fixo para M-Pesa

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Investir no ${grupo.nome}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Valor: ${grupo.valor.toInt()} MT',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Escolha o método de pagamento:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Botão Emola
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _mostrarPopupPin(grupo, 'Emola', numeroEmola, 6);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.account_balance_wallet, size: 24),
                      SizedBox(height: 5),
                      Text('Emola'),
                    ],
                  ),
                ),
                // Botão M-Pesa
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _mostrarPopupPin(grupo, 'M-Pesa', numeroMpesa, 4);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.phone_iphone, size: 24),
                      SizedBox(height: 5),
                      Text('M-Pesa'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarPopupPin(
      Grupo grupo, String operadora, String numero, int digitosPin) {
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Consumer<PaymentProvider>(
        builder: (context, paymentProvider, child) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (paymentProvider.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(paymentProvider.errorMessage!),
                  backgroundColor: Colors.red,
                ),
              );
              paymentProvider.resetState();
            }
            if (paymentProvider.successMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(paymentProvider.successMessage!),
                  backgroundColor: Colors.green,
                ),
              );
              paymentProvider.resetState();
              Navigator.of(context).pop();
              _investir(grupo);
            }
          });

          return AlertDialog(
            title: Text(
              'Investir no ${grupo.nome}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      operadora == 'Emola'
                          ? Icons.account_balance_wallet
                          : Icons.phone_iphone,
                      color:
                          operadora == 'Emola' ? Colors.orange : Colors.green,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      operadora,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color:
                            operadora == 'Emola' ? Colors.orange : Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Valor: ${grupo.valor.toInt()} MT',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: digitosPin,
                  decoration: InputDecoration(
                    labelText: 'Insira PIN ($digitosPin dígitos)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                if (paymentProvider.isLoading)
                  const CircularProgressIndicator()
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (pinController.text.length == digitosPin) {
                          paymentProvider.processPayment(
                            phoneNumber: numero,
                            amount: grupo.valor.toStringAsFixed(0),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('PIN deve ter $digitosPin dígitos'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            operadora == 'Emola' ? Colors.orange : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text('Confirmar Investimento'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void showWithdrawPopup(Grupo grupo) {
    final phoneController = TextEditingController();
    final valorCicloCompleto =
        grupo.limiteDoadores * grupo.valor * grupo.percentualBonusBase;
    final amountController =
        TextEditingController(text: valorCicloCompleto.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Consumer<PaymentProvider>(
            builder: (context, paymentProvider, child) {
              // Função para verificar se o número é válido e determinar operadora
              void atualizarBotoes() {
                setState(() {});
              }

              // Verificar operadora baseada nos primeiros dígitos
              String? getOperadora(String numero) {
                if (numero.isEmpty) return null;
                if (numero.startsWith('84') || numero.startsWith('85')) {
                  return 'mpesa';
                } else if (numero.startsWith('86') || numero.startsWith('87')) {
                  return 'emola';
                }
                return null;
              }

              // Obter cor baseada na operadora
              Color getCorOperadora(String? operadora) {
                if (operadora == 'mpesa') return Colors.green;
                if (operadora == 'emola') return Colors.orange;
                return Colors.grey;
              }

              // Obter ícone baseado na operadora
              IconData getIconOperadora(String? operadora) {
                if (operadora == 'mpesa') return Icons.phone_iphone;
                if (operadora == 'emola') return Icons.account_balance_wallet;
                return Icons.error;
              }

              // Obter texto baseado na operadora
              String getTextoOperadora(String? operadora) {
                if (operadora == 'mpesa') return 'M-Pesa';
                if (operadora == 'emola') return 'Emola';
                return 'Inválido';
              }

              final numero = phoneController.text;
              final operadora = getOperadora(numero);
              final numeroValido = operadora != null && numero.length >= 9;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (paymentProvider.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(paymentProvider.errorMessage!),
                      backgroundColor: Colors.red,
                    ),
                  );
                  paymentProvider.resetState();
                }
                if (paymentProvider.successMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(paymentProvider.successMessage!),
                      backgroundColor: Colors.green,
                    ),
                  );
                  paymentProvider.resetState();
                  Navigator.of(context).pop();
                  _sacarBonus(grupo);
                }
              });

              return AlertDialog(
                title: Text('Sacar Bônus ${grupo.nome}'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Valor a sacar: ${valorCicloCompleto.toStringAsFixed(2)} MT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Número de telefone (9 dígitos)',
                        hintText: '84XXXXXXX ou 86XXXXXXX',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                        prefixText: '+258 ',
                      ),
                      onChanged: (value) => atualizarBotoes(),
                      maxLength: 9,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      operadora != null
                          ? 'Operadora: ${getTextoOperadora(operadora)}'
                          : 'Digite um número válido (84/85/86/87)',
                      style: TextStyle(
                        color: operadora != null ? Colors.green : Colors.red,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (paymentProvider.isLoading)
                      const CircularProgressIndicator()
                    else if (numeroValido)
                      ElevatedButton.icon(
                        onPressed: () {
                          final fullNumber = '258${phoneController.text}';
                          paymentProvider.processPayment(
                            phoneNumber: fullNumber,
                            amount: amountController.text,
                          );
                        },
                        icon: Icon(
                          getIconOperadora(operadora),
                          color: Colors.white,
                        ),
                        label: Text(
                          'Sacar com ${getTextoOperadora(operadora)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: getCorOperadora(operadora),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      )
                    else
                      const Text(
                        'Digite um número válido para habilitar o saque',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void showAddDonorPopup(Grupo grupo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Adicionar Doador ${grupo.nome}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _popupButton('WhatsApp', () => _compartilharWhatsApp(grupo.nome, _fundadorRecrutador)),
            _popupButton('Facebook', () => _compartilharFacebook(grupo.nome, _fundadorRecrutador)),
            _popupButton('SMS', () => _compartilharSMS(grupo.nome, _fundadorRecrutador)),
            _popupButton('Teste', () => _adicionarDoadorTeste(grupo)),
          ],
        ),
      ),
    );
  }

  void _compartilharWhatsApp(String grupo, String fundadorRecrutadorId) async {
  final mensagem = '💰 GANHE DINHEIRO JUSTO E CERTO APENAS COM ALGUNS CLICKS! 💰\n\n'
      '🚀 OPORTUNIDADE ÚNICA DE INVESTIMENTO EM REDE 🚀\n\n'
      '👉 Junte-se ao grupo $grupo no XITIKE 👈\n\n'
      '✅ Vantagens exclusivas:\n'
      '• Retorno garantido através do sistema hierárquico\n'
      '• Ganhos proporcionais ao seu esforço\n'
      '• Comunidade de investidores comprometidos\n'
      '• Suporte 24/7 para dúvidas\n\n'
      '💎 Não perca esta chance de transformar seu futuro financeiro!\n\n'
      '🔗 Clique no link para participar agora mesmo:\n'
      'https://xitike.com/convite/$grupo/$fundadorRecrutadorId\n\n'
      '#XitikeInvestimentos #$grupo #OportunidadeÚnica';

  final url = 'https://wa.me/?text=${Uri.encodeComponent(mensagem)}';

  try {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } else {
      // Fallback: copiar para área de transferência
      await Clipboard.setData(ClipboardData(text: mensagem));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copiado para área de transferência!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    await Clipboard.setData(ClipboardData(text: mensagem));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mensagem copiada para área de transferência!'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

  void _compartilharFacebook(String grupo, String fundadorRecrutadorId) async {
    final link = 'https://xitike.com/convite/$grupo/$fundadorRecrutadorId';
    final mensagem = '💰 GANHE DINHEIRO JUSTO E CERTO APENAS COM ALGUNS CLICKS! 💰\n\n'
        '🚀 OPORTUNIDADE ÚNICA DE INVESTIMENTO EM REDE 🚀\n\n'
        '👉 Junte-se ao grupo $grupo no XITIKE 👈\n\n'
        '✅ Vantagens exclusivas:\n'
        '• Retorno garantido através do sistema hierárquico\n'
        '• Ganhos proporcioais ao seu esforço\n'
        '• Comunidade de investidores comprometidos\n'
        '• Suporte 24/7 para dúvidas\n\n'
        '💎 Não perca esta chance de transformar seu futuro financeiro!\n\n'
        '🔗 Clique no link para participar agora mesmo:\n'
        '$link\n\n'
        '#XitikeInvestimentos #$grupo #OportunidadeÚnica';

    final shareUrl = 'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(link)}&quote=${Uri.encodeComponent(mensagem)}';

    try {
      final uri = Uri.parse(shareUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o Facebook')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao abrir o Facebook')),
      );
    }
  }

  void _compartilharSMS(String grupo, String fundadorRecrutadorId) async {
    final mensagem = '💰 GANHE DINHEIRO JUSTO E CERTO APENAS COM ALGUNS CLICKS! 💰\n\n'
        '🚀 OPORTUNIDADE ÚNICA DE INVESTIMENTO EM REDE 🚀\n\n'
        '👉 Junte-se ao grupo $grupo no XITIKE 👈\n\n'
        '✅ Vantagens exclusivas:\n'
        '• Retorno garantido através do sistema hierárquico\n'
        '• Ganhos proporcioais ao seu esforço\n'
        '• Comunidade de investidores comprometidos\n'
        '• Suporte 24/7 para dúvidas\n\n'
        '💎 Não perca esta chance de transformar seu futuro financeiro!\n\n'
        '🔗 Clique no link para participar agora mesmo:\n'
        'https://xitike.com/convite/$grupo/$fundadorRecrutadorId\n\n'
        '#XitikeInvestimentos #$grupo #OportunidadeÚnica';

    final url = 'sms:?body=${Uri.encodeComponent(mensagem)}';

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir SMS')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao abrir SMS')),
      );
    }
  }

  Widget _popupButton(String title, VoidCallback action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton(
        onPressed: () {
          Navigator.of(context).pop();
          action();
        },
        child: Text(title),
      ),
    );
  }

  void _sacarBonusRede() {
    final user = Provider.of<UserAccount>(context, listen: false);
    user.sacarBonusRedeAdmin();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Bônus de rede do admin sacado com sucesso!')),
    );
  }

  // ------------------ LÓGICA ------------------
  void _investir(Grupo grupo) {
    setState(() {
      GroupState current = states[grupo.nome]!;
      final user = Provider.of<UserAccount>(context, listen: false);
      final investingViaGroupLink = (groupFromLink != null &&
          grupo.nome == groupFromLink &&
          !firstInvestmentDoneInLinkedGroup);

      if (investingViaGroupLink) {
        current = InvestmentService.processInvestmentViaLink(
          grupo: grupo,
          groupState: current,
          admin: user,
          fundadorRecrutadorId: _fundadorRecrutador,
        );
        firstInvestmentDoneInLinkedGroup = true;
      } else {
        current = InvestmentService.processInvestmentRei(
          grupo: grupo,
          groupState: current,
          admin: user,
        );
      }
      states[grupo.nome] = current;
    });
  }

  void _adicionarDoadorTeste(Grupo grupo) {
    setState(() {
      final user = Provider.of<UserAccount>(context, listen: false);
      final newState = InvestmentService.addDonor(
        grupo: grupo,
        groupState: states[grupo.nome]!,
        admin: user,
        fundadorRecrutadorId: _fundadorRecrutador,
      );
      states[grupo.nome] = newState;
    });
  }

  void _sacarBonus(Grupo grupo) {
    setState(() {
      final newState = InvestmentService.withdrawBonus(
        grupo: grupo,
        groupState: states[grupo.nome]!,
      );
      states[grupo.nome] = newState;
    });
  }

  // ------------------ NOVA UI - TABELA DE CONTROLE ------------------
  Widget _buildTabelaControle({
    required String founderName,
    required double bonusAcumulado,
    required double saldoASacar,
    required double bonusRede,
    required double totalInvestido,
    required double adminBalance,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color.fromARGB(200, 75, 161, 248),
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar e Nome
            Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.shade200,
                    border: Border.all(color: Colors.blue.shade400, width: 2),
                  ),
                  child:
                      const Icon(Icons.person, size: 30, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  founderName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Grade 2x2 com os valores
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.3,
              children: [
                _buildInfoCard(
                  title: 'Bônus Acumulado',
                  value: '${bonusAcumulado.toStringAsFixed(2)} MT',
                  icon: Icons.attach_money,
                  color: Colors.purple,
                ),
                _buildInfoCard(
                  title: 'Saldo a Sacar',
                  value: '${saldoASacar.toStringAsFixed(2)} MT',
                  icon: Icons.account_balance_wallet,
                  color: Colors.green,
                ),
                _buildInfoCard(
                  title: 'Bônus de Rede',
                  value: '${bonusRede.toStringAsFixed(2)} MT',
                  icon: Icons.account_tree,
                  color: Colors.orange,
                ),
                _buildInfoCard(
                  title: 'Total Investido',
                  value: '${totalInvestido.toStringAsFixed(2)} MT',
                  icon: Icons.trending_up,
                  color: Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Botão para Sacar Bônus de Rede
            ElevatedButton.icon(
              onPressed: bonusRede > 0 ? _sacarBonusRede : null,
              icon: const Icon(Icons.account_balance_wallet, size: 18),
              label: const Text('Sacar Bônus de Rede'),
              style: ElevatedButton.styleFrom(
                backgroundColor: bonusRede > 0 ? Colors.purple : Colors.grey,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
            const SizedBox(height: 8),

            // Saldo Admin (provisão para testes)
            Text(
              'Saldo Admin: ${adminBalance.toStringAsFixed(2)} MT',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserAccount>(context);

    // CORREÇÃO: Verificar se states está inicializado
    if (states.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final totalSacado = states.values
        .map((st) => st.founders.first.balance)
        .fold(0.0, (a, b) => a + b);

    final totalInvestido = states.values
        .map((st) => st.founders.first.totalInvestido)
        .fold(0.0, (a, b) => a + b);

    final bonusAcumulado = states.values
        .map((st) => st.founders.first.bonusAcumulado)
        .fold(0.0, (a, b) => a + b);

    final founder = states.values.first.founders.first;
    final adminBalance = user.adminBalance;
    final bonusRedeAdmin = user.bonusRedeAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.currency_exchange, color: Colors.white),
            SizedBox(width: 10),
            Text(
              'XITIKE - Simulação',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        elevation: 5,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('termo_lido');
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (_) => false,
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Nova Tabela de Controle
            _buildTabelaControle(
              founderName: founder.name,
              bonusAcumulado: bonusAcumulado,
              saldoASacar: totalSacado,
              bonusRede: bonusRedeAdmin,
              totalInvestido: totalInvestido,
              adminBalance: adminBalance,
            ),
            const SizedBox(height: 16),

            // Lista de Grupos
            Expanded(
              child: ListView.builder(
                itemCount: widget.grupos.length,
                itemBuilder: (context, index) {
                  final g = widget.grupos[index];
                  final st = states[g.nome]!;
                  final fundador = st.founders[0];
                  final limite = g.limiteDoadores;
                  final ciclosCompletos = fundador.donors.length ~/ limite;
                  final doadoresNoCicloAtual = fundador.donors.length % limite;
                  final progressoCicloAtual = doadoresNoCicloAtual / limite;
                  final progressoPercentual =
                      (progressoCicloAtual * 100).toInt();
                  final valorCicloCompleto =
                      limite * g.valor * g.percentualBonusBase;
                  final podeSacar =
                      fundador.bonusAcumulado >= valorCicloCompleto;
                  final grupoHabilitado = _grupoHabilitadoParaInvestir(g);
                  final atingiuLimite = st.atingiuLimiteInvestimentos;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Opacity(
                        opacity: grupoHabilitado ? 1.0 : 0.5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  g.nome,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color:
                                        const Color.fromARGB(255, 73, 108, 148),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Chip(
                                      label: Text(
                                        '${g.valor.toStringAsFixed(0)} MT',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      backgroundColor: Colors.blue.shade700,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${st.investmentsCount}/${g.maxInvestimentos} invest.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: atingiuLimite
                                            ? Colors.red
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Base Percentual: ${(g.percentualBonusBase * 100).toInt()}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Progresso do Ciclo:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Stack(
                              children: [
                                LinearProgressIndicator(
                                  value: progressoCicloAtual,
                                  backgroundColor: Colors.grey.shade300,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    podeSacar ? Colors.green : Colors.blue,
                                  ),
                                  minHeight: 20,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                Positioned.fill(
                                  child: Center(
                                    child: Text(
                                      '$progressoPercentual% Concluído',
                                      style: TextStyle(
                                        color: progressoPercentual > 50
                                            ? Colors.white
                                            : Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Doadores: $doadoresNoCicloAtual/$limite',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  'Ciclos: $ciclosCompletos',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Total: ${fundador.donors.length} doadores',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: (!atingiuLimite && grupoHabilitado)
                                      ? () => showInvestPopup(g)
                                      : null,
                                  icon: const Icon(Icons.add_chart, size: 18),
                                  label: Text(
                                    atingiuLimite
                                        ? 'Limite Atingido'
                                        : grupoHabilitado
                                            ? 'Investir'
                                            : 'Bloqueado (usar link)',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: atingiuLimite
                                        ? Colors.grey
                                        : Colors.blue.shade700,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: st.donorsPending > 0
                                      ? () => showAddDonorPopup(g)
                                      : null,
                                  icon: const Icon(Icons.person_add, size: 18),
                                  label: const Text('Adicionar Doador'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade700,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: podeSacar
                                      ? () => showWithdrawPopup(g)
                                      : null,
                                  icon: const Icon(Icons.account_balance,
                                      size: 18),
                                  label: Text(
                                    podeSacar
                                        ? 'Sacar Bônus!'
                                        : 'Completar Ciclo',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: podeSacar
                                        ? Colors.green.shade600
                                        : Colors.grey.shade400,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Investimentos: ${st.investmentsCount}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  'Pendentes: ${st.donorsPending}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: st.donorsPending > 0
                                        ? Colors.orange.shade700
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            if (atingiuLimite)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Limite de investimentos atingido!',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ---------------------- PÁGINA DE CONVITE ----------------------
class ConvitePage extends StatelessWidget {
  final String grupo;
  final String recrutador;

  const ConvitePage({Key? key, required this.grupo, required this.recrutador});

  @override
  Widget build(BuildContext context) {
    // Encontrar o grupo correspondente
    final grupos = [
      const Grupo(
        nome: 'Curioso',
        valor: 50,
        limiteDoadores: 10,
        maxInvestimentos: 10,
        percentualBonusBase: 0.40,
      ),
      const Grupo(
        nome: 'Focado',
        valor: 100,
        limiteDoadores: 6,
        maxInvestimentos: 20,
        percentualBonusBase: 0.50,
      ),
      const Grupo(
        nome: 'Determinado',
        valor: 500,
        limiteDoadores: 4,
        maxInvestimentos: 50,
        percentualBonusBase: 0.60,
      ),
      const Grupo(
        nome: 'Visionário',
        valor: 1000,
        limiteDoadores: 2,
        maxInvestimentos: 100,
        percentualBonusBase: 0.80,
      ),
    ];

    final grupoData =
        grupos.firstWhere((g) => g.nome == grupo, orElse: () => grupos[0]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Convite Xitike'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            Text(
              '🎉 Parabéns! Você foi convidado!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              '$recrutador convidou você para participar do grupo:',

              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      grupoData.nome,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Valor do investimento: ${grupoData.valor.toInt()} MT',
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      'Limite de doadores: ${grupoData.limiteDoadores}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      'Bônus base: ${(grupoData.percentualBonusBase * 100).toInt()}%',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                // Aqui você pode implementar a navegação para o investimento
                // com o grupo pré-selecionado
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Voltar para Investir'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
