import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'database_helper.dart';
import 'receipt_repository.dart';
import 'customers_page.dart';
import 'collect_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const DawacomCollectorApp());
}

final repository = ReceiptRepository();

final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

void showMessage(String message, {bool error = false}) {
  messengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(message, textDirection: TextDirection.rtl),
      backgroundColor: error ? const Color(0xFFD94B4B) : const Color(0xFF0B1F3A),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

String money(num value) => NumberFormat('#,##0.##', 'en_US').format(value);

class DawacomCollectorApp extends StatelessWidget {
  const DawacomCollectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تحصيل دواكم',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      locale: const Locale('ar'),
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B1F3A),
          primary: const Color(0xFF0B1F3A),
          secondary: const Color(0xFFE8B84D),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B1F3A),
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: CollectorShell(),
      ),
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

  final List<Widget> pages = const [
    DashboardPage(),
    CustomersPage(),
    CollectPage(),
    HistoryPage(),
    CashDrawerPage(),
  ];

  final List<String> titles = [
    'الرئيسية',
    'العملاء',
    'تحصيل جديد',
    'السندات',
    'العهدة',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titles[selectedIndex], style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            const Text('محلات دواكم المركزية للأدوية', style: TextStyle(fontSize: 10, color: Color(0xFFD2DCE8))),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => setState(() => selectedIndex = index),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE8B84D).withOpacity(0.20),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'العملاء'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'تحصيل'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'السندات'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'العهدة'),
        ],
      ),
    );
  }
}

// ============================================================
// شاشة الرئيسية (Dashboard)
// ============================================================

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        repository.getCustomers(),
        repository.getReceipts(limit: 100),
        repository.getLocalTotals(),
        repository.getPendingCount(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data as List?;
        if (data == null) return const Center(child: Text('خطأ في تحميل البيانات'));

        final customers = data[0] as List<CustomerRecord>;
        final receipts = data[1] as List<Receipt>;
        final totals = data[2] as Map<String, double>;
        final pending = data[3] as int;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0B1F3A), Color(0xFF142E50)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('مرحباً بك في محطة التحصيل', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 7),
                  const Text('نظام التحصيل الميداني • الموزع #1001', style: TextStyle(color: Color(0xFFD1DBE8), fontSize: 12)),
                  const SizedBox(height: 15),
                  Text('$pending سند بانتظار المزامنة المركزية', style: const TextStyle(color: Color(0xFFE8B84D), fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('ملخص اليوم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _StatCard(title: 'العملاء', value: '${customers.length}', icon: Icons.people, color: Colors.blue)),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(title: 'السندات', value: '${receipts.length}', icon: Icons.receipt, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 20),
            const Text('أحدث السندات المسجلة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (receipts.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('لا توجد سندات بعد')))
            else
              ...receipts.take(5).map((r) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('${money(r.amount)} ${r.currency.name.toUpperCase()}'),
                      subtitle: Text('رقم السند: ${r.number} - العميل: ${r.customerCode}'),
                      trailing: Text(r.status.name),
                    ),
                  )),
          ],
        );
      },
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
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFE7EBF1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

// ============================================================
// شاشة سجل السندات (HistoryPage)
// ============================================================

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Receipt>>(
      future: repository.getReceipts(limit: 500),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final receipts = snapshot.data ?? [];
        if (receipts.isEmpty) {
          return const Center(child: Text('لا توجد سندات مسجلة في السجل'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: receipts.length,
          itemBuilder: (context, index) {
            final r = receipts[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text('${money(r.amount)} ${r.currency.name.toUpperCase()}'),
                subtitle: Text('رقم: ${r.number}\nالعميل: ${r.customerName}'),
                isThreeLine: true,
                trailing: Text(r.status.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================================
// شاشة صندوق العهدة (CashDrawerPage)
// ============================================================

class CashDrawerPage extends StatelessWidget {
  const CashDrawerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder>(
      future: repository.getLocalTotals(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final totals = snapshot.data ?? {'yer': 0, 'sar': 0, 'usd': 0};
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('صندوق العهدة الميدانية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFE7EBF1))),
              child: Column(
                children: [
                  _drawerRow('ريال يمني', totals['yer'] ?? 0, 'ر.ي'),
                  const Divider(height: 20),
                  _drawerRow('ريال سعودي', totals['sar'] ?? 0, 'ر.س'),
                  const Divider(height: 20),
                  _drawerRow('دولار أمريكي', totals['usd'] ?? 0, '\$'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _drawerRow(String title, double val, String symbol) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        Text('${money(val)} $symbol', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
