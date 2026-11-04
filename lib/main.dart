import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DawacomCollectorApp());
}

// -----------------------------------------------------------------
// قاعدة البيانات والمستودع المحلي
// -----------------------------------------------------------------
enum CurrencyType { yer, sar, usd }
enum ReceiptStatus { pending, draft, posted }

class CustomerRecord {
  final String code;
  final String name;
  final String area;
  final String phone;
  final double balanceYer;
  final double balanceSar;
  final double balanceUsd;

  const CustomerRecord({
    required this.code,
    required this.name,
    this.area = '',
    this.phone = '',
    this.balanceYer = 0,
    this.balanceSar = 0,
    this.balanceUsd = 0,
  });

  factory CustomerRecord.fromMap(Map<String, Object?> map) {
    return CustomerRecord(
      code: map['code'] as String,
      name: map['name'] as String,
      area: map['area'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      balanceYer: (map['balance_yer'] as num?)?.toDouble() ?? 0,
      balanceSar: (map['balance_sar'] as num?)?.toDouble() ?? 0,
      balanceUsd: (map['balance_usd'] as num?)?.toDouble() ?? 0,
    );
  }
}

class Receipt {
  final int? id;
  final String number;
  final String customerCode;
  final String customerName;
  final double amount;
  final CurrencyType currency;
  final String method;
  final String? network;
  final String? transferRef;
  final String? note;
  final ReceiptStatus status;
  final DateTime createdAt;

  const Receipt({
    this.id,
    required this.number,
    required this.customerCode,
    required this.customerName,
    required this.amount,
    required this.currency,
    required this.method,
    this.network,
    this.transferRef,
    this.note,
    required this.status,
    required this.createdAt,
  });

  factory Receipt.fromMap(Map<String, Object?> map) {
    return Receipt(
      id: map['id'] as int?,
      number: map['number'] as String,
      customerCode: map['customer_code'] as String,
      customerName: map['customer_name'] as String,
      amount: (map['amount'] as num).toDouble(),
      currency: CurrencyType.values.firstWhere(
        (e) => e.name == map['currency'],
        orElse: () => CurrencyType.yer,
      ),
      method: map['method'] as String,
      network: map['network'] as String?,
      transferRef: map['transfer_ref'] as String?,
      note: map['note'] as String?,
      status: ReceiptStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ReceiptStatus.pending,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  DatabaseHelper._();
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
            phone TEXT DEFAULT '',
            balance_yer REAL DEFAULT 0,
            balance_sar REAL DEFAULT 0,
            balance_usd REAL DEFAULT 0,
            updated_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE receipts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            number TEXT UNIQUE NOT NULL,
            customer_code TEXT NOT NULL,
            customer_name TEXT NOT NULL,
            amount REAL NOT NULL,
            currency TEXT NOT NULL,
            method TEXT NOT NULL,
            network TEXT,
            transfer_ref TEXT,
            note TEXT,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        // عملاء افتراضيون للاختبار
        await db.insert('customers', {
          'code': 'C-101', 'name': 'صيدلية الأمل الحديثة', 'area': 'صنعاء - التحرير',
          'balance_yer': 850000, 'balance_sar': 2400, 'balance_usd': 350, 'updated_at': DateTime.now().toIso8601String()
        });
        await db.insert('customers', {
          'code': 'C-102', 'name': 'صيدلية النور المركزية', 'area': 'صنعاء - حدة',
          'balance_yer': 420000, 'balance_sar': 0, 'balance_usd': 0, 'updated_at': DateTime.now().toIso8601String()
        });
      },
    );
  }
}

class LocalRepository {
  Future<List<CustomerRecord>> getCustomers({String search = ''}) async {
    final db = await DatabaseHelper.instance.database;
    final term = search.trim();
    final rows = await db.query(
      'customers',
      where: term.isEmpty ? null : 'name LIKE ? OR code LIKE ?',
      whereArgs: term.isEmpty ? null : ['%$term%', '%$term%'],
    );
    return rows.map(CustomerRecord.fromMap).toList();
  }

  Future<List<Receipt>> getReceipts() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('receipts', orderBy: 'id DESC');
    return rows.map(Receipt.fromMap).toList();
  }

  Future<void> saveReceipt({
    required String customerCode,
    required String customerName,
    required double amount,
    required CurrencyType currency,
    required String method,
    String? network,
    String? transferRef,
    String? note,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final number = 'DWK-1001-${DateFormat('yyMMdd').format(now)}-${now.millisecondsSinceEpoch.toString().substring(8)}';

    await db.insert('receipts', {
      'number': number,
      'customer_code': customerCode,
      'customer_name': customerName,
      'amount': amount,
      'currency': currency.name,
      'method': method,
      'network': network,
      'transfer_ref': transferRef,
      'note': note,
      'status': 'pending',
      'created_at': now.toIso8601String(),
    });
  }
}

final repo = LocalRepository();

// -----------------------------------------------------------------
// التطبيق والواجهات
// -----------------------------------------------------------------
class DawacomCollectorApp extends StatelessWidget {
  const DawacomCollectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تحصيل دواكم',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B1F3A)),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: ShellPage(),
      ),
    );
  }
}

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int index = 0;
  final pages = [const CollectPage(), const HistoryPage(), const CustomersViewPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('محلات دواكم - التحصيل الميداني', style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: const Color(0xFF0B1F3A),
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'تحصيل'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'السندات'),
          NavigationDestination(icon: Icon(Icons.people), label: 'العملاء'),
        ],
      ),
    );
  }
}

// 1. صفحة تسجيل التحصيل
class CollectPage extends StatefulWidget {
  const CollectPage({super.key});

  @override
  State<CollectPage> createState() => _CollectPageState();
}

class _CollectPageState extends State<CollectPage> {
  CustomerRecord? selectedCustomer;
  CurrencyType currency = CurrencyType.yer;
  String method = 'نقداً';
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  bool saving = false;

  void save() async {
    if (selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار العميل')));
      return;
    }
    final amount = double.tryParse(amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل مبلغاً صحيحاً')));
      return;
    }

    setState(() => saving = true);
    await repo.saveReceipt(
      customerCode: selectedCustomer!.code,
      customerName: selectedCustomer!.name,
      amount: amount,
      currency: currency,
      method: method,
      note: noteController.text,
    );
    setState(() {
      saving = false;
      selectedCustomer = null;
      amountController.clear();
      noteController.clear();
    });
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ السند محلياً بنجاح')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('تسجيل سند قبض', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        ElevatedButton.icon(
          onPressed: () async {
            final customers = await repo.getCustomers();
            if(!context.mounted) return;
            final chosen = await showModalBottomSheet<CustomerRecord>(
              context: context,
              builder: (_) => Container(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: customers.map((c) => ListTile(
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
          onChanged: (v) => setState(() => currency = v!),
          decoration: const InputDecoration(labelText: 'العملة'),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'المبلغ'),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: noteController,
          decoration: const InputDecoration(labelText: 'ملاحظات'),
        ),
        const SizedBox(height: 25),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B1F3A), foregroundColor: Colors.white),
          onPressed: saving ? null : save,
          child: const Text('حفظ السند محلياً'),
        ),
      ],
    );
  }
}

// 2. صفحة السندات
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Receipt>>(
      future: repo.getReceipts(),
      builder: (context, snapshot) {
        final receipts = snapshot.data ?? [];
        if (receipts.isEmpty) return const Center(child: Text('لا توجد سندات مسجلة'));
        return ListView.builder(
          itemCount: receipts.length,
          itemBuilder: (context, i) {
            final r = receipts[i];
            return ListTile(
              title: Text('${r.amount} ${r.currency.name.toUpperCase()} - ${r.customerName}'),
              subtitle: Text('رقم: ${r.number} | ${r.method}'),
              trailing: Text(r.status, style: const TextStyle(color: Colors.green)),
            );
          },
        );
      },
    );
  }
}

// 3. صفحة العملاء
class CustomersViewPage extends StatelessWidget {
  const CustomersViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CustomerRecord>>(
      future: repo.getCustomers(),
      builder: (context, snapshot) {
        final customers = snapshot.data ?? [];
        return ListView.builder(
          itemCount: customers.length,
          itemBuilder: (context, i) {
            final c = customers[i];
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
