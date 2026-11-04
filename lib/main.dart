import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DawacomCollectorApp());
}

class AppColors {
  static const navy = Color(0xFF0B1F3A);
  static const gold = Color(0xFFE8B84D);
  static const background = Color(0xFFF4F6FA);
  static const white = Colors.white;
  static const text = Color(0xFF172B45);
  static const muted = Color(0xFF8290A3);
  static const green = Color(0xFF15966B);
  static const red = Color(0xFFD94B4B);
  static const border = Color(0xFFE7EBF1);
}

class DawacomCollectorApp extends StatelessWidget {
  const DawacomCollectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تحصيل دواكم',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.navy),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: SimpleHomeView(),
      ),
    );
  }
}

class SimpleHomeView extends StatefulWidget {
  const SimpleHomeView({super.key});

  @override
  State<SimpleHomeView> createState() => _SimpleHomeViewState();
}

class _SimpleHomeViewState extends State<SimpleHomeView> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardTab(),
    CollectTab(),
    HistoryTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        title: const Text(
          'محلات دواكم - التحصيل الميداني',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            label: 'تحصيل جديد',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'السندات',
          ),
        ],
      ),
    );
  }
}

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحباً بك، الموزع #1001',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'نظام تحصيل المستودعات الميداني جاهز للعمل.',
                  style: TextStyle(color: AppColors.gold, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CollectTab extends StatefulWidget {
  const CollectTab({super.key});

  @override
  State<CollectTab> createState() => _CollectTabState();
}

class _CollectTabState extends State<CollectTab> {
  final _amountController = TextEditingController();
  final _customerController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  Future<void> _saveReceipt() async {
    final customer = _customerController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    if (customer.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال اسم العميل ومبلغ صحيح'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final dbPath = await getDatabasesPath();
      final dbFile = path.join(dbPath, 'dawacom_collector.db');

      final db = await openDatabase(
        dbFile,
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE receipts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              customer TEXT NOT NULL,
              amount REAL NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
        },
      );

      await db.insert('receipts', {
        'customer': customer,
        'amount': amount,
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.close();

      _customerController.clear();
      _amountController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ السند محلياً بنجاح'),
          backgroundColor: AppColors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ أثناء الحفظ: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          const Text(
            'تسجيل سند قبض محلي',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _customerController,
            decoration: const InputDecoration(
              labelText: 'اسم الصيدلية / العميل',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: const InputDecoration(
              labelText: 'المبلغ بالريال اليمني',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
              ),
              onPressed: _loading ? null : _saveReceipt,
              child: _loading
                  .?(const CircularProgressIndicator(color: Colors.white))
                  : const Text('حفظ السند', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  Future<List>> _fetchReceipts() async {
    try {
      final dbPath = await getDatabasesPath();
      final dbFile = path.join(dbPath, 'dawacom_collector.db');
      final db = await openDatabase(dbFile);
      final results = await db.query('receipts', orderBy: 'id DESC');
      await db.close();
      return results;
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List>>(
      future: _fetchReceipts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('لا توجد سندات مسجلة بعد'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            return Card(
              child: ListTile(
                title: Text('${item['customer']}'),
                subtitle: Text('المبلغ: ${item['amount']} ر.ي'),
                trailing: Text(
                  '${item['created_at'].toString().substring(0, 10)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
