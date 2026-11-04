import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'receipt_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const DawacomCollectorApp());
}

// ============================================================================
// 1. EXTENSIONS & DOMAIN HELPERS
// ============================================================================

extension CurrencyExtension on CurrencyType {
  String get code {
    switch (this) {
      case CurrencyType.yer: return 'ر.ي';
      case CurrencyType.sar: return 'ر.س';
      case CurrencyType.usd: return '\$';
    }
  }

  String get label {
    switch (this) {
      case CurrencyType.yer: return 'ريال يمني';
      case CurrencyType.sar: return 'ريال سعودي';
      case CurrencyType.usd: return 'دولار أمريكي';
    }
  }

  String get subUnitLabel {
    switch (this) {
      case CurrencyType.yer: return 'فلس';
      case CurrencyType.sar: return 'هللة';
      case CurrencyType.usd: return 'سنت';
    }
  }
}

class Customer {
  final String code;
  final String name;
  final String area;
  final String phone;
  final double bookBalanceYER;
  final double bookBalanceSAR;
  final double bookBalanceUSD;

  const Customer({
    required this.code,
    required this.name,
    required this.area,
    required this.phone,
    required this.bookBalanceYER,
    required this.bookBalanceSAR,
    required this.bookBalanceUSD,
  });

  double getBookBalance(CurrencyType c) {
    switch (c) {
      case CurrencyType.yer: return bookBalanceYER;
      case CurrencyType.sar: return bookBalanceSAR;
      case CurrencyType.usd: return bookBalanceUSD;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Customer && runtimeType == other.runtimeType && code == other.code;

  @override
  int get hashCode => code.hashCode;
}

class TafqeetEngine {
  static const List<String> _ones = [
    '', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة',
    'عشرة', 'أحد عشر', 'اثنا عشر', 'ثلاثة عشر', 'أربعة عشر', 'خمسة عشر', 'ستة عشر',
    'سبعة عشر', 'ثمانية عشر', 'تسعة عشر'
  ];

  static const List<String> _tens = [
    '', '', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون', 'ستون', 'سبعون', 'ثمانون', 'تسعون'
  ];

  static const List<String> _hundreds = [
    '', 'مائة', 'مائتان', 'ثلاثمائة', 'أربعمائة', 'خمسمائة', 'ستمائة', 'سبعمائة', 'ثمانمائة', 'تسعمائة'
  ];

  static String _convertThreeDigits(int n, {bool isScale = false}) {
    if (n == 0) return '';
    String res = '';
    int h = n ~/ 100;
    int rem = n % 100;

    if (h > 0) {
      if (h == 2 && rem == 0 && isScale) {
        res += 'مائتا';
      } else {
        res += _hundreds[h];
      }
    }
    if (rem > 0) {
      if (res.isNotEmpty) res += ' و';
      if (rem < 20) {
        res += _ones[rem];
      } else {
        int t = rem ~/ 10;
        int u = rem % 10;
        if (u > 0) {
          res += '${_ones[u]} و${_tens[t]}';
        } else {
          res += _tens[t];
        }
      }
    }
    return res;
  }

  static String _formatScale(int val, String singular, String dual, String plural, String accusative) {
    if (val == 1) return singular;
    if (val == 2) return dual;

    // المئات الصريحة (100، 200، 300...) تأخذ المفرد: مائتا ألف / مائة مليون
    if (val % 100 == 0) {
      return '${_convertThreeDigits(val, isScale: true)} $singular';
    }

    if (val > 100 && (val % 100) == 2) {
      final hundredsOnly = (val ~/ 100) * 100;
      return '${_convertThreeDigits(hundredsOnly, isScale: true)} $singular و$dual';
    }

    final rem100 = val % 100;
    if (rem100 >= 3 && rem100 <= 10) {
      return '${_convertThreeDigits(val, isScale: true)} $plural';
    }
    return '${_convertThreeDigits(val, isScale: true)} $accusative';
  }

  static String convert(double amount, CurrencyType currency) {
    if (amount <= 0) return 'صفر ${currency.label} لا غير';

    final double normalized = double.parse(amount.toStringAsFixed(2));
    final int integerPart = normalized.floor();
    final int decimalPart = ((normalized - integerPart) * 100).round();

    int billions = integerPart ~/ 1000000000;
    int millions = (integerPart % 1000000000) ~/ 1000000;
    int thousands = (integerPart % 1000000) ~/ 1000;
    int remaining = integerPart % 1000;

    List<String> parts = [];

    if (billions > 0) parts.add(_formatScale(billions, 'مليار', 'ملياران', 'مليارات', 'ملياراً'));
    if (millions > 0) parts.add(_formatScale(millions, 'مليون', 'مليونان', 'ملايين', 'مليوناً'));
    if (thousands > 0) parts.add(_formatScale(thousands, 'ألف', 'ألفان', 'آلاف', 'ألفاً'));
    if (remaining > 0) parts.add(_convertThreeDigits(remaining));

    String mainText = parts.isEmpty ? 'صفر' : parts.join(' و');
    String result = 'فقط $mainText ${currency.label}';

    if (decimalPart > 0) {
      result += ' و${_convertThreeDigits(decimalPart)} ${currency.subUnitLabel}';
    }

    return '$result لا غير';
  }
}

// ============================================================================
// 2. THEME & UTILITIES
// ============================================================================

const navy = Color(0xFF0F243E);
const blue = Color(0xFF2563EB);
const bg = Color(0xFFF8FAFC);
const ink = Color(0xFF0F172A);
const muted = Color(0xFF64748B);
const green = Color(0xFF10B981);
const amber = Color(0xFFF59E0B);
const red = Color(0xFFEF4444);
const borderCol = Color(0xFFE2E8F0);

String _fmt(num n) {
  final formatter = NumberFormat('#,##0.##', 'en_US');
  return formatter.format(n);
}

String _normalizeDigits(String input) {
  const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩', '٫'];
  const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.'];
  for (int i = 0; i < arabic.length; i++) {
    input = input.replaceAll(arabic[i], english[i]);
  }
  return input.replaceAll(',', '').trim();
}

class DawacomCollectorApp extends StatelessWidget {
  const DawacomCollectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'دواكم - نظام التحصيل',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(seedColor: blue, brightness: Brightness.light),
        fontFamily: 'sans-serif',
      ),
      home: const CollectorShell(),
    );
  }
}

// ============================================================================
// 3. MAIN SHELL
// ============================================================================

class CollectorShell extends StatefulWidget {
  const CollectorShell({super.key});

  @override
  State<CollectorShell> createState() => _CollectorShellState();
}

class _CollectorShellState extends State<CollectorShell> {
  int _selectedIndex = 0;
  final ReceiptRepository _repository = ReceiptRepository();

  static const List<Customer> _seedCustomers = [
    Customer(
      code: 'C-101',
      name: 'صيدلية الأمل الحديثة',
      area: 'صنعاء - التحرير',
      phone: '777000111',
      bookBalanceYER: 850000,
      bookBalanceSAR: 2400,
      bookBalanceUSD: 350,
    ),
    Customer(
      code: 'C-102',
      name: 'صيدلية النور المركزية',
      area: 'صنعاء - حدة',
      phone: '771234567',
      bookBalanceYER: 420000,
      bookBalanceSAR: 0,
      bookBalanceUSD: 0,
    ),
    Customer(
      code: 'C-103',
      name: 'صيدلية الحياة التخصصية',
      area: 'صنعاء - شميلة',
      phone: '773334445',
      bookBalanceYER: 1250000,
      bookBalanceSAR: 5600,
      bookBalanceUSD: 1200,
    ),
    Customer(
      code: 'C-104',
      name: 'صيدلية المستقبل المتميزة',
      area: 'صنعاء - الحصبة',
      phone: '775556667',
      bookBalanceYER: 95000,
      bookBalanceSAR: 450,
      bookBalanceUSD: 0,
    ),
    Customer(
      code: 'C-105',
      name: 'مستوصف ابن سينا الطبي',
      area: 'صنعاء - مذبح',
      phone: '778889990',
      bookBalanceYER: 0,
      bookBalanceSAR: 0,
      bookBalanceUSD: 0,
    ),
  ];

  List<Customer> _customers = [];
  List<Receipt> _receipts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initDatabaseAndLoad();
  }

  Future<void> _initDatabaseAndLoad() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM customers'),
      ) ?? 0;

      if (count == 0) {
        await _repository.saveCustomers(
          _seedCustomers.map((c) => {
            'code': c.code,
            'name': c.name,
            'area': c.area,
            'phone': c.phone,
            'balance_yer': c.bookBalanceYER,
            'balance_sar': c.bookBalanceSAR,
            'balance_usd': c.bookBalanceUSD,
          }).toList(),
        );
      }

      await _refreshData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'فشل تهيئة قاعدة البيانات المحلية: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final customerRows = await db.query('customers', orderBy: 'code ASC');
      final receiptsList = await _repository.getReceipts();

      if (!mounted) return;
      setState(() {
        _customers = customerRows.map((r) => Customer(
          code: r['code'] as String,
          name: r['name'] as String,
          area: r['area'] as String? ?? '',
          phone: r['phone'] as String? ?? '',
          bookBalanceYER: (r['balance_yer'] as num?)?.toDouble() ?? 0.0,
          bookBalanceSAR: (r['balance_sar'] as num?)?.toDouble() ?? 0.0,
          bookBalanceUSD: (r['balance_usd'] as num?)?.toDouble() ?? 0.0,
        )).toList();
        _receipts = receiptsList;
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذر قراءة البيانات: $e';
        _isLoading = false;
      });
    }
  }

  double _getPendingTotal(String customerCode, CurrencyType currency) {
    return _receipts
        .where((r) => r.customerCode == customerCode && r.currency == currency && r.status == ReceiptStatus.pending)
        .fold(0.0, (s, r) => s + r.amount);
  }

  Future<void> _handleReceiptSaved(Receipt r) async {
    await _refreshData();
    if (!mounted) return;
    setState(() => _selectedIndex = 3);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(child: CircularProgressIndicator(color: blue)),
        ),
      );
    }

    final pages = [
      DashboardPage(
        customers: _customers,
        receipts: _receipts,
        storageError: _errorMessage,
        onCollect: () => setState(() => _selectedIndex = 2),
        onShowCustomers: () => setState(() => _selectedIndex = 1),
        onShowHistory: () => setState(() => _selectedIndex = 3),
        onCustomerTap: _showCustomerSheet,
      ),
      CustomersPage(
        customers: _customers,
        receipts: _receipts,
        onTap: _showCustomerSheet,
      ),
      CollectPage(
        customers: _customers,
        receipts: _receipts,
        repository: _repository,
        onReceiptSaved: _handleReceiptSaved,
      ),
      HistoryPage(receipts: _receipts),
      CashDrawerPage(receipts: _receipts),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (_errorMessage != null)
                Container(
                  color: red,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                        onPressed: _refreshData,
                      )
                    ],
                  ),
                ),
              Expanded(
                child: IndexedStack(index: _selectedIndex, children: pages),
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          height: 70,
          backgroundColor: Colors.white,
          indicatorColor: blue.withAlpha(31),
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.people_alt_outlined), label: 'العملاء'),
            NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'تحصيل'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'السندات'),
            NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'العهدة'),
          ],
        ),
      ),
    );
  }

  void _showCustomerSheet(Customer customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomerStatementSheet(
        customer: customer,
        receipts: _receipts.where((r) => r.customerCode == customer.code).toList(),
        pendingYER: _getPendingTotal(customer.code, CurrencyType.yer),
        pendingSAR: _getPendingTotal(customer.code, CurrencyType.sar),
        pendingUSD: _getPendingTotal(customer.code, CurrencyType.usd),
      ),
    );
  }
}

// ============================================================================
// 4. DASHBOARD PAGE
// ============================================================================

class DashboardPage extends StatelessWidget {
  final List<Customer> customers;
  final List<Receipt> receipts;
  final String? storageError;
  final VoidCallback onCollect;
  final VoidCallback onShowCustomers;
  final VoidCallback onShowHistory;
  final ValueChanged<Customer> onCustomerTap;

  const DashboardPage({
    super.key,
    required this.customers,
    required this.receipts,
    this.storageError,
    required this.onCollect,
    required this.onShowCustomers,
    required this.onShowHistory,
    required this.onCustomerTap,
  });

  @override
  Widget build(BuildContext context) {
    final todayReceipts = receipts
        .where((r) => DateUtils.isSameDay(r.createdAt, DateTime.now()) && r.status != ReceiptStatus.draft)
        .toList();

    double todayYER = todayReceipts.where((r) => r.currency == CurrencyType.yer).fold(0, (s, r) => s + r.amount);
    double todaySAR = todayReceipts.where((r) => r.currency == CurrencyType.sar).fold(0, (s, r) => s + r.amount);
    double todayUSD = todayReceipts.where((r) => r.currency == CurrencyType.usd).fold(0, (s, r) => s + r.amount);

    final totalDebtYER = customers.fold<double>(0, (s, c) => s + c.bookBalanceYER);
    final todayPendingCount = todayReceipts.where((r) => r.status == ReceiptStatus.pending).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('محلات دواكم للأدوية والمستلزمات',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ink)),
                  SizedBox(height: 2),
                  Text('نظام التحصيل الميداني • الموزع #1001', style: TextStyle(fontSize: 11, color: muted)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: green.withAlpha(31), borderRadius: BorderRadius.circular(8)),
              child: const Text('المرحلة 1: محلي (SQLite)',
                  style: TextStyle(color: green, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [navy, Color(0xFF1E3A5F)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: navy.withAlpha(51), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إجمالي تحصيلات اليوم (كاش وحوالات اليوم فقط)',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Text('${_fmt(todayYER)} ر.ي',
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('سعودي: ${_fmt(todaySAR)} ر.س',
                      style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  Text('دولار: ${_fmt(todayUSD)} \$',
                      style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(color: Colors.white24, height: 24),
              Row(
                children: [
                  const Icon(Icons.storage_rounded, size: 14, color: Colors.white70),
                  const SizedBox(width: 6),
                  const Text('قاعدة بيانات SQLite محلية', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  const Spacer(),
                  Text(DateFormat('yyyy/MM/dd').format(DateTime.now()),
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'المديونية الدفترية (يمني)',
                value: _fmt(totalDebtYER),
                icon: Icons.account_balance_wallet_outlined,
                color: amber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'عدد العملاء',
                value: '${customers.length}',
                icon: Icons.storefront_outlined,
                color: blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'سندات اليوم',
                value: '${todayReceipts.length}',
                icon: Icons.receipt_long_outlined,
                color: green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'بانتظار الترحيل (اليوم)',
                value: '$todayPendingCount',
                icon: Icons.hourglass_top_rounded,
                color: const Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: onCollect,
            icon: const Icon(Icons.add_rounded),
            label: const Text('تسجيل سند قبض جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 22),
        _SectionHeader(title: 'آخر السندات المحررة', action: 'عرض السجل', onTap: onShowHistory),
        const SizedBox(height: 10),
        if (receipts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: Text('لا توجد سندات مسجلة بعد', style: TextStyle(color: muted))),
          )
        else
          ...receipts.take(3).map((r) => ReceiptTile(receipt: r, showDate: true)),
        const SizedBox(height: 16),
        _SectionHeader(title: 'دليل الصيدليات والمديونيات', action: 'عرض الكل', onTap: onShowCustomers),
        const SizedBox(height: 10),
        ...customers.take(3).map((c) => CustomerTile(
              customer: c,
              pendingYER: receipts
                  .where((r) => r.customerCode == c.code && r.currency == CurrencyType.yer && r.status == ReceiptStatus.pending)
                  .fold(0, (s, r) => s + r.amount),
              onTap: () => onCustomerTap(c),
            )),
      ],
    );
  }
}

// ============================================================================
// 5. CUSTOMERS DIRECTORY
// ============================================================================

class CustomersPage extends StatefulWidget {
  final List<Customer> customers;
  final List<Receipt> receipts;
  final ValueChanged<Customer> onTap;

  const CustomersPage({
    super.key,
    required this.customers,
    required this.receipts,
    required this.onTap,
  });

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.customers
        .where((c) =>
            c.name.contains(_query) ||
            c.code.toLowerCase().contains(_query.toLowerCase()) ||
            c.area.contains(_query))
        .toList();

    return Column(
      children: [
        const _PageHeader(
          title: 'دليل الصيدليات والعملاء',
          subtitle: 'كشف مديونيات العملاء مع احتساب السندات المعلقة فقط (pending)',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'ابحث باسم الصيدلية، الكود، أو الحي...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: borderCol),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final c = filtered[i];
              final pYER = widget.receipts
                  .where((r) => r.customerCode == c.code && r.currency == CurrencyType.yer && r.status == ReceiptStatus.pending)
                  .fold(0.0, (s, r) => s + r.amount);
              return CustomerTile(
                customer: c,
                pendingYER: pYER,
                onTap: () => widget.onTap(c),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 6. OFFICIAL RECEIPT ENTRY
// ============================================================================

class CollectPage extends StatefulWidget {
  final List<Customer> customers;
  final List<Receipt> receipts;
  final ReceiptRepository repository;
  final Future<void> Function(Receipt) onReceiptSaved;

  const CollectPage({
    super.key,
    required this.customers,
    required this.receipts,
    required this.repository,
    required this.onReceiptSaved,
  });

  @override
  State<CollectPage> createState() => _CollectPageState();
}

class _CollectPageState extends State<CollectPage> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _transferRefController = TextEditingController();

  String? _selectedCode;
  CurrencyType _currency = CurrencyType.yer;
  String _method = 'نقداً';
  String _network = 'الكريمي';
  bool _isOpeningReview = false;

  final List<String> _networks = ['الكريمي', 'النجم', 'الامتياز', 'يمن إكسبرس', 'المريسي', 'أخرى'];

  Customer? get _selected =>
      widget.customers.where((c) => c.code == _selectedCode).firstOrNull;

  double get _amount => double.tryParse(_normalizeDigits(_amountController.text)) ?? 0;

  double get _customerBookBalance => _selected?.getBookBalance(_currency) ?? 0.0;

  double get _customerPendingTotal {
    if (_selected == null) return 0.0;
    return widget.receipts
        .where((r) => r.customerCode == _selected!.code && r.currency == _currency && r.status == ReceiptStatus.pending)
        .fold(0.0, (s, r) => s + r.amount);
  }

  double get _effectiveCurrentBalance => _customerBookBalance - _customerPendingTotal;
  double get _projectedRemaining => _effectiveCurrentBalance - _amount;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _transferRefController.dispose();
    super.dispose();
  }

  void _triggerVoucherReview(ReceiptStatus targetStatus) async {
    if (_isOpeningReview) return;

    final rawAmountText = _normalizeDigits(_amountController.text);
    final parsedAmount = double.tryParse(rawAmountText) ?? 0.0;

    if (_selected == null) {
      _snack('يرجى اختيار الصيدلية أولاً');
      return;
    }
    if (parsedAmount <= 0) {
      _snack('يرجى كتابة مبلغ صحيح');
      return;
    }
    if ((parsedAmount * 100).roundToDouble() / 100 != parsedAmount) {
      _snack('المبلغ لا يقبل أكثر من خانتين عشريتين.');
      return;
    }
    if (_method == 'حوالة' && _transferRefController.text.trim().isEmpty && targetStatus != ReceiptStatus.draft) {
      _snack('يرجى إدخال رقم إشعار الحوالة');
      return;
    }

    setState(() => _isOpeningReview = true);

    try {
      final previewSerial = await widget.repository.previewNextReceiptSerial('1001', targetStatus);
      if (!mounted) return;

      await _showVoucherModal(previewSerial, targetStatus);
    } catch (e) {
      if (mounted) _snack('خطأ أثناء تجهيز السند: $e');
    } finally {
      if (mounted) {
        setState(() => _isOpeningReview = false);
      }
    }
  }

  Future<void> _showVoucherModal(String previewSerial, ReceiptStatus targetStatus) async {
    bool isSubmitting = false;
    final double remainingBeforeSave = _projectedRemaining;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      children: [
                        const Text('محلات دواكم للأدوية والمستلزمات الطبية',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: ink)),
                        Text(
                          targetStatus == ReceiptStatus.draft
                              ? 'مسودة سند تحصيل • لا تستهلك ترقيماً رسمياً'
                              : 'سند تحصيل ميداني • محفوظ محلياً (بانتظار الترحيل المركزي)',
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                        const Divider(height: 20, color: borderCol),
                        _rowKV(
                          targetStatus == ReceiptStatus.draft ? 'معرف المسودة' : 'الرقم التسلسلي المقترح',
                          previewSerial,
                          bold: true,
                        ),
                        _rowKV('الصيدلية المستلم منها', '${_selected!.name} (${_selected!.code})'),
                        _rowKV('الرصيد الدفتري المسجل', '${_fmt(_customerBookBalance)} ${_currency.code}'),
                        if (_customerPendingTotal > 0)
                          _rowKV('سندات معلقة بالجولة لم ترحل', '- ${_fmt(_customerPendingTotal)} ${_currency.code}',
                              color: amber, bold: true),
                        _rowKV('الرصيد الميداني قبل هذا السند', '${_fmt(_effectiveCurrentBalance)} ${_currency.code}',
                            bold: true),
                        _rowKV('طريقة القبض',
                            _method == 'نقداً' ? 'نقدي في الحقيبة (كاش)' : 'حوالة ($_network) - مرجع: ${_transferRefController.text.trim()}'),
                        const Divider(height: 16, color: borderCol),
                        _rowKV('المبلغ المقبوض', '${_fmt(_amount)} ${_currency.code}', bold: true, color: blue),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            TafqeetEngine.convert(_amount, _currency),
                            style: const TextStyle(color: Color(0xFF92400E), fontSize: 11, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const Divider(height: 16, color: borderCol),
                        _rowKV('الرصيد المتبقي التقديري', '${_fmt(remainingBeforeSave)} ${_currency.code}',
                            color: green, bold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setModalState(() => isSubmitting = true);

                            try {
                              final savedReceipt = await widget.repository.issueAndSaveReceipt(
                                distributorCode: '1001',
                                customerCode: _selected!.code,
                                customerName: _selected!.name,
                                amount: _amount,
                                currency: _currency,
                                method: _method,
                                network: _method == 'حوالة' ? _network : null,
                                transferRef: _method == 'حوالة' ? _transferRefController.text.trim() : null,
                                note: _noteController.text.trim(),
                                status: targetStatus,
                                fixedDraftNumber: targetStatus == ReceiptStatus.draft ? previewSerial : null,
                              );

                              await widget.onReceiptSaved(savedReceipt);

                              if (!mounted) return;
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);

                              if (savedReceipt.status != ReceiptStatus.draft) {
                                _copyWhatsAppVoucher(savedReceipt, remainingBeforeSave);
                              } else {
                                _snack('تم حفظ المسودة بنجاح في قاعدة البيانات.');
                              }

                              setState(() {
                                _selectedCode = null;
                              });
                              _amountController.clear();
                              _noteController.clear();
                              _transferRefController.clear();
                            } catch (e) {
                              if (mounted) {
                                setModalState(() => isSubmitting = false);
                                String msg = e.toString();
                                if (e is ArgumentError) msg = e.message?.toString() ?? e.toString();
                                if (e is ReceiptPersistenceException) msg = e.message;
                                _snack(msg);
                              }
                            }
                          },
                    icon: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 20),
                    label: Text(
                      isSubmitting
                          ? 'جاري الحفظ الذري في SQLite...'
                          : (targetStatus == ReceiptStatus.draft
                              ? 'تأكيد وحفظ المسودة'
                              : 'تأكيد واعتماد السند محلياً'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text('تراجع لتعديل البيانات'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _copyWhatsAppVoucher(Receipt r, double remaining) {
    if (r.status == ReceiptStatus.draft) return;

    final text = '''
*محلات دواكم للأدوية والمستلزمات*
📄 *إشعار سند تحصيل ميداني*
*(محفوظ محلياً — بانتظار الترحيل المركزي)*
───────────────────
▫️ *رقم السند:* ${r.number}
▫️ *الصيدلية:* ${r.customerName} (${r.customerCode})
▫️ *المبلغ المقبوض:* ${_fmt(r.amount)} ${r.currency.code}
▫️ *فقط:* ${TafqeetEngine.convert(r.amount, r.currency)}
▫️ *طريقة الدفع:* ${r.method == "نقداً" ? "نقداً (كاش المندوب)" : "حوالة ${r.network} (مرجع: ${r.transferRef})"}
▫️ *الرصيد المتبقي التقديري:* ${_fmt(remaining)} ${r.currency.code}
▫️ *التاريخ:* ${DateFormat('yyyy/MM/dd hh:mm a').format(r.createdAt)}
───────────────────
_تم توثيق السند داخل قاعدة بيانات المحطة الميدانية_
''';
    Clipboard.setData(ClipboardData(text: text));
    _snack('تم توثيق السند بنجاح ونسخ الإشعار إلى الحافظة!');
  }

  Widget _rowKV(String k, String v, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: muted, fontSize: 12)),
          Text(v,
              style: TextStyle(
                  color: color ?? ink, fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  void _snack(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        const _PageHeader(title: 'تسجيل سند قبض', subtitle: 'إصدار سند تحصيل نقد أو حوالة متوافق مع سوق الأدوية'),
        const SizedBox(height: 12),
        const _FieldLabel('الصيدلية / العميل المستلم منه'),
        DropdownButtonFormField<String>(
          key: ValueKey(_selectedCode),
          value: _selectedCode,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.storefront_outlined),
            hintText: 'اختر الصيدلية من القائمة',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: borderCol),
            ),
          ),
          items: widget.customers
              .map((c) => DropdownMenuItem(value: c.code, child: Text('${c.name} (${c.code})')))
              .toList(),
          onChanged: (code) => setState(() => _selectedCode = code),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('عملة السند'),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderCol),
          ),
          child: Row(
            children: CurrencyType.values.map((c) {
              final active = _currency == c;
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _currency = c),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? blue : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      c.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: active ? Colors.white : ink, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (_selected != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الرصيد الدفتري المسجل:', style: TextStyle(color: muted, fontSize: 12)),
                    Text('${_fmt(_customerBookBalance)} ${_currency.code}',
                        style: const TextStyle(color: navy, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                if (_customerPendingTotal > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('سندات معلقة بالجولة لم ترحل:', style: TextStyle(color: amber, fontSize: 12)),
                      Text('- ${_fmt(_customerPendingTotal)} ${_currency.code}',
                          style: const TextStyle(color: amber, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ],
                const Divider(height: 14, color: Color(0xFFBFDBFE)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الرصيد الميداني الفعلي للمطالبة:',
                        style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.bold)),
                    Text('${_fmt(_effectiveCurrentBalance)} ${_currency.code}',
                        style: const TextStyle(color: blue, fontWeight: FontWeight.w900, fontSize: 15)),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        const _FieldLabel('مبلغ التحصيل'),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: ink),
          decoration: InputDecoration(
            hintText: '0',
            suffixText: _currency.code,
            prefixIcon: const Icon(Icons.payments_outlined),
            filled: true,
            fillColor: Colors.white,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: borderCol),
            ),
          ),
        ),
        if (_amount > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFB45309)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    TafqeetEngine.convert(_amount, _currency),
                    style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        const _FieldLabel('طريقة القبض'),
        Row(
          children: ['نقداً', 'حوالة'].map((m) {
            final active = _method == m;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Center(child: Text(m)),
                  selected: active,
                  onSelected: (_) => setState(() => _method = m),
                  selectedColor: const Color(0xFFDBEAFE),
                  side: BorderSide(color: active ? blue : borderCol),
                  labelStyle: TextStyle(color: active ? blue : ink, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }).toList(),
        ),
        if (_method == 'حوالة') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('network_$_network'),
            value: _network,
            decoration: const InputDecoration(
              labelText: 'شبكة التحويل / الصرافة',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: borderCol),
              ),
            ),
            items: _networks.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
            onChanged: (v) => setState(() => _network = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _transferRefController,
            decoration: const InputDecoration(
              labelText: 'رقم السند أو إشعار الحوالة',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: borderCol),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        const _FieldLabel('ملاحظات إضافية'),
        TextField(
          controller: _noteController,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'سداد فاتورة أدوية، دفعة حساب...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: borderCol),
            ),
          ),
        ),
        const SizedBox(height: 22),
        ElevatedButton.icon(
          onPressed: _isOpeningReview ? null : () => _triggerVoucherReview(ReceiptStatus.pending),
          icon: _isOpeningReview
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.description_outlined),
          label: const Text('معاينة السند وتأكيد الحفظ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: blue,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _isOpeningReview ? null : () => _triggerVoucherReview(ReceiptStatus.draft),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('حفظ كمسودة محليّة'),
        ),
      ],
    );
  }
}

// ============================================================================
// 7. RECEIPTS ARCHIVE
// ============================================================================

class HistoryPage extends StatefulWidget {
  final List<Receipt> receipts;
  const HistoryPage({super.key, required this.receipts});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _query = '';
  ReceiptStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final filtered = widget.receipts.where((r) {
      final matchesQuery = r.customerName.contains(_query) ||
          r.number.toLowerCase().contains(_query.toLowerCase()) ||
          r.customerCode.toLowerCase().contains(_query.toLowerCase());
      final matchesFilter = _filter == null || r.status == _filter;
      return matchesQuery && matchesFilter;
    }).toList();

    return Column(
      children: [
        const _PageHeader(
          title: 'سجل السندات المحررة',
          subtitle: 'أرشيف سندات القبض المحلية وحالات الترحيل والمسودات',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'ابحث برقم السند أو اسم الصيدلية...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: borderCol),
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Row(
            children: [
              _buildFilterChip('الكل (${widget.receipts.length})', null),
              const SizedBox(width: 8),
                            _buildFilterChip(
                'مسودات (${widget.receipts.where((r) => r.status == ReceiptStatus.draft).length})',
                ReceiptStatus.draft,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'مرحل (${widget.receipts.where((r) => r.status == ReceiptStatus.posted).length})',
                ReceiptStatus.posted,
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'لا توجد سندات مطابقة لمعايير البحث',
                    style: TextStyle(color: muted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => ReceiptTile(receipt: filtered[i], showDate: true),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, ReceiptStatus? status) {
    final active = _filter == status;
    return FilterChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => setState(() => _filter = status),
      selectedColor: blue.withAlpha(38),
      checkmarkColor: blue,
      labelStyle: TextStyle(
        color: active ? blue : ink,
        fontWeight: active ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }
}

// ============================================================================
// 8. CASH DRAWER
// ============================================================================

class CashDrawerPage extends StatelessWidget {
  final List<Receipt> receipts;

  const CashDrawerPage({super.key, required this.receipts});

  @override
  Widget build(BuildContext context) {
    final todayReceipts = receipts
        .where((r) => DateUtils.isSameDay(r.createdAt, DateTime.now()) && r.status != ReceiptStatus.draft)
        .toList();

    final cashYER = todayReceipts
        .where((r) => r.currency == CurrencyType.yer && r.method == 'نقداً')
        .fold(0.0, (s, r) => s + r.amount);
    final cashSAR = todayReceipts
        .where((r) => r.currency == CurrencyType.sar && r.method == 'نقداً')
        .fold(0.0, (s, r) => s + r.amount);
    final cashUSD = todayReceipts
        .where((r) => r.currency == CurrencyType.usd && r.method == 'نقداً')
        .fold(0.0, (s, r) => s + r.amount);

    final transYER = todayReceipts
        .where((r) => r.currency == CurrencyType.yer && r.method == 'حوالة')
        .fold(0.0, (s, r) => s + r.amount);
    final transSAR = todayReceipts
        .where((r) => r.currency == CurrencyType.sar && r.method == 'حوالة')
        .fold(0.0, (s, r) => s + r.amount);
    final transUSD = todayReceipts
        .where((r) => r.currency == CurrencyType.usd && r.method == 'حوالة')
        .fold(0.0, (s, r) => s + r.amount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        const _PageHeader(
          title: 'صندوق العهدة الميدانية (وردية اليوم)',
          subtitle: 'جرد المبالغ النقدية في الحقيبة وإشعارات الحوالات المحصلة خلال اليوم',
        ),
        const SizedBox(height: 8),
        _buildCustodyCard(
          title: 'النقدية بالحقيبة (كاش الموزع اليوم)',
          icon: Icons.payments_rounded,
          headerColor: green,
          yer: cashYER,
          sar: cashSAR,
          usd: cashUSD,
          note: 'المبالغ النقدية الفعلية المحصلة اليوم والمطابق تسليمها لأمين الصندوق بالفرع',
        ),
        const SizedBox(height: 16),
        _buildCustodyCard(
          title: 'إجمالي إشعارات الحوالات الموثقة اليوم',
          icon: Icons.account_balance_rounded,
          headerColor: blue,
          yer: transYER,
          sar: transSAR,
          usd: transUSD,
          note: 'حوالات الصرافين والشبكات المقيدة بموجب سندات رسمية خلال وردية اليوم',
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderCol),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: navy, size: 20),
                  SizedBox(width: 8),
                  Text('إيضاح محاسبي لتسليم العهدة',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ink)),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'تنبيه: هذه الأرقام تمثل السندات المسجلة محلياً لوردية اليوم فقط، وتعتبر عهدة في ذمة الموزع حتى يتم تسليمها ومطابقتها وتوريدها فعلياً لأمين الصندوق بالفرع وترحيلها مركزياً.',
                style: TextStyle(fontSize: 11, color: muted, height: 1.5),
              ),
              const Divider(height: 20, color: borderCol),
              _checkStep('1. مطابقة الكاش الفعلي في الحقيبة مع إجمالي الصندوق أعلاه.'),
              _checkStep('2. التأكد من صحة أرقام إشعارات الحوالات قبل تسليم الإقفال.'),
              _checkStep('3. المزامنة والترحيل إلى الخادم المركزي فور توفر اتصال بالإنترنت.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _checkStep(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: green, size: 15),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: ink))),
        ],
      ),
    );
  }

  Widget _buildCustodyCard({
    required String title,
    required IconData icon,
    required Color headerColor,
    required double yer,
    required double sar,
    required double usd,
    required String note,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: headerColor.withAlpha(31),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: headerColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: ink),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: borderCol),
          _currencyRow('ريال يمني (YER)', yer, CurrencyType.yer.code, green),
          const SizedBox(height: 8),
          _currencyRow('ريال سعودي (SAR)', sar, CurrencyType.sar.code, amber),
          const SizedBox(height: 8),
          _currencyRow('دولار أمريكي (USD)', usd, CurrencyType.usd.code, blue),
          const Divider(height: 20, color: borderCol),
          Text(note, style: const TextStyle(fontSize: 11, color: muted)),
        ],
      ),
    );
  }

  Widget _currencyRow(String label, double val, String sym, Color accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: muted)),
        Text(
          '${_fmt(val)} $sym',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: ink),
        ),
      ],
    );
  }
}

// ============================================================================
// 9. CUSTOMER STATEMENT BOTTOM SHEET
// ============================================================================

class CustomerStatementSheet extends StatelessWidget {
  final Customer customer;
  final List<Receipt> receipts;
  final double pendingYER;
  final double pendingSAR;
  final double pendingUSD;

  const CustomerStatementSheet({
    super.key,
    required this.customer,
    required this.receipts,
    required this.pendingYER,
    required this.pendingSAR,
    required this.pendingUSD,
  });

  @override
  Widget build(BuildContext context) {
    final effYER = customer.bookBalanceYER - pendingYER;
    final effSAR = customer.bookBalanceSAR - pendingSAR;
    final effUSD = customer.bookBalanceUSD - pendingUSD;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: blue.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: blue, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ink),
                      ),
                      Text(
                        'كود: ${customer.code} • المنطقة: ${customer.area} • هاتف: ${customer.phone}',
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24, color: borderCol),
            const Text(
              'موقف الأرصدة والمديونيات متعددة العملات',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ink),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderCol),
              ),
              child: Column(
                children: [
                  _balanceItem('ريال يمني', customer.bookBalanceYER, pendingYER, effYER, 'ر.ي'),
                  const Divider(height: 16, color: borderCol),
                  _balanceItem('ريال سعودي', customer.bookBalanceSAR, pendingSAR, effSAR, 'ر.س'),
                  const Divider(height: 16, color: borderCol),
                  _balanceItem('دولار أمريكي', customer.bookBalanceUSD, pendingUSD, effUSD, '\$'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'حركات التحصيل الميداني الأخيرة لهذا العميل',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ink),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: receipts.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد سندات محررة لهذه الصيدلية بالجولة الحالية',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      itemCount: receipts.length,
                      itemBuilder: (_, i) => ReceiptTile(receipt: receipts[i], showDate: true),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceItem(String name, double book, double pending, double eff, String sym) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ink)),
        ),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('دفتري: ${_fmt(book)} $sym', style: const TextStyle(fontSize: 11, color: muted)),
              if (pending > 0)
                Text('معلق: -${_fmt(pending)}',
                    style: const TextStyle(fontSize: 10, color: amber, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            '${_fmt(eff)} $sym',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: eff > 0 ? red : green,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 10. REUSABLE ATOMIC COMPONENTS & TILES
// ============================================================================

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(31),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ink)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 11, color: muted)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ink)),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          child: Text(action, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: blue)),
        ),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PageHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: muted)),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ink),
      ),
    );
  }
}

class ReceiptTile extends StatelessWidget {
  final Receipt receipt;
  final bool showDate;

  const ReceiptTile({
    super.key,
    required this.receipt,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    switch (receipt.status) {
      case ReceiptStatus.draft:
        statusColor = muted;
        statusText = 'مسودة';
        break;
      case ReceiptStatus.pending:
        statusColor = amber;
        statusText = 'بانتظار الترحيل';
        break;
      case ReceiptStatus.posted:
        statusColor = green;
        statusText = 'مرحل للمركز';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (receipt.method == 'نقداً' ? green : blue).withAlpha(31),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              receipt.method == 'نقداً' ? Icons.payments_outlined : Icons.account_balance_outlined,
              color: receipt.method == 'نقداً' ? green : blue,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        receipt.customerName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(31),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${receipt.number} • ${receipt.method}${receipt.network != null ? ' (${receipt.network})' : ''}',
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
                if (showDate) ...[
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('yyyy/MM/dd hh:mm a').format(receipt.createdAt),
                    style: const TextStyle(fontSize: 10, color: muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_fmt(receipt.amount)} ${receipt.currency.code}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: navy),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CustomerTile extends StatelessWidget {
  final Customer customer;
  final double pendingYER;
  final VoidCallback onTap;

  const CustomerTile({
    super.key,
    required this.customer,
    required this.pendingYER,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveYER = customer.bookBalanceYER - pendingYER;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderCol),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: blue.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.storefront_outlined, color: blue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${customer.code} • ${customer.area}',
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_fmt(effectiveYER)} ر.ي',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: effectiveYER > 0 ? red : green,
                  ),
                ),
                if (pendingYER > 0)
                  Text(
                    'معلق: ${_fmt(pendingYER)}',
                    style: const TextStyle(fontSize: 10, color: amber, fontWeight: FontWeight.bold),
                  )
                else if (customer.bookBalanceSAR > 0 || customer.bookBalanceUSD > 0)
                  const Text(
                    'عملات أخرى متوفرة',
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_left_rounded, color: muted, size: 20),
          ],
        ),
      ),
    );
  }
}
