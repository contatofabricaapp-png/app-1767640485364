import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LicenseStatus { trial, licensed, expired }

class LicenseManager {
  static const String _firstRunKey = 'app_first_run';
  static const String _licenseKey = 'app_license';
  static const int trialDays = 5;

  static Future<LicenseStatus> checkLicense() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_licenseKey) != null) return LicenseStatus.licensed;
    final firstRun = prefs.getString(_firstRunKey);
    if (firstRun == null) {
      await prefs.setString(_firstRunKey, DateTime.now().toIso8601String());
      return LicenseStatus.trial;
    }
    final startDate = DateTime.parse(firstRun);
    final daysUsed = DateTime.now().difference(startDate).inDays;
    return daysUsed < trialDays ? LicenseStatus.trial : LicenseStatus.expired;
  }

  static Future<int> getRemainingDays() async {
    final prefs = await SharedPreferences.getInstance();
    final firstRun = prefs.getString(_firstRunKey);
    if (firstRun == null) return trialDays;
    final startDate = DateTime.parse(firstRun);
    final daysUsed = DateTime.now().difference(startDate).inDays;
    return (trialDays - daysUsed).clamp(0, trialDays);
  }

  static Future<bool> activate(String key) async {
    final cleaned = key.trim().toUpperCase();
    final regex = RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}');
    if (regex.hasMatch(cleaned) && cleaned.length == 19) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_licenseKey, cleaned);
      return true;
    }
    return false;
  }
}

class TrialBanner extends StatelessWidget {
  final int daysRemaining;
  const TrialBanner({super.key, required this.daysRemaining});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: daysRemaining <= 2 ? Colors.red : Colors.orange,
      child: Text(
        'Teste: ' + daysRemaining.toString() + ' dias restantes',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class LicenseExpiredScreen extends StatefulWidget {
  const LicenseExpiredScreen({super.key});
  @override
  State<LicenseExpiredScreen> createState() => _LicenseExpiredScreenState();
}

class _LicenseExpiredScreenState extends State<LicenseExpiredScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _activate() async {
    setState(() { _loading = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 500));
    final ok = await LicenseManager.activate(_ctrl.text);
    if (ok && mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RestartApp()));
    } else if (mounted) {
      setState(() { _error = 'Chave inválida'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.red.shade800, Colors.red.shade600], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 80, color: Colors.white),
                const SizedBox(height: 24),
                const Text('Período de Teste Encerrado', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 32),
                TextField(controller: _ctrl, decoration: InputDecoration(labelText: 'Chave de Licença', hintText: 'XXXX-XXXX-XXXX-XXXX', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), errorText: _error), textCapitalization: TextCapitalization.characters, maxLength: 19),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _activate, style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: Colors.green), child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Ativar', style: TextStyle(fontSize: 18, color: Colors.white)))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RestartApp extends StatelessWidget {
  const RestartApp({super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([LicenseManager.checkLicense(), LicenseManager.getRemainingDays()]),
      builder: (context, snap) {
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        return MyApp(licenseStatus: snap.data![0] as LicenseStatus, remainingDays: snap.data![1] as int);
      },
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final status = await LicenseManager.checkLicense();
  final days = await LicenseManager.getRemainingDays();
  runApp(MyApp(licenseStatus: status, remainingDays: days));
}

class MyApp extends StatelessWidget {
  final LicenseStatus licenseStatus;
  final int remainingDays;
  const MyApp({super.key, required this.licenseStatus, required this.remainingDays});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue), useMaterial3: true),
      home: licenseStatus == LicenseStatus.expired ? const LicenseExpiredScreen() : HomeScreen(licenseStatus: licenseStatus, remainingDays: remainingDays),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final LicenseStatus licenseStatus;
  final int remainingDays;
  const HomeScreen({super.key, required this.licenseStatus, required this.remainingDays});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Map<String, dynamic>> marmitas = [
    {'nome': 'Frango com Batata Doce', 'preco': 18.50, 'calorias': 450, 'proteina': 35},
    {'nome': 'Carne com Abobrinha', 'preco': 22.00, 'calorias': 520, 'proteina': 42},
    {'nome': 'Peixe com Quinoa', 'preco': 25.90, 'calorias': 380, 'proteina': 38},
    {'nome': 'Salmão com Brócolis', 'preco': 28.50, 'calorias': 490, 'proteina': 40},
  ];

  List<Map<String, dynamic>> carrinho = [];

  void adicionarCarrinho(Map<String, dynamic> marmita) {
    setState(() {
      carrinho.add(marmita);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${marmita['nome']} adicionado ao carrinho'))
    );
  }

  void verCarrinho() {
    double total = carrinho.fold(0, (sum, item) => sum + item['preco']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Carrinho'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (carrinho.isEmpty) const Text('Carrinho vazio'),
            for (var item in carrinho)
              ListTile(
                title: Text(item['nome']),
                trailing: Text('R\$ ${item['preco'].toStringAsFixed(2)}'),
              ),
            if (carrinho.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text('Total: R\$ ${total.toStringAsFixed(2)}', 
                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          if (carrinho.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                setState(() {
                  carrinho.clear();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pedido realizado com sucesso!'))
                );
              },
              child: const Text('Finalizar'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FitMarmitas'),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.shopping_cart),
                if (carrinho.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text(carrinho.length.toString(), 
                                 style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
              ],
            ),
            onPressed: verCarrinho,
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.licenseStatus == LicenseStatus.trial) TrialBanner(daysRemaining: widget.remainingDays),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }
  
  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Marmitas Fit Disponíveis', 
                     style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: marmitas.length,
              itemBuilder: (context, index) {
                final marmita = marmitas[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(marmita['nome'], 
                                         style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                            Text('R\$ ${marmita['preco'].toStringAsFixed(2)}', 
                                 style: TextStyle(fontSize: 18, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.local_fire_department, size: 16, color: Colors.orange),
                            Text(' ${marmita['calorias']} cal'),
                            const SizedBox(width: 16),
                            Icon(Icons.fitness_center, size: 16, color: Colors.blue),
                            Text(' ${marmita['proteina']}g proteína'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => adicionarCarrinho(marmita),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text('Adicionar ao Carrinho', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}