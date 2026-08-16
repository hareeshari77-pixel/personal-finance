
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = FinanceStore();
  await store.load();
  runApp(FinanceApp(store: store));
}

class FinanceStore extends ChangeNotifier {
  List<Map<String, dynamic>> accounts = [];
  List<Map<String, dynamic>> transactions = [];
  List<String> categories = [
    'Salary','Other Income','Housing','Groceries','Food','Shopping',
    'Travel','Entertainment','Transportation','Education','Health',
    'Family','Utilities','Miscellaneous','Mutual Funds','Stocks','FD/RD',
    'Gold','Loan','Transfer'
  ];

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    accounts = _decodeList(p.getString('accounts'));
    transactions = _decodeList(p.getString('transactions'));
    final c = p.getStringList('categories');
    if (c != null && c.isNotEmpty) categories = c;

    // One-time migration of the user's existing Excel history.
    // Only runs when the app has no existing local transactions.
    if (transactions.isEmpty && p.getBool('excelImportV1Done') != true) {
      try {
        final raw = await rootBundle.loadString('assets/excel_import.json');
        final data = jsonDecode(raw) as Map<String, dynamic>;

        final importedAccounts =
            List<Map<String, dynamic>>.from((data['accounts'] as List).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ));

        final accountIds = <String, String>{};
        for (final a in importedAccounts) {
          final id = a['id'].toString();
          final name = a['name'].toString();
          accountIds[name] = id;
        }

        accounts = importedAccounts;

        final importedTransactions =
            List<Map<String, dynamic>>.from((data['transactions'] as List).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ));

        transactions = importedTransactions.map((t) {
          final copy = Map<String, dynamic>.from(t);
          final accountKey = copy.remove('accountKey')?.toString() ?? '';
          copy['accountId'] = accountIds[accountKey];
          return copy;
        }).where((t) => t['accountId'] != null).toList();

        final importedCategories = List<String>.from(
          (data['categories'] as List).map((e) => e.toString()),
        );
        categories = {...categories, ...importedCategories}.toList();

        await p.setBool('excelImportV1Done', true);
        await save();
      } catch (_) {
        // Keep the app usable even if an import asset is unavailable.
      }
    }
  }

  List<Map<String,dynamic>> _decodeList(String? s) {
    if (s == null) return [];
    try { return List<Map<String,dynamic>>.from(jsonDecode(s).map((e)=>Map<String,dynamic>.from(e))); }
    catch (_) { return []; }
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('accounts', jsonEncode(accounts));
    await p.setString('transactions', jsonEncode(transactions));
    await p.setStringList('categories', categories);
    notifyListeners();
  }

  void addAccount(Map<String,dynamic> a) { accounts.add(a); save(); }
  void deleteAccount(String id) { accounts.removeWhere((a)=>a['id']==id); save(); }
  void addTransaction(Map<String,dynamic> t) { transactions.add(t); save(); }
  void deleteTransaction(String id) { transactions.removeWhere((t)=>t['id']==id); save(); }
  void addCategory(String c) { if(c.trim().isNotEmpty && !categories.contains(c.trim())) { categories.add(c.trim()); save(); } }

  double get bankBalance {
    double total = 0;
    for (final a in accounts) {
      if (a['type'] == 'Bank' || a['type'] == 'Cash' || a['type'] == 'Wallet') {
        total += balanceFor(a['id']);
      }
    }
    return total;
  }

  double get cardOutstanding {
    double total = 0;
    for (final a in accounts.where((x)=>x['type']=='Credit Card')) total += -balanceFor(a['id']);
    return total < 0 ? 0 : total;
  }

  double balanceFor(String id) {
    final a = accounts.firstWhere((x)=>x['id']==id, orElse: ()=>{'opening':0});
    double v = (a['opening'] ?? 0).toDouble();
    for (final t in transactions.where((x)=>x['accountId']==id)) {
      final type=t['type'];
      final amount=(t['amount'] ?? 0).toDouble();
      if (type=='Income') {
        v += amount;
      } else if (type=='Expense') {
        v -= amount;
      } else if (type=='Investment' || type=='Others') {
        v += (t['flow']=='in' ? amount : -amount);
      } else if (type=='Transfer') {
        v += (t['direction']=='in' || t['flow']=='in' ? amount : -amount);
      }
    }
    return v;
  }

  double monthly(String type) {
    final now=DateTime.now();
    return transactions.where((t){
      final d=DateTime.tryParse(t['date']??'');
      return d!=null && d.year==now.year && d.month==now.month && t['type']==type;
    }).fold(0.0,(s,t)=>s+(t['amount']??0).toDouble());
  }

  double get investments {
    double total=0;
    for(final t in transactions.where((x)=>x['type']=='Investment')) total += (t['amount']??0).toDouble();
    return total;
  }

  double get netWorth => bankBalance + investments - cardOutstanding;
}

class FinanceApp extends StatelessWidget {
  final FinanceStore store;
  const FinanceApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (_,__) => MaterialApp(
        debugShowCheckedModeBanner:false,
        title:'Personal Finance',
        theme: ThemeData(useMaterial3:true, colorSchemeSeed:Colors.indigo, scaffoldBackgroundColor:const Color(0xfff6f7fb)),
        home: HomePage(store:store),
      ),
    );
  }
}

String money(double v) => NumberFormat.currency(locale:'en_IN',symbol:'₹',decimalDigits:0).format(v);

class HomePage extends StatefulWidget {
  final FinanceStore store;
  const HomePage({super.key, required this.store});
  @override State<HomePage> createState()=>_HomePageState();
}
class _HomePageState extends State<HomePage> {
  int tab=0;
  @override Widget build(BuildContext context) {
    final pages=[
      Dashboard(store:widget.store),
      TransactionsPage(store:widget.store),
      AccountsPage(store:widget.store),
      ReportsPage(store:widget.store),
    ];
    return Scaffold(
      body: SafeArea(child: pages[tab]),
      floatingActionButton: tab==1 ? FloatingActionButton.extended(
        onPressed:()=>showAddTransaction(context,widget.store),
        icon:const Icon(Icons.add), label:const Text('Transaction')) : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex:tab,
        onDestinationSelected:(i)=>setState(()=>tab=i),
        destinations:const[
          NavigationDestination(icon:Icon(Icons.dashboard_outlined),selectedIcon:Icon(Icons.dashboard),label:'Dashboard'),
          NavigationDestination(icon:Icon(Icons.receipt_long_outlined),selectedIcon:Icon(Icons.receipt_long),label:'Transactions'),
          NavigationDestination(icon:Icon(Icons.account_balance_outlined),selectedIcon:Icon(Icons.account_balance),label:'Accounts'),
          NavigationDestination(icon:Icon(Icons.bar_chart_outlined),selectedIcon:Icon(Icons.bar_chart),label:'Reports'),
        ])
    );
  }
}

class Dashboard extends StatelessWidget {
  final FinanceStore store;
  const Dashboard({super.key,required this.store});
  @override Widget build(BuildContext context){
    final income=store.monthly('Income'), expense=store.monthly('Expense'), inv=store.monthly('Investment');
    return RefreshIndicator(
      onRefresh:()=>store.load(),
      child: ListView(padding:const EdgeInsets.fromLTRB(16,20,16,100),children:[
        Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Good afternoon 👋',style:TextStyle(fontSize:16,color:Colors.black54)),
          Text('My Finances',style:TextStyle(fontSize:28,fontWeight:FontWeight.w800))
        ])), IconButton(onPressed:()=>showAddAccount(context,store),icon:const Icon(Icons.add_business_outlined))]),
        const SizedBox(height:16),
        Card(elevation:0,child:Padding(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('NET WORTH',style:TextStyle(fontSize:12,fontWeight:FontWeight.bold,letterSpacing:1.3)),
          const SizedBox(height:7),Text(money(store.netWorth),style:const TextStyle(fontSize:34,fontWeight:FontWeight.w900)),
          const SizedBox(height:8),Text('Assets and liabilities from your local records',style:TextStyle(color:Colors.grey.shade600))
        ]))),
        const SizedBox(height:12),
        GridView.count(crossAxisCount:2,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisSpacing:10,mainAxisSpacing:10,childAspectRatio:1.55,children:[
          MetricCard(icon:Icons.account_balance,title:'Bank & Cash',value:money(store.bankBalance)),
          MetricCard(icon:Icons.credit_card,title:'Card Outstanding',value:money(store.cardOutstanding)),
          MetricCard(icon:Icons.trending_up,title:'Investments',value:money(store.investments)),
          MetricCard(icon:Icons.savings_outlined,title:'This Month Savings',value:money(income-expense-inv)),
        ]),
        const SizedBox(height:18),
        const Text('This Month',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
        const SizedBox(height:10),
        Card(elevation:0,child:Column(children:[
          StatRow('Income',income,Icons.arrow_downward),
          StatRow('Expenses',expense,Icons.arrow_upward),
          StatRow('Investments',inv,Icons.trending_up),
        ])),
        const SizedBox(height:18),
        const Text('Quick actions',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
        const SizedBox(height:10),
        Wrap(spacing:8,runSpacing:8,children:[
          ActionChip(avatar:const Icon(Icons.remove,size:18),label:const Text('Expense'),onPressed:()=>showAddTransaction(context,store,initial:'Expense')),
          ActionChip(avatar:const Icon(Icons.add,size:18),label:const Text('Income'),onPressed:()=>showAddTransaction(context,store,initial:'Income')),
          ActionChip(avatar:const Icon(Icons.trending_up,size:18),label:const Text('Investment'),onPressed:()=>showAddTransaction(context,store,initial:'Investment')),
          ActionChip(avatar:const Icon(Icons.swap_horiz,size:18),label:const Text('Transfer'),onPressed:()=>showAddTransaction(context,store,initial:'Transfer')),
        ]),
      ]));
  }
}

class MetricCard extends StatelessWidget {
  final IconData icon; final String title,value;
  const MetricCard({super.key,required this.icon,required this.title,required this.value});
  @override Widget build(BuildContext context)=>Card(elevation:0,child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[
    Icon(icon,size:22),const SizedBox(height:7),Text(title,style:const TextStyle(fontSize:12)),Text(value,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold))
  ])));
}
class StatRow extends StatelessWidget {
  final String title; final double value; final IconData icon;
  const StatRow(this.title,this.value,this.icon,{super.key});
  @override Widget build(BuildContext context)=>ListTile(leading:CircleAvatar(radius:18,child:Icon(icon,size:17)),title:Text(title),trailing:Text(money(value),style:const TextStyle(fontWeight:FontWeight.bold)));
}

class TransactionsPage extends StatefulWidget {
  final FinanceStore store; const TransactionsPage({super.key,required this.store});
  @override State<TransactionsPage> createState()=>_TransactionsPageState();
}
class _TransactionsPageState extends State<TransactionsPage>{
  String q='';
  @override Widget build(BuildContext context){
    final list=widget.store.transactions.reversed.where((t){
      final text='${t['type']} ${t['category']} ${t['notes']??''}'.toLowerCase();
      return text.contains(q.toLowerCase());
    }).toList();
    return Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(16,20,16,8),child:Row(children:[
        const Expanded(child:Text('Transactions',style:TextStyle(fontSize:28,fontWeight:FontWeight.w800))),
        IconButton(onPressed:()=>showAddTransaction(context,widget.store),icon:const Icon(Icons.add_circle,size:30))
      ])),
      Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:TextField(decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:'Search transactions',filled:true,border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide.none)),onChanged:(v)=>setState(()=>q=v))),
      const SizedBox(height:8),
      Expanded(child:list.isEmpty?const Center(child:Text('No transactions yet. Tap + to add one.')):ListView.builder(itemCount:list.length,itemBuilder:(c,i){
        final t=list[i]; final type=t['type']; final sign=type=='Income'?'+':type=='Expense'||type=='Investment'?'-':'↔';
        return Dismissible(key:ValueKey(t['id']),background:Container(color:Colors.red),onDismissed:(_)=>widget.store.deleteTransaction(t['id']),child:ListTile(
          leading:CircleAvatar(child:Icon(type=='Income'?Icons.arrow_downward:type=='Expense'?Icons.arrow_upward:type=='Investment'?Icons.trending_up:Icons.swap_horiz,size:18)),
          title:Text(t['category']??type,style:const TextStyle(fontWeight:FontWeight.w600)),
          subtitle:Text('${t['date']} • ${t['notes']??''}'),
          trailing:Text('$sign ${money((t['amount']??0).toDouble())}',style:TextStyle(fontWeight:FontWeight.bold,color:type=='Expense'?Colors.red:type=='Income'?Colors.green:null))
        ));
      }))
    ]);
  }
}

class AccountsPage extends StatelessWidget {
  final FinanceStore store; const AccountsPage({super.key,required this.store});
  @override Widget build(BuildContext context)=>Column(children:[
    Padding(padding:const EdgeInsets.fromLTRB(16,20,8,10),child:Row(children:[const Expanded(child:Text('Accounts',style:TextStyle(fontSize:28,fontWeight:FontWeight.w800))),IconButton(onPressed:()=>showAddAccount(context,store),icon:const Icon(Icons.add_circle,size:30))])),
    Expanded(child:store.accounts.isEmpty?const Center(child:Text('No accounts yet. Add your first bank or card.')):ListView.builder(itemCount:store.accounts.length,itemBuilder:(c,i){
      final a=store.accounts[i]; final bal=store.balanceFor(a['id']);
      return Card(elevation:0,margin:const EdgeInsets.symmetric(horizontal:16,vertical:5),child:ListTile(
        leading:CircleAvatar(child:Icon(a['type']=='Credit Card'?Icons.credit_card:Icons.account_balance)),
        title:Text(a['name'],style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${a['type']} • ${a['institution']??''}'),
        trailing:Text(money(bal),style:const TextStyle(fontWeight:FontWeight.bold))
      ));
    }))
  ]);
}

class ReportsPage extends StatelessWidget {
  final FinanceStore store;
  const ReportsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final Map<String, double> expenseMap = {};

    for (final t in store.transactions) {
      final d = DateTime.tryParse(t['date'] ?? '');
      if (d != null &&
          d.year == now.year &&
          d.month == now.month &&
          t['type'] == 'Expense') {
        final category = t['category'] ?? 'Other';
        final amount = (t['amount'] ?? 0).toDouble();
        expenseMap[category] = (expenseMap[category] ?? 0.0) + amount;
      }
    }

    final entries = expenseMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0.0, (sum, e) => sum + e.value);

    final expenseWidgets = entries.map<Widget>((e) {
      final double pct = total == 0.0 ? 0.0 : e.value / total;

      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(e.key)),
                Text(
                  money(e.value),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 5),
            LinearProgressIndicator(value: pct, minHeight: 8),
            const SizedBox(height: 2),
            Text(
              '${(pct * 100).toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        const Text(
          'Reports',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          DateFormat('MMMM yyyy').format(now),
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 18),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Expense analysis',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('Total ${money(total)}'),
                const SizedBox(height: 16),
                if (entries.isEmpty)
                  const Text('No expenses this month.')
                else
                  ...expenseWidgets,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> showAddAccount(BuildContext context, FinanceStore store) async {
  final name=TextEditingController(), institution=TextEditingController(), opening=TextEditingController(text:'0');
  String type='Bank';
  await showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setState)=>AlertDialog(
    title:const Text('Add account'),
    content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:name,decoration:const InputDecoration(labelText:'Account name')),
      TextField(controller:institution,decoration:const InputDecoration(labelText:'Bank / institution')),
      TextField(controller:opening,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Opening balance')),
      DropdownButtonFormField<String>(value:type,decoration:const InputDecoration(labelText:'Type'),items:['Bank','Credit Card','Cash','Wallet','Other'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>type=v!))
    ])),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:(){
      if(name.text.trim().isEmpty)return;
      store.addAccount({'id':DateTime.now().microsecondsSinceEpoch.toString(),'name':name.text.trim(),'institution':institution.text.trim(),'type':type,'opening':double.tryParse(opening.text)??0});
      Navigator.pop(ctx);
    },child:const Text('Save'))]
  )));
}

Future<void> showAddTransaction(BuildContext context, FinanceStore store,{String initial='Expense'}) async {
  final amount=TextEditingController(), notes=TextEditingController();
  String type=initial, category=store.categories.first, accountId=store.accounts.isEmpty?'':store.accounts.first['id'];
  final date=DateTime.now();
  await showModalBottomSheet(context:context,isScrollControlled:true,builder:(ctx)=>StatefulBuilder(builder:(ctx,setState)=>Padding(
    padding:EdgeInsets.only(left:18,right:18,top:18,bottom:MediaQuery.of(ctx).viewInsets.bottom+18),
    child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Text('Add $type',style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
      const SizedBox(height:12),
      SegmentedButton<String>(segments:const[
        ButtonSegment(value:'Expense',label:Text('Expense'),icon:Icon(Icons.remove)),
        ButtonSegment(value:'Income',label:Text('Income'),icon:Icon(Icons.add)),
        ButtonSegment(value:'Investment',label:Text('Invest'),icon:Icon(Icons.trending_up)),
        ButtonSegment(value:'Transfer',label:Text('Transfer'),icon:Icon(Icons.swap_horiz)),
      ],selected:{type},onSelectionChanged:(s)=>setState(()=>type=s.first)),
      const SizedBox(height:12),
      TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Amount',prefixText:'₹ ',border:OutlineInputBorder())),
      const SizedBox(height:10),
      DropdownButtonFormField<String>(value:category,decoration:const InputDecoration(labelText:'Category',border:OutlineInputBorder()),items:store.categories.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>category=v!)),
      const SizedBox(height:10),
      if(store.accounts.isNotEmpty) DropdownButtonFormField<String>(value:accountId,decoration:const InputDecoration(labelText:'Account',border:OutlineInputBorder()),items:store.accounts.map((a)=>DropdownMenuItem(value:a['id'].toString(),child:Text('${a['name']} (${a['type']})'))).toList(),onChanged:(v)=>setState(()=>accountId=v!)),
      if(store.accounts.isEmpty) const Padding(padding:EdgeInsets.all(8),child:Text('Add an account first from Accounts.')),
      const SizedBox(height:10),
      TextField(controller:notes,decoration:const InputDecoration(labelText:'Notes (optional)',border:OutlineInputBorder())),
      const SizedBox(height:14),
      FilledButton.icon(onPressed:(){
        final value=double.tryParse(amount.text);
        if(value==null||value<=0||accountId.isEmpty)return;
        store.addTransaction({'id':DateTime.now().microsecondsSinceEpoch.toString(),'date':date.toIso8601String(),'type':type,'category':category,'amount':value,'accountId':accountId,'notes':notes.text.trim(),'direction':type=='Transfer'?'out':'in'});
        Navigator.pop(ctx);
      },icon:const Icon(Icons.check),label:const Text('Save transaction'))
    ]))
  )));
}
