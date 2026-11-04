import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DawacomCollectorApp());
}

class AppColors {
  static const navy = Color(0xFF0B1F3A);
  static const navyLight = Color(0xFF142E50);
  static const gold = Color(0xFFE8B84D);
  static const background = Color(0xFFF4F6FA);
  static const white = Colors.white;
  static const text = Color(0xFF172B45);
  static const muted = Color(0xFF8290A3);
  static const green = Color(0xFF15966B);
  static const red = Color(0xFFD94B4B);
  static const border = Color(0xFFE7EBF1);
}

enum CurrencyType { yer, sar, usd }
enum ReceiptStatus { draft, pending, posted }

String money(num value) => NumberFormat('#,##0.##', 'en_US').format(value);

String currencyShort(CurrencyType c) {
  switch (c) {
    case CurrencyType.yer:
      return 'ر.ي';
    case CurrencyType.sar:
      return 'ر.س';
    case CurrencyType.usd:
      return '\$';
  }
}

String statusArabic(ReceiptStatus s) {
  switch (s) {
    case ReceiptStatus.draft:
      return 'مسودة';
    case ReceiptStatus.pending:
      return 'بانتظار المزامنة';
    case ReceiptStatus.posted:
      return 'مرحّل';
  }
}

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

  Map<String, Object?> toMap() => {
        'code': code.trim(),
        'name': name.trim(),
        'area': area.trim(),
        'phone': phone.trim(),
        'balance_yer': balanceYer,
        'balance_sar': balanceSar,
        'balance_usd': balanceUsd,
        'updated_at': DateTime.now().toIso8601String(),
      };
}

class ReceiptModel {
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

  const ReceiptModel({
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

  factory ReceiptModel.fromMap(Map<String, Object?> map) {
    return ReceiptModel(
      id: map['id'] as int?,
      number: map['number'] as String,
      customerCode: map['customer_code'] as String? ?? '',
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
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._();
  LocalDatabase._();
  Database? _db;

  Future<Database> get database async => _db ??= await _initDb();

  Future<Database> _initDb() async {
    final path = p.join(await getDatabasesPath(), 'dawacom_collector_v4.db');
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

        final now = DateTime.now().toIso8601String();
        await db.insert('customers', {
          'code': 'C-101',
          'name': 'صيدلية الأمل الحديثة',
          'area': 'صنعاء - التحرير',
          'phone': '777111222',
          'balance_yer': 850000.0,
          'balance_sar': 2400.0,
          'balance_usd': 350.0,
          'updated_at': now,
        });
        await db.insert('customers', {
          'code': 'C-102',
          'name': 'صيدلية النور المركزية',
          'area': 'صنعاء - حدة',
          'phone': '777333444',
          'balance_yer': 420000.0,
          'balance_sar': 0.0,
          'balance_usd': 0.0,
          'updated_at': now,
        });
      },
    );
  }

  Future<List<CustomerRecord>> getCustomers({String search = ''}) async {
    final db = await database;
    final term = search.trim();
    final rows = await db.query(
      'customers',
      where: term.isEmpty ? null : 'name LIKE ? OR code LIKE ? OR phone LIKE ?',
      whereArgs: term.isEmpty ? null : ['%$term%', '%$term%', '%$term%'],
      orderBy: 'name ASC',
    );
    return rows.map(CustomerRecord.fromMap).toList();
  }

  Future<void> saveCustomer(CustomerRecord customer) async {
    final db = await database;
    await db.insert(
      'customers',
      customer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ReceiptModel>> getReceipts({String? customerCode}) async {
    final db = await database;
    final rows = await db.query(
      'receipts',
      where: customerCode == null ? null : 'customer_code = ?',
      whereArgs: customerCode == null ? null : [customerCode],
      orderBy: 'id DESC',
    );
    return rows.map(ReceiptModel.fromMap).toList();
  }

  Future> getLocalTotals() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT currency, SUM(amount) AS total
      FROM receipts
      WHERE status != 'draft'
      GROUP BY currency
    ''');
    final totals = <String, double>{'yer': 0, 'sar': 0, 'usd': 0};
    for (final row in rows) {
      final key = row['currency'] as String?;
      if (key != null) {
        totals[key] = (row['total'] as num?)?.toDouble() ?? 0;
      }
    }
    return totals;
  }

  Future<ReceiptModel> saveReceipt({
    required CustomerRecord customer,
    required double amount,
    required CurrencyType currency,
    required String method,
    String? network,
    String? transferRef,
    String? note,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final seq = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    final number = 'DWK-1001-${DateFormat('yyyyMMdd').format(now)}-$seq';

    final map = {
      'number': number,
      'customer_code': customer.code,
      'customer_name': customer.name,
      'amount': amount,
      'currency': currency.name,
      'method': method,
      'network': network,
      'transfer_ref': transferRef,
      'note': note,
      'status': ReceiptStatus.pending.name,
      'created_at': now.toIso8601String(),
    };

    final id = await db.insert('receipts', map);
    return ReceiptModel.fromMap({...map, 'id': id});
  }
}

final dbRepo = LocalDatabase.instance;
final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

void showMsg(String text, {bool error = false}) {
  messengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(text),
      backgroundColor: error ? AppColors.red : AppColors.navy,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class DawacomCollectorApp extends StatelessWidget {
  const DawacomCollectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تحصيل دواكم',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.navy,
          primary: AppColors.navy,
          secondary: AppColors.gold,
          surface: AppColors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.navy,
          foregroundColor: AppColors.white,
          elevation: 0,
        ),
      ),
      home: const CollectorShell(),
    );
  }
}

class CollectorShell extends StatefulWidget {
  const CollectorShell({super.key});

  @override
  State<CollectorShell> createState() => _CollectorShellState();
}

class _CollectorShellState extends State<CollectorShell> {
  int selectedIndex = 0;

  final List<String> titles = const [
    'الرئيسية',
    'العملاء وكشف الحساب',
    'تحصيل جديد',
    'سجل السندات',
    'صندوق العهدة',
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(onNavigate: (i) => setState(() => selectedIndex = i)),
      const CustomersPage(),
      const CollectPage(),
      const HistoryPage(),
      const CashDrawerPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titles[selectedIndex],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              'محلات دواكم المركزية للأدوية',
              style: TextStyle(fontSize: 11, color: Color(0xFFD2DCE8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: pages[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => setState(() => selectedIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.gold.withOpacity(0.25),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'العملاء'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'تحصيل'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'السندات'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'العهدة'),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const DashboardPage({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        dbRepo.getCustomers(),
        dbRepo.getReceipts(),
        dbRepo.getLocalTotals(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data as List?;
        if (data == null) return const Center(child: Text('خطأ في تحميل البيانات'));

        final customers = data[0] as List<CustomerRecord>;
        final receipts = data[1] as List<ReceiptModel>;
        final totals = data[2] as Map<String, double>;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.navy, AppColors.navyLight],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('مرحباً بك في محطة التحصيل الميداني',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('إجمالي السندات المحفوظة: ${receipts.length} سند',
                      style: const TextStyle(color: AppColors.gold, fontSize: 13)),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.navy,
                    ),
                    onPressed: () => onNavigate(2),
                    icon: const Icon(Icons.add),
                    label: const Text('إصدار سند قبض جديد', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _StatCard(title: 'العملاء المسجلون', value: '${customers.length}', icon: Icons.storefront, color: Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(title: 'سندات اليوم', value: '${receipts.length}', icon: Icons.receipt_long, color: AppColors.green)),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ملخص التحصيل المحلي حسب العملة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const Divider(height: 22),
                  _currencyRow('ريال يمني', totals['yer'] ?? 0, 'ر.ي'),
                  const SizedBox(height: 10),
                  _currencyRow('ريال سعودي', totals['sar'] ?? 0, 'ر.س'),
                  const SizedBox(height: 10),
                  _currencyRow('دولار أمريكي', totals['usd'] ?? 0, '\$'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _currencyRow(String label, double amount, String symbol) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted)),
        Text('${money(amount)} $symbol',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 15)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final searchCtrl = TextEditingController();

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  void openStatement(CustomerRecord customer) async {
    final receipts = await dbRepo.getReceipts(customerCode: customer.code);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('كشف حساب: ${customer.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('الكود: ${customer.code} • ${customer.area}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              const Divider(height: 24),
              const Text('الأرصدة الدفترية:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _balBox('يمني', '${money(customer.balanceYer)} ر.ي'),
                  _balBox('سعودي', '${money(customer.balanceSar)} ر.س'),
                  _balBox('دولار', '${money(customer.balanceUsd)} \$'),
                ],
              ),
              const SizedBox(height: 18),
              const Text('سندات التحصيل المسجلة للعميل:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: receipts.isEmpty
                    ? const Center(child: Text('لا توجد سندات مسجلة لهذا العميل'))
                    : ListView.builder(
                        itemCount: receipts.length,
                        itemBuilder: (context, i) {
                          final r = receipts[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('${money(r.amount)} ${currencyShort(r.currency)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${r.number} • ${r.method}'),
                              trailing: Text(statusArabic(r.status),
                                  style: const TextStyle(color: AppColors.green, fontSize: 12)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _balBox(String title, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'ابحث باسم الصيدلية أو الكود...',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<CustomerRecord>>(
            future: dbRepo.getCustomers(search: searchCtrl.text),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snapshot.data ?? [];
              if (list.isEmpty) {
                return const Center(child: Text('لا يوجد عملاء'));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final c = list[i];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: ListTile(
                      onTap: () => openStatement(c),
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.navy,
                        child: Icon(Icons.storefront, color: AppColors.gold),
                      ),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('كود: ${c.code} • ${c.area}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${money(c.balanceYer)} ر.ي',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
                          const Text('كشف الحساب ⬅', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class CollectPage extends StatefulWidget {
  const CollectPage({super.key});

  @override
  State<CollectPage> createState() => _CollectPageState();
}

class _CollectPageState extends State<CollectPage> {
  CustomerRecord? selectedCustomer;
  CurrencyType currency = CurrencyType.yer;
  String method = 'نقداً';
  String network = 'الكريمي';

  final amountCtrl = TextEditingController();
  final transferCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  bool saving = false;

  final networks = const ['الكريمي', 'النجم', 'الامتياز', 'يمن إكسبرس', 'أخرى'];

  @override
  void dispose() {
    amountCtrl.dispose();
    transferCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  void pickCustomer() async {
    final customers = await dbRepo.getCustomers();
    if (!mounted) return;

    final chosen = await showModalBottomSheet<CustomerRecord>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('اختر الصيدلية / العميل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: customers.length,
                builder: (_, i) {
                  final c = customers[i];
                  return ListTile(
                    leading: const Icon(Icons.storefront, color: AppColors.navy),
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${c.code} • الرصيد: ${money(c.balanceYer)} ر.ي'),
                    onTap: () => Navigator.pop(ctx, c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (chosen != null) {
      setState(() => selectedCustomer = chosen);
    }
  }

  void submit() async {
    if (selectedCustomer == null) {
      showMsg('الرجاء اختيار الصيدلية أولاً', error: true);
      return;
    }
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      showMsg('أدخل مبلغ تحصيل صحيح أكبر من صفر', error: true);
      return;
    }

    setState(() => saving = true);
    try {
      final receipt = await dbRepo.saveReceipt(
        customer: selectedCustomer!,
        amount: amount,
        currency: currency,
        method: method,
        network: method == 'حوالة' ? network : null,
        transferRef: method == 'حوالة' ? transferCtrl.text.trim() : null,
        note: noteCtrl.text.trim(),
      );

      setState(() {
        saving = false;
        selectedCustomer = null;
        amountCtrl.clear();
        transferCtrl.clear();
        noteCtrl.clear();
      });

      showMsg('تم حفظ السند رقم ${receipt.number} بنجاح');
    } catch (e) {
      setState(() => saving = false);
      showMsg('خطأ في الحفظ: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InkWell(
          onTap: pickCustomer,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront, color: AppColors.navy),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedCustomer == null
                        ? 'اضغط لاختيار الصيدلية / العميل...'
                        : '${selectedCustomer!.name} (${selectedCustomer!.code})',
                    style: TextStyle(
                      fontWeight: selectedCustomer == null ? FontWeight.normal : FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<CurrencyType>(
          value: currency,
          decoration: const InputDecoration(labelText: 'عملة السند', prefixIcon: Icon(Icons.currency_exchange)),
          items: const [
            DropdownMenuItem(value: CurrencyType.yer, child: Text('ريال يمني (ر.ي)')),
            DropdownMenuItem(value: CurrencyType.sar, child: Text('ريال سعودي (ر.س)')),
            DropdownMenuItem(value: CurrencyType.usd, child: Text('دولار أمريكي (\$)')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => currency = v);
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: const InputDecoration(labelText: 'المبلغ المستلم', prefixIcon: Icon(Icons.payments_outlined)),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('نقداً'),
                value: 'نقداً',
                groupValue: method,
                onChanged: (v) => setState(() => method = v!),
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('حوالة'),
                value: 'حوالة',
                groupValue: method,
                onChanged: (v) => setState(() => method = v!),
              ),
            ),
          ],
        ),
        if (method == 'حوالة') ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: network,
            decoration: const InputDecoration(labelText: 'شبكة التحويل'),
            items: networks.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => network = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: transferCtrl,
            decoration: const InputDecoration(labelText: 'رقم إشعار الحوالة', prefixIcon: Icon(Icons.numbers)),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)', prefixIcon: Icon(Icons.note_alt_outlined)),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: saving ? null : submit,
            icon: const Icon(Icons.save_outlined),
            label: Text(saving ? 'جاري الحفظ...' : 'حفظ واعتماد السند محلياً',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ReceiptModel>>(
      future: dbRepo.getReceipts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const Center(child: Text('لا توجد سندات مسجلة حتى الآن'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final r = list[i];
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.navy,
                  child: Icon(Icons.receipt, color: AppColors.gold),
                ),
                title: Text('${money(r.amount)} ${currencyShort(r.currency)} — ${r.customerName}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('سند: ${r.number}\nالطريقة: ${r.method}'),
                isThreeLine: true,
                trailing: Text(statusArabic(r.status),
                    style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            );
          },
        );
      },
    );
  }
}

class CashDrawerPage extends StatelessWidget {
  const CashDrawerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder>(
      future: dbRepo.getLocalTotals(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final totals = snapshot.data ?? {'yer': 0, 'sar': 0, 'usd': 0};
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('إجمالي العهدة الميدانية المحصلة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const Divider(height: 28),
                  _row('الريال اليمني', totals['yer'] ?? 0, 'ر.ي'),
                  const Divider(height: 24),
                  _row('الريال السعودي', totals['sar'] ?? 0, 'ر.س'),
                  const Divider(height: 24),
                  _row('الدولار الأمريكي', totals['usd'] ?? 0, '\$'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(String title, double val, String symbol) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, color: AppColors.muted)),
        Text('${money(val)} $symbol',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy)),
      ],
    );
  }
}
