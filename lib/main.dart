import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

// ============================================================
// 1. تشغيل التطبيق
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DawacomCollectorApp());
}

// ============================================================
// 2. الهوية البصرية
// ============================================================

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
  static const orange = Color(0xFFD18B22);
}

enum CurrencyType { yer, sar, usd }

enum ReceiptStatus { draft, pending, posted }

String money(num value) {
  return NumberFormat('#,##0.##', 'en_US').format(value);
}

String currencyShort(CurrencyType currency) {
  switch (currency) {
    case CurrencyType.yer:
      return 'ر.ي';
    case CurrencyType.sar:
      return 'ر.س';
    case CurrencyType.usd:
      return '\$';
  }
}

String currencyName(CurrencyType currency) {
  switch (currency) {
    case CurrencyType.yer:
      return 'ريال يمني';
    case CurrencyType.sar:
      return 'ريال سعودي';
    case CurrencyType.usd:
      return 'دولار أمريكي';
  }
}

String statusArabic(ReceiptStatus status) {
  switch (status) {
    case ReceiptStatus.draft:
      return 'مسودة';
    case ReceiptStatus.pending:
      return 'بانتظار المزامنة';
    case ReceiptStatus.posted:
      return 'مرحّل مركزياً';
  }
}

String formatDate(DateTime date) {
  return DateFormat('yyyy/MM/dd - hh:mm a').format(date);
}

// ============================================================
// 3. نماذج البيانات
// ============================================================

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

  Map<String, Object?> toMap() {
    return {
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
}

class ReceiptModel {
  final int? id;
  final String number;
  final String distributorCode;
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
  final String syncStatus;

  const ReceiptModel({
    this.id,
    required this.number,
    required this.distributorCode,
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
    this.syncStatus = 'pending',
  });

  factory ReceiptModel.fromMap(Map<String, Object?> map) {
    return ReceiptModel(
      id: map['id'] as int?,
      number: map['number'] as String,
      distributorCode: map['distributor_code'] as String? ?? '',
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
      createdAt: DateTime.tryParse(
            map['created_at'] as String? ?? '',
          ) ??
          DateTime.now(),
      syncStatus: map['sync_status'] as String? ?? 'pending',
    );
  }
}

// ============================================================
// 4. قاعدة البيانات SQLite
// ============================================================

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  Database? _db;

  static const String distributorCode = '1001';

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final databasePath = await getDatabasesPath();

    final path = p.join(
      databasePath,
      'dawacom_collector_v4.db',
    );

    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA journal_mode = WAL');
        await db.execute('PRAGMA synchronous = FULL');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE customers (
            code TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            area TEXT DEFAULT '',
            phone TEXT DEFAULT '',
            balance_yer REAL NOT NULL DEFAULT 0,
            balance_sar REAL NOT NULL DEFAULT 0,
            balance_usd REAL NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE receipts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            number TEXT NOT NULL UNIQUE,
            distributor_code TEXT NOT NULL,
            customer_code TEXT NOT NULL,
            customer_name TEXT NOT NULL,
            amount REAL NOT NULL,
            currency TEXT NOT NULL,
            method TEXT NOT NULL,
            network TEXT,
            transfer_ref TEXT,
            note TEXT,
            status TEXT NOT NULL DEFAULT 'pending',
            created_at TEXT NOT NULL,
            shift_date TEXT NOT NULL,
            sync_status TEXT NOT NULL DEFAULT 'pending',
            synced_at TEXT,
            FOREIGN KEY(customer_code)
              REFERENCES customers(code)
              ON UPDATE CASCADE
              ON DELETE RESTRICT
          )
        ''');

        await db.execute('''
          CREATE TABLE daily_sequences (
            distributor_code TEXT NOT NULL,
            shift_date TEXT NOT NULL,
            last_number INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY(distributor_code, shift_date)
          )
        ''');

        await _createIndexes(db);
      },
    );
  }

  Future<void> _createIndexes(DatabaseExecutor db) async {
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_receipts_customer
      ON receipts(customer_code)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_receipts_date
      ON receipts(shift_date)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_receipts_sync
      ON receipts(sync_status)
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_transfer_ref
      ON receipts(network, transfer_ref)
      WHERE method = 'حوالة'
        AND transfer_ref IS NOT NULL
        AND transfer_ref != ''
        AND status != 'draft'
    ''');
  }

  // ----------------------------------------------------------
  // العملاء
  // ----------------------------------------------------------

  Future<List<CustomerRecord>> getCustomers({
    String search = '',
  }) async {
    final db = await database;
    final term = search.trim();

    final rows = await db.query(
      'customers',
      where: term.isEmpty
          ? null
          : 'name LIKE ? OR code LIKE ? OR phone LIKE ?',
      whereArgs: term.isEmpty
          ? null
          : ['%$term%', '%$term%', '%$term%'],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows.map(CustomerRecord.fromMap).toList();
  }

  Future<CustomerRecord?> getCustomer(String code) async {
    final db = await database;

    final rows = await db.query(
      'customers',
      where: 'code = ?',
      whereArgs: [code],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return CustomerRecord.fromMap(rows.first);
  }

  Future<void> saveCustomer(CustomerRecord customer) async {
    final db = await database;

    await db.transaction((txn) async {
      final existing = await txn.query(
        'customers',
        columns: ['code'],
        where: 'code = ?',
        whereArgs: [customer.code.trim()],
        limit: 1,
      );

      if (existing.isEmpty) {
        await txn.insert(
          'customers',
          customer.toMap(),
        );
      } else {
        await txn.update(
          'customers',
          customer.toMap(),
          where: 'code = ?',
          whereArgs: [customer.code.trim()],
        );
      }
    });
  }

  // ----------------------------------------------------------
  // ترقيم السندات
  // ----------------------------------------------------------

  String _dateKey(DateTime date) {
    return DateFormat('yyyyMMdd').format(date);
  }

  Future<String> _nextReceiptNumber(
    Transaction txn,
    String date,
  ) async {
    final rows = await txn.query(
      'daily_sequences',
      where: 'distributor_code = ? AND shift_date = ?',
      whereArgs: [distributorCode, date],
      limit: 1,
    );

    int next;

    if (rows.isEmpty) {
      next = 1;

      await txn.insert('daily_sequences', {
        'distributor_code': distributorCode,
        'shift_date': date,
        'last_number': next,
      });
    } else {
      next = (rows.first['last_number'] as int) + 1;

      await txn.update(
        'daily_sequences',
        {'last_number': next},
        where: 'distributor_code = ? AND shift_date = ?',
        whereArgs: [distributorCode, date],
      );
    }

    return 'DWK-$distributorCode-$date-${next.toString().padLeft(4, '0')}';
  }

  // ----------------------------------------------------------
  // إصدار سند قبض
  // ----------------------------------------------------------

  Future<ReceiptModel> saveReceipt({
    required CustomerRecord customer,
    required double amount,
    required CurrencyType currency,
    required String method,
    String? network,
    String? transferRef,
    String? note,
  }) async {
    if (!amount.isFinite || amount <= 0) {
      throw Exception('المبلغ غير صحيح');
    }

    if ((amount * 100 - (amount * 100).round()).abs() > 0.000001) {
      throw Exception('المبلغ لا يقبل أكثر من منزلتين عشريتين');
    }

    if (method == 'حوالة') {
      if (network == null || network.trim().isEmpty) {
        throw Exception('حدد شبكة الحوالة');
      }

      if (transferRef == null || transferRef.trim().isEmpty) {
        throw Exception('رقم الحوالة مطلوب');
      }
    }

    final db = await database;
    final now = DateTime.now();
    final date = _dateKey(now);

    return db.transaction((txn) async {
      final customerRows = await txn.query(
        'customers',
        where: 'code = ?',
        whereArgs: [customer.code],
        limit: 1,
      );

      if (customerRows.isEmpty) {
        throw Exception('العميل غير موجود');
      }

      final savedCustomer =
          CustomerRecord.fromMap(customerRows.first);

      final number = await _nextReceiptNumber(txn, date);

      final map = {
        'number': number,
        'distributor_code': distributorCode,
        'customer_code': savedCustomer.code,
        'customer_name': savedCustomer.name,
        'amount': amount,
        'currency': currency.name,
        'method': method,
        'network': network?.trim(),
        'transfer_ref': transferRef?.trim(),
        'note': note?.trim(),
        'status': ReceiptStatus.pending.name,
        'created_at': now.toIso8601String(),
        'shift_date': date,
        'sync_status': 'pending',
        'synced_at': null,
      };

      final id = await txn.insert('receipts', map);

      return ReceiptModel.fromMap({
        ...map,
        'id': id,
      });
    });
  }

  // ----------------------------------------------------------
  // قراءة السندات
  // ----------------------------------------------------------

  Future<List<ReceiptModel>> getReceipts({
    String? customerCode,
    int limit = 1000,
  }) async {
    final db = await database;

    final rows = await db.query(
      'receipts',
      where: customerCode == null
          ? null
          : 'customer_code = ?',
      whereArgs: customerCode == null
          ? null
          : [customerCode],
      orderBy: 'id DESC',
      limit: limit,
    );

    return rows.map(ReceiptModel.fromMap).toList();
  }

  Future<List<ReceiptModel>> getPendingReceipts() async {
    final db = await database;

    final rows = await db.query(
      'receipts',
      where: "sync_status IN ('pending', 'failed') AND status != 'draft'",
      orderBy: 'id ASC',
    );

    return rows.map(ReceiptModel.fromMap).toList();
  }

  // ----------------------------------------------------------
  // الإجماليات
  // ----------------------------------------------------------

  Future<Map<String, double>> getLocalTotals() async {
    final db = await database;

    final rows = await db.rawQuery('''
      SELECT currency, SUM(amount) AS total
      FROM receipts
      WHERE status != 'draft'
      GROUP BY currency
    ''');

    final totals = <String, double>{
      'yer': 0,
      'sar': 0,
      'usd': 0,
    };

    for (final row in rows) {
      final key = row['currency'] as String?;

      if (key != null) {
        totals[key] =
            (row['total'] as num?)?.toDouble() ?? 0;
      }
    }

    return totals;
  }

  Future<int> getPendingCount() async {
    final db = await database;

    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM receipts
      WHERE sync_status IN ('pending', 'failed')
        AND status != 'draft'
    ''');

    return (rows.first['total'] as num).toInt();
  }
}

final dbRepo = LocalDatabase.instance;

// ============================================================
// 5. الرسائل العامة
// ============================================================

final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

void showMsg(
  String message, {
  bool error = false,
}) {
  messengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor:
          error ? AppColors.red : AppColors.navy,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

// ============================================================
// 6. التطبيق الرئيسي
// ============================================================

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
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(
              color: AppColors.border,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(
              color: AppColors.border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(
              color: AppColors.gold,
              width: 1.5,
            ),
          ),
        ),
      ),
      home: const CollectorShell(),
    );
  }
}

// ============================================================
// 7. التنقل الرئيسي
// ============================================================

class CollectorShell extends StatefulWidget {
  const CollectorShell({super.key});

  @override
  State<CollectorShell> createState() =>
      _CollectorShellState();
}

class _CollectorShellState extends State<CollectorShell> {
  int selectedIndex = 0;

  final titles = const [
    'الرئيسية',
    'العملاء وكشف الحساب',
    'تحصيل جديد',
    'سجل السندات',
    'صندوق العهدة',
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        onNavigate: (index) {
          setState(() => selectedIndex = index);
        },
      ),
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'محلات دواكم المركزية للأدوية',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFFD2DCE8),
              ),
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
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        backgroundColor: Colors.white,
        indicatorColor: AppColors.gold.withOpacity(0.25),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'العملاء',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'تحصيل',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'السندات',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'العهدة',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 8. عناصر واجهة مشتركة
// ============================================================

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13, top: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 55,
              color: AppColors.muted,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 9. لوحة التحكم
// ============================================================

class DashboardPage extends StatefulWidget {
  final ValueChanged<int> onNavigate;

  const DashboardPage({
    super.key,
    required this.onNavigate,
  });

  @override
  State<DashboardPage> createState() =>
      _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<_DashboardData> future;

  @override
  void initState() {
    super.initState();
    future = loadData();
  }

  Future<_DashboardData> loadData() async {
    final customers = await dbRepo.getCustomers();
    final receipts = await dbRepo.getReceipts();
    final totals = await dbRepo.getLocalTotals();
    final pending = await dbRepo.getPendingCount();

    return _DashboardData(
      customers: customers.length,
      receipts: receipts.length,
      totals: totals,
      pending: pending,
    );
  }

  Future<void> refresh() async {
    setState(() => future = loadData());
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: refresh,
      child: FutureBuilder<_DashboardData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return EmptyState(
              title: 'تعذر تحميل البيانات',
              subtitle: '${snapshot.error}',
            );
          }

          final data = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.navy,
                      AppColors.navyLight,
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'مرحباً بك في محطة التحصيل الميداني',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'إدارة عمليات التحصيل وسندات القبض.',
                      style: TextStyle(
                        color: Color(0xFFD1DBE8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${data.pending} سند بانتظار المزامنة',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.navy,
                      ),
                      onPressed: () => widget.onNavigate(2),
                      icon: const Icon(Icons.add),
                      label: const Text(
                        'إصدار سند قبض جديد',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionTitle(title: 'ملخص النشاط'),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'العملاء',
                      value: '${data.customers}',
                      icon: Icons.people_outline,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      title: 'السندات',
                      value: '${data.receipts}',
                      icon: Icons.receipt_long,
                      color: AppColors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              StatCard(
                title: 'السندات بانتظار المزامنة',
                value: '${data.pending}',
                icon: Icons.sync_problem_outlined,
                color: AppColors.orange,
              ),
              const SizedBox(height: 20),
              const SectionTitle(
                title: 'إجمالي التحصيل حسب العملة',
                subtitle: 'إجماليات محلية محفوظة على الجهاز',
              ),
              _CurrencySummary(totals: data.totals),
              const SizedBox(height: 20),
              const Text(
                'الأرصدة المركزية لا تتغير بمجرد تسجيل سند محلي. يلزم ترحيله واعتماده من الخادم.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  height: 1.6,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardData {
  final int customers;
  final int receipts;
  final int pending;
  final Map<String, double> totals;

  const _DashboardData({
    required this.customers,
    required this.receipts,
    required this.pending,
    required this.totals,
  });
}

class _CurrencySummary extends StatelessWidget {
  final Map<String, double> totals;

  const _CurrencySummary({
    required this.totals,
  });

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
        children: [
          _row('الريال اليمني', totals['yer'] ?? 0, 'ر.ي'),
          const Divider(height: 22),
          _row('الريال السعودي', totals['sar'] ?? 0, 'ر.س'),
          const Divider(height: 22),
          _row('الدولار الأمريكي', totals['usd'] ?? 0, '\$'),
        ],
      ),
    );
  }

  Widget _row(String title, double value, String symbol) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          '${money(value)} $symbol',
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 10. إدارة العملاء
// ============================================================

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() =>
      _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final searchController = TextEditingController();

  late Future<List<CustomerRecord>> future;

  @override
  void initState() {
    super.initState();
    future = dbRepo.getCustomers();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void reload() {
    setState(() {
      future = dbRepo.getCustomers(
        search: searchController.text,
      );
    });
  }

  Future<void> openCustomerForm([
    CustomerRecord? customer,
  ]) async {
    final result = await showDialog<CustomerRecord>(
      context: context,
      builder: (_) => CustomerFormDialog(
        customer: customer,
      ),
    );

    if (result == null) return;

    try {
      await dbRepo.saveCustomer(result);
      reload();
      showMsg('تم حفظ بيانات العميل');
    } catch (e) {
      showMsg('تعذر حفظ العميل: $e', error: true);
    }
  }

  Future<void> openStatement(
    CustomerRecord customer,
  ) async {
    final receipts = await dbRepo.getReceipts(
      customerCode: customer.code,
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (_) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'كشف حساب: ${customer.name}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${customer.code} • ${customer.area}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
                const Divider(height: 25),
                const Text(
                  'الأرصدة المحفوظة للعميل',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _balanceRow(
                  'الريال اليمني',
                  customer.balanceYer,
                  'ر.ي',
                ),
                _balanceRow(
                  'الريال السعودي',
                  customer.balanceSar,
                  'ر.س',
                ),
                _balanceRow(
                  'الدولار',
                  customer.balanceUsd,
                  '\$',
                ),
                const Divider(height: 25),
                const Text(
                  'سندات التحصيل المحلية',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: receipts.isEmpty
                      ? const EmptyState(
                          title: 'لا توجد سندات',
                          subtitle: 'لم تسجل تحصيلات لهذا العميل بعد.',
                        )
                      : ListView.builder(
                          itemCount: receipts.length,
                          itemBuilder: (context, index) {
                            final r = receipts[index];

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.receipt_long,
                                color: AppColors.navy,
                              ),
                              title: Text(
                                '${money(r.amount)} ${currencyShort(r.currency)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${r.number} • ${r.method}',
                              ),
                              trailing: const Icon(
                                Icons.pending_outlined,
                                color: AppColors.orange,
                                size: 19,
                              ),
                            );
                          },
                        ),
                ),
                const Text(
                  'كشف محلي فقط، ولا يمثل كشف الحساب المركزي في Life Ex Pro.',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _balanceRow(
    String title,
    double amount,
    String symbol,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          Text(
            '${money(amount)} $symbol',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: (_) => reload(),
                  decoration: const InputDecoration(
                    hintText: 'ابحث باسم العميل أو رقمه أو هاتفه',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              IconButton.filled(
                onPressed: () => openCustomerForm(),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.person_add_alt_1),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<CustomerRecord>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return EmptyState(
                  title: 'حدث خطأ',
                  subtitle: '${snapshot.error}',
                );
              }

              final customers = snapshot.data ?? [];

              if (customers.isEmpty) {
                return const EmptyState(
                  title: 'لا يوجد عملاء',
                  subtitle: 'اضغط زر الإضافة لتسجيل أول عميل.',
                  icon: Icons.people_outline,
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                ),
                itemCount: customers.length,
                itemBuilder: (context, index) {
                  final c = customers[index];

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(
                        color: AppColors.border,
                      ),
                    ),
                    child: ListTile(
                      onTap: () => openStatement(c),
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.navy,
                        child: Icon(
                          Icons.storefront,
                          color: AppColors.gold,
                        ),
                      ),
                      title: Text(
                        c.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        '${c.code} • ${c.area}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: IconButton(
                        onPressed: () => openCustomerForm(c),
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: AppColors.navy,
                        ),
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

// ============================================================
// 11. نموذج إضافة وتعديل عميل
// ============================================================

class CustomerFormDialog extends StatefulWidget {
  final CustomerRecord? customer;

  const CustomerFormDialog({
    super.key,
    this.customer,
  });

  @override
  State<CustomerFormDialog> createState() =>
      _CustomerFormDialogState();
}

class _CustomerFormDialogState
    extends State<CustomerFormDialog> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController code;
  late final TextEditingController name;
  late final TextEditingController area;
  late final TextEditingController phone;
  late final TextEditingController yer;
  late final TextEditingController sar;
  late final TextEditingController usd;

  @override
  void initState() {
    super.initState();

    final c = widget.customer;

    code = TextEditingController(text: c?.code ?? '');
    name = TextEditingController(text: c?.name ?? '');
    area = TextEditingController(text: c?.area ?? '');
    phone = TextEditingController(text: c?.phone ?? '');
    yer = TextEditingController(
      text: c?.balanceYer.toString() ?? '0',
    );
    sar = TextEditingController(
      text: c?.balanceSar.toString() ?? '0',
    );
    usd = TextEditingController(
      text: c?.balanceUsd.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    area.dispose();
    phone.dispose();
    yer.dispose();
    sar.dispose();
    usd.dispose();
    super.dispose();
  }

  double parse(TextEditingController c) {
    return double.tryParse(c.text.trim()) ?? 0;
  }

  Widget field(
    TextEditingController controller,
    String label, {
    bool numeric = false,
    bool enabled = true,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(
                decimal: true,
              )
            : TextInputType.text,
        inputFormatters: numeric
            ? [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[0-9.]'),
                ),
              ]
            : null,
        validator: (value) {
          if (required &&
              (value == null || value.trim().isEmpty)) {
            return 'هذا الحقل مطلوب';
          }

          if (numeric &&
              (value == null ||
                  double.tryParse(value.trim()) == null ||
                  double.parse(value.trim()) < 0)) {
            return 'أدخل رقماً صحيحاً';
          }

          return null;
        },
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.customer == null
            ? 'إضافة عميل جديد'
            : 'تعديل بيانات العميل',
      ),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                field(
                  code,
                  'كود العميل',
                  enabled: widget.customer == null,
                  required: true,
                ),
                field(
                  name,
                  'اسم العميل',
                  required: true,
                ),
                field(area, 'المنطقة'),
                field(phone, 'رقم الهاتف'),
                const Divider(height: 25),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'الأرصدة الافتتاحية',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                field(
                  yer,
                  'رصيد الريال اليمني',
                  numeric: true,
                ),
                field(
                  sar,
                  'رصيد الريال السعودي',
                  numeric: true,
                ),
                field(
                  usd,
                  'رصيد الدولار',
                  numeric: true,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.navy,
          ),
          onPressed: () {
            if (!formKey.currentState!.validate()) return;

            Navigator.pop(
              context,
              CustomerRecord(
                code: code.text.trim(),
                name: name.text.trim(),
                area: area.text.trim(),
                phone: phone.text.trim(),
                balanceYer: parse(yer),
                balanceSar: parse(sar),
                balanceUsd: parse(usd),
              ),
            );
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

// ============================================================
// 12. شاشة التحصيل
// ============================================================

class CollectPage extends StatefulWidget {
  const CollectPage({super.key});

  @override
  State<CollectPage> createState() => _CollectPageState();
}

class _CollectPageState extends State<CollectPage> {
  final amountController = TextEditingController();
  final transferController = TextEditingController();
  final noteController = TextEditingController();

  final formKey = GlobalKey<FormState>();

  List<CustomerRecord> customers = [];

  CustomerRecord? selectedCustomer;

  CurrencyType currency = CurrencyType.yer;

  String method = 'نقد';

  String network = 'الكريمي';

  final networks = const [
    'الكريمي',
    'النجم',
    'الامتياز',
    'يمن إكسبرس',
    'محفظتي',
    'جيب',
    'ون كاش',
    'أخرى',
  ];

  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    loadCustomers();
  }

  @override
  void dispose() {
    amountController.dispose();
    transferController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> loadCustomers() async {
    try {
      final result = await dbRepo.getCustomers();

      if (!mounted) return;

      setState(() {
        customers = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);
      showMsg('تعذر تحميل العملاء: $e', error: true);
    }
  }

  Future<void> pickCustomer() async {
    if (loading) return;

    if (customers.isEmpty) {
      showMsg('أضف العملاء أولاً', error: true);
      return;
    }

    final chosen = await showModalBottomSheet<CustomerRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(17),
                child: Text(
                  'اختر العميل',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final c = customers[index];

                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.navy,
                        child: Icon(
                          Icons.storefront,
                          color: AppColors.gold,
                        ),
                      ),
                      title: Text(c.name),
                      subtitle: Text(
                        '${c.code} • ${c.area}',
                      ),
                      onTap: () {
                        Navigator.pop(ctx, c);
                      },
                   
