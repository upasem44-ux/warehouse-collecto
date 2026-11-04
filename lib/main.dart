import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DawacomCollectorApp());
}

enum CurrencyType { yer, sar, usd }
enum ReceiptStatus { pending, draft, posted }

class CustomerRecord {
  final String code;
  final String name;
  final String area;
  final double balanceYer;

  const CustomerRecord({
    required this.code,
    required this.name,
    this.area = '',
    this.balanceYer = 0,
  });

  factory CustomerRecord.fromMap(Map<String, Object?> map) {
    return CustomerRecord(
      code: map['code'] as String,
      name: map['name'] as String,
      area: map['area'] as String? ?? '',
      balanceYer: (map['balance_yer'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ReceiptModel {
  final int? id;
  final String number;
  final String customerName;
  final double amount;
  final CurrencyType currency;
  final String method;
  final ReceiptStatus status;

  const ReceiptModel({
    this.id,
    required this.number,
    required this.customerName,
    required this.amount,
    required this.currency,
    required this.method,
    required this.status,
  });

  factory ReceiptModel.fromMap(Map<String, Object?> map) {
    return ReceiptModel(
      id: map['id'] as int?,
      number: map['number'] as String,
      customerName: map['customer_name'] as String,
      amount: (map['amount'] as num).toDouble(),
      currency: CurrencyType.values.firstWhere(
        (e) => e.name == map['currency'],
        orElse: () => CurrencyType.yer,
      ),
      method: map['method'] as String,
      status: ReceiptStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ReceiptStatus.pending,
      ),
    );
  }
}

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._();
  LocalDatabase._();
  Database? _db;

  Future<Database> get database async => _db ??= await _initDb();

  Future<Database> _initDb() async {
    final path = p.join(await getDatabasesPath(), 'dawacom_collector.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE customers (
            code TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            area TEXT DEFAULT '',
            balance_yer REAL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE receipts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            number TEXT UNIQUE NOT NULL,
            customer_name TEXT NOT NULL,
            amount REAL NOT NULL,
            currency TEXT NOT NULL,
            method TEXT NOT NULL,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.insert('customers', {
          'code': 'C-101',
          'name': 'صيدلية الأمل الحديثة',
          'area': 'صنعاء - التحرير',
          'balance_yer': 850000.0,
        });
        await db.insert('customers', {
          'code': 'C-102',
          'name': 'صيدلية النور المركزية',
          'area': 'صنعاء - حدة',
          'balance_yer': 420000.0,
        });
      },
    );
  }

  Future<List<CustomerRecord>> getCustomers() async {
    final db = await database;
    final rows = await db.query('customers');
    return rows.map(CustomerRecord.fromMap).toList();
  }

  Future<List<ReceiptModel>> getReceipts() async {
    final db = await database;
    final rows = await db.query('receipts', orderBy: 'id DESC');
    return rows.map(ReceiptModel.fromMap).toList();
  }

  Future<void> saveReceipt({
    required String customerName,
    required double amount,
    required CurrencyType currency,
    required String method,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final number = 'DWK-1001-${DateFormat('yyMMdd').format(now)}-${now.millisecondsSinceEpoch.toString().substring(8)}';

    await db.insert('receipts', {
      'number': number,
      'customer_name': customerName,
      'amount': amount,
      'currency': currency.name,
      'method': method,
      'status': ReceiptStatus.pending.name,
      'created_at': now.toIso8601String(),
    });
  }
}

final dbRepo = LocalDatabase.instance;

class DawacomCollectorApp extends StatelessWidget {
  const DawacomCollectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تحصيل دواكم',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B1F3A)),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int currentIndex = 0;
  final screens = const [CollectScreen(), HistoryScreen(), CustomersScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('محلات دواكم - التحصيل الميداني', style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: const Color(0xFF0B1F3A),
      ),
      body: screens[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => setState(() => currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'تحصيل'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'السندات'),
          NavigationDestination(icon: Icon(Icons.people), label: 'العملاء'),
        ],
      ),
    );
  }
}

class CollectScreen extends StatefulWidget {
  const CollectScreen({super.key});

  @override
  State<CollectScreen> createState() => _CollectScreenState();
}

class _CollectScreenState extends State<CollectScreen> {
  CustomerRecord? selectedCustomer;
  CurrencyType currency = CurrencyType.yer;
  String method = 'نقداً';
  final amountCtrl = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    amountCtrl.dispose();
    super.dispose();
  }

  void submitReceipt() async {
    if (selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار العميل')));
      return;
    }
    final amount = double.tryParse(amountCtrl.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل مبلغاً صحيحاً')));
      return;
    }

    setState(() => loading = true);
    await dbRepo.saveReceipt(
      customerName: selectedCustomer!.name,
      amount: amount,
      currency: currency,
      method: method,
    );
    setState(() {
      loading = false;
      selectedCustomer = null;
      amountCtrl.clear();
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ السند محلياً بنجاح')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('تسجيل سند قبض جديد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        ElevatedButton.icon(
          onPressed: () async {
            final list = await dbRepo.getCustomers();
            if (!context.mounted) return;
            final chosen = await showModalBottomSheet<CustomerRecord>(
              context: context,
              builder: (_) => Container(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: list.map((c) => ListTile(
                    title: Text(c.name),
                    subtitle: Text(c.code),
                    onTap: () => Navigator.pop(context, c),
                  )).toList(),
                ),
              ),
            );
            if (chosen != null) setState(() => selectedCustomer = chosen);
          },
          icon: const Icon(Icons.storefront),
          label: Text(selectedCustomer == null ? 'اختر الصيدلية / العميل' : selectedCustomer!.name),
        ),
        const SizedBox(height: 15),
        DropdownButtonFormField<CurrencyType>(
          value: currency,
          items: const [
            DropdownMenuItem(value: CurrencyType.yer, child: Text('ريال يمني')),
            DropdownMenuItem(value: CurrencyType.sar, child: Text('ريال سعودي')),
            DropdownMenuItem(value: CurrencyType.usd, child: Text('دولار أمريكي')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => currency = v);
          },
          decoration: const InputDecoration(labelText: 'العملة'),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'المبلغ'),
        ),
        const SizedBox(height: 25),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0B1F3A),
            foregroundColor: Colors.white,
          ),
          onPressed: loading ? null : submitReceipt,
          child: const Text('حفظ السند محلياً'),
        ),
      ],
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ReceiptModel>>(
      future: dbRepo.getReceipts(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        if (items.isEmpty) return const Center(child: Text('لا توجد سندات مسجلة'));
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, i) {
            final r = items[i];
            return ListTile(
              title: Text('${r.amount} ${r.currency.name.toUpperCase()} - ${r.customerName}'),
              subtitle: Text('رقم: ${r.number} | ${r.method}'),
              trailing: Text(
                r.status.name,
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            );
          },
        );
      },
    );
  }
}

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CustomerRecord>>(
      future: dbRepo.getCustomers(),
      builder: (context, snapshot) {
        final list = snapshot.data ?? [];
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final c = list[i];
            return ListTile(
              title: Text(c.name),
              subtitle: Text('الكود: ${c.code} | المنطقة: ${c.area}'),
              trailing: Text('${c.balanceYer} ر.ي'),
            );
          },
        );
      },
    );
  }
}
