import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = FinanceStore();
  await store.load();
  runApp(FinanceApp(store));
}

class FinanceStore extends ChangeNotifier {
  final List<Map<String, dynamic>> accounts = [];
  final List<Map<String, dynamic>> investments = [];
  final List<Map<String, dynamic>> receivables = [];
  List<Map<String, dynamic>> ledger = [];
  List<Map<String, dynamic>> checks = [];
  String asOf = '';
  int sourceTransactions = 0;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('financeLedgerV2');
    if (saved != null) {
      _loadData(jsonDecode(saved));
      return;
    }
    final seed = jsonDecode(
      await rootBundle.loadString('assets/excel_import.json'),
    );
    _loadData(seed);
    // Keep post-import V1 entries while replacing its flawed bundled import.
    for (final e in _decode(
      prefs.getString('transactions'),
    ).where((x) => !x['id'].toString().startsWith('import-'))) {
      final account = accounts
          .where((a) => a['id'] == e['accountId'])
          .map((a) => a['name'])
          .firstOrNull;
      if (account == null) continue;
      final value = n(e['amount']);
      final incoming = e['type'] == 'Income' || e['flow'] == 'in';
      ledger.add({
        'id': 'legacy-${e['id']}',
        'date': e['date'].toString().substring(0, 10),
        'transactionType': e['type'] ?? 'Expense',
        'category': e['category'] ?? '',
        'subCategory': '',
        'receipt': incoming ? value : 0,
        'payment': incoming ? 0 : value,
        'accountName': account,
        'payee': '',
        'remarks': 'Preserved V1 entry',
      });
    }
    await save();
  }

  void _loadData(Map<String, dynamic> data) {
    accounts
      ..clear()
      ..addAll(_maps(data['accounts']));
    investments
      ..clear()
      ..addAll(_maps(data['investments']));
    receivables
      ..clear()
      ..addAll(_maps(data['receivables']));
    ledger = _maps(data['ledger']);
    checks = _maps((data['reconciliation'] ?? {})['checks']);
    final source = Map<String, dynamic>.from(data['source'] ?? {});
    asOf = source['asOf']?.toString() ?? '';
    sourceTransactions = source['transactionCount'] ?? ledger.length;
  }

  List<Map<String, dynamic>> _maps(dynamic v) =>
      List<Map<String, dynamic>>.from(
        (v as List? ?? []).map((x) => Map<String, dynamic>.from(x)),
      );
  List<Map<String, dynamic>> _decode(String? v) {
    try {
      return v == null ? [] : _maps(jsonDecode(v));
    } catch (_) {
      return [];
    }
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      'financeLedgerV2',
      jsonEncode({
        'accounts': accounts,
        'investments': investments,
        'receivables': receivables,
        'ledger': ledger,
        'reconciliation': {'checks': checks},
        'source': {'asOf': asOf, 'transactionCount': sourceTransactions},
      }),
    );
    notifyListeners();
  }

  double n(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
  double accountBalance(Map<String, dynamic> a) =>
      n(a['opening']) +
      ledger
          .where((e) => e['accountName'] == a['name'])
          .fold(0.0, (s, e) => s + n(e['receipt']) - n(e['payment']));
  double investmentBalance(Map<String, dynamic> a) {
    const aliases = {'Dhan': 'MutualFund'};
    return n(a['opening']) +
        ledger
            .where(
              (e) =>
                  e['transactionType'] == 'Investment' &&
                  (e['subCategory'] == a['name'] ||
                      aliases[e['subCategory']] == a['name'] ||
                      (e['subCategory'] == '' && e['category'] == a['name'])),
            )
            .fold(0.0, (s, e) => s + n(e['payment']) - n(e['receipt']));
  }

  double receivableBalance(Map<String, dynamic> a) =>
      n(a['opening']) +
      (a['activityTracked'] == true
          ? ledger
                .where(
                  (e) =>
                      e['transactionType'] == 'Others' &&
                      e['payee'] == a['name'],
                )
                .fold(0.0, (s, e) => s + n(e['payment']) - n(e['receipt']))
          : 0);
  double get bankCash => accounts
      .where((a) => a['kind'] == 'bank' || a['kind'] == 'cash')
      .fold(0.0, (s, a) => s + accountBalance(a));
  double get cards => accounts
      .where((a) => a['kind'] == 'creditCard')
      .fold(0.0, (s, a) => s + accountBalance(a));
  double get investmentTotal =>
      investments.fold(0.0, (s, a) => s + investmentBalance(a));
  double get receivableTotal =>
      receivables.fold(0.0, (s, a) => s + receivableBalance(a));
  double get netWorth => bankCash + cards + investmentTotal + receivableTotal;
  void add(Map<String, dynamic> entry) {
    ledger.add(entry);
    save();
  }

  double current(Map<String, dynamic> check) {
    if (check['group'] == 'Account')
      return accountBalance(
        accounts.firstWhere((a) => a['id'] == check['entityId']),
      );
    if (check['group'] == 'Investment')
      return investmentBalance(
        investments.firstWhere((a) => a['id'] == check['entityId']),
      );
    return receivableBalance(
      receivables.firstWhere((a) => a['id'] == check['entityId']),
    );
  }
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

String money(double v) => NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
).format(v.abs());
String shown(double v) => '${v < 0 ? '-' : ''}${money(v)}';

class FinanceApp extends StatelessWidget {
  final FinanceStore s;
  const FinanceApp(this.s, {super.key});
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: s,
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Personal Finance',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: Home(s),
    ),
  );
}

class Home extends StatefulWidget {
  final FinanceStore s;
  const Home(this.s, {super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  @override
  Widget build(BuildContext c) {
    final pages = [
      Dashboard(widget.s),
      LedgerPage(widget.s),
      Positions(widget.s),
      Reconcile(widget.s),
    ];
    return Scaffold(
      body: SafeArea(child: pages[tab]),
      floatingActionButton: tab == 1
          ? FloatingActionButton.extended(
              onPressed: () => addEntry(c, widget.s),
              icon: const Icon(Icons.add),
              label: const Text('Add entry'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Ledger',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance),
            label: 'Positions',
          ),
          NavigationDestination(
            icon: Icon(Icons.verified_outlined),
            selectedIcon: Icon(Icons.verified),
            label: 'Reconcile',
          ),
        ],
      ),
    );
  }
}

class Dashboard extends StatelessWidget {
  final FinanceStore s;
  const Dashboard(this.s, {super.key});
  @override
  Widget build(BuildContext c) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'My Finances',
        style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
      ),
      Text(
        'Reconciled through ${s.asOf}',
        style: const TextStyle(color: Colors.black54),
      ),
      const SizedBox(height: 16),
      Card(
        color: Theme.of(c).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('NET WORTH'),
              Text(
                shown(s.netWorth),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text('Assets + receivables − card liabilities'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          Metric('Bank & Cash', s.bankCash),
          Metric('Card liabilities', s.cards),
          Metric('Investments', s.investmentTotal),
          Metric('Receivables', s.receivableTotal),
        ],
      ),
      const SizedBox(height: 20),
      Text(
        '${s.sourceTransactions} historical source rows',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      const Text(
        'Opening balances and both sides of transfers are retained locally.',
      ),
    ],
  );
}

class Metric extends StatelessWidget {
  final String name;
  final double value;
  const Metric(this.name, this.value, {super.key});
  @override
  Widget build(BuildContext c) => SizedBox(
    width: (MediaQuery.of(c).size.width - 42) / 2,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name),
            Text(
              shown(value),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    ),
  );
}

class LedgerPage extends StatefulWidget {
  final FinanceStore s;
  const LedgerPage(this.s, {super.key});
  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  String query = '';
  @override
  Widget build(BuildContext c) {
    final list =
        widget.s.ledger
            .where(
              (e) =>
                  '${e['transactionType']} ${e['category']} ${e['payee']} ${e['accountName']}'
                      .toLowerCase()
                      .contains(query.toLowerCase()),
            )
            .toList()
          ..sort(
            (a, b) => b['date'].toString().compareTo(a['date'].toString()),
          );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search historical ledger',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final e = list[i];
              final d = widget.s.n(e['receipt']) - widget.s.n(e['payment']);
              return ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    d >= 0 ? Icons.arrow_downward : Icons.arrow_upward,
                  ),
                ),
                title: Text(
                  e['category'].toString().isEmpty
                      ? e['transactionType'].toString()
                      : e['category'].toString(),
                ),
                subtitle: Text(
                  '${e['date']} • ${e['accountName']} ${e['payee'].toString().isEmpty ? '' : '• ${e['payee']}'}',
                ),
                trailing: Text(
                  shown(d),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: d < 0 ? Colors.red : Colors.green,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class Positions extends StatelessWidget {
  final FinanceStore s;
  const Positions(this.s, {super.key});
  Widget section(
    String t,
    List<Map<String, dynamic>> rows,
    double Function(Map<String, dynamic>) calc,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 15, bottom: 4),
        child: Text(
          t,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
      ),
      ...rows
          .map(
            (a) => ListTile(
              title: Text(a['name']),
              subtitle: Text(a['kind']?.toString() ?? ''),
              trailing: Text(
                shown(calc(a)),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          )
          .toList(),
    ],
  );
  @override
  Widget build(BuildContext c) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'Positions',
        style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
      ),
      section('Bank & cards', s.accounts, s.accountBalance),
      section('Investments', s.investments, s.investmentBalance),
      section('Loans / receivables', s.receivables, s.receivableBalance),
    ],
  );
}

class Reconcile extends StatelessWidget {
  final FinanceStore s;
  const Reconcile(this.s, {super.key});
  @override
  Widget build(BuildContext c) {
    final allOk = s.checks.every(
      (x) => (s.current(x) - s.n(x['expected'])).abs() < .01,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          allOk
              ? 'Excel reconciliation: MATCHED'
              : 'Excel reconciliation: REVIEW',
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        const Text(
          'Opening balance + retained ledger is compared account by account.',
        ),
        const SizedBox(height: 12),
        ...s.checks.map((x) {
          final d = s.current(x) - s.n(x['expected']);
          return ListTile(
            leading: Icon(
              d.abs() < .01 ? Icons.check_circle : Icons.error,
              color: d.abs() < .01 ? Colors.green : Colors.red,
            ),
            title: Text('${x['group']} • ${x['name']}'),
            subtitle: Text(
              'Excel ${shown(s.n(x['expected']))} | App ${shown(s.current(x))}',
            ),
            trailing: Text(shown(d)),
          );
        }),
      ],
    );
  }
}

Future<void> addEntry(BuildContext c, FinanceStore s) async {
  String type = 'Expense',
      from = s.accounts.first['name'],
      to = s.accounts.first['name'];
  final amount = TextEditingController(),
      category = TextEditingController(),
      payee = TextEditingController();
  await showModalBottomSheet(
    context: c,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField(
                value: type,
                items:
                    const [
                          'Expense',
                          'Income',
                          'Transfer',
                          'Investment',
                          'Loan',
                          'Loan Repayment',
                        ]
                        .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                        .toList(),
                onChanged: (v) => set(() => type = v.toString()),
              ),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                ),
              ),
              TextField(
                controller: category,
                decoration: const InputDecoration(
                  labelText: 'Category / investment',
                ),
              ),
              TextField(
                controller: payee,
                decoration: const InputDecoration(
                  labelText: 'Payee / receivable',
                ),
              ),
              DropdownButtonFormField(
                value: from,
                items: s.accounts
                    .map(
                      (a) => DropdownMenuItem(
                        value: a['name'].toString(),
                        child: Text(a['name']),
                      ),
                    )
                    .toList(),
                onChanged: (v) => set(() => from = v.toString()),
              ),
              if (type == 'Transfer')
                DropdownButtonFormField(
                  value: to,
                  items: s.accounts
                      .map(
                        (a) => DropdownMenuItem(
                          value: a['name'].toString(),
                          child: Text('To ${a['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => set(() => to = v.toString()),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  final v = double.tryParse(amount.text) ?? 0;
                  if (v <= 0) return;
                  final id = DateTime.now().microsecondsSinceEpoch.toString(),
                      date = DateTime.now().toIso8601String().substring(0, 10);
                  if (type == 'Transfer') {
                    s.add({
                      'id': 'user-$id-a',
                      'date': date,
                      'transactionType': 'Transfer',
                      'category': 'WithinBank',
                      'subCategory': to,
                      'receipt': 0,
                      'payment': v,
                      'accountName': from,
                      'payee': to,
                      'remarks': 'User transfer',
                      'transferLinkId': 'user-$id',
                    });
                    s.add({
                      'id': 'user-$id-b',
                      'date': date,
                      'transactionType': 'Transfer',
                      'category': 'WithinBank',
                      'subCategory': from,
                      'receipt': v,
                      'payment': 0,
                      'accountName': to,
                      'payee': from,
                      'remarks': 'User transfer',
                      'transferLinkId': 'user-$id',
                    });
                  } else {
                    final incoming =
                        type == 'Income' || type == 'Loan Repayment';
                    s.add({
                      'id': 'user-$id',
                      'date': date,
                      'transactionType':
                          type == 'Loan' || type == 'Loan Repayment'
                          ? 'Others'
                          : type,
                      'category': type == 'Loan' || type == 'Loan Repayment'
                          ? type
                          : category.text.trim(),
                      'subCategory': category.text.trim(),
                      'receipt': incoming ? v : 0,
                      'payment': incoming ? 0 : v,
                      'accountName': from,
                      'payee': payee.text.trim(),
                      'remarks': 'User entry',
                    });
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
