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
      identical(this, other) || other is Customer && runtimeType == other.runtimeType && code == other.code;

  @override
  int get hashCode => code.hashCode;
}

const navy = Color(0xFF0F243E);
const blue = Color(0xFF2563EB);
const bg = Color(0xFFF8FAFC);
const ink = Color(0xFF0F172A);
const muted = Color(0xFF64748B);
const green = Color(0xFF10B981);
const amber = Color(0xFFF59E0B);
const red = Color(0xFFEF4444);
const borderCol = Color(0xFFE2E8F0);

String _fmt(num n) => NumberFormat('#,##0.##', 'en_US').format(n);

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
  int _selectedIndex = 0;
  final ReceiptRepository _repository = ReceiptRepository();

  static const List<Customer> _seedCustomers = [
    Customer(code: 'C-101', name: 'صيدلية الأمل الحديثة', area: 'صنعاء - التحرير', phone: '777000111', bookBalanceYER: 850000, bookBalanceSAR: 2400, bookBalanceUSD: 350),
    Customer(code: 'C-102', name: 'صيدلية النور المركزية', area: 'صنعاء - حدة', phone: '771234567', bookBalanceYER: 420000, bookBalanceSAR: 0, bookBalanceUSD: 0),
    Customer(code: 'C-103', name: 'صيدلية الحياة التخصصية', area: 'صنعاء - شميلة', phone: '773334445', bookBalanceYER: 1250000, bookBalanceSAR: 5600, bookBalanceUSD: 1200),
    Customer(code: 'C-104', name: 'صيدلية المستقبل المتميزة', area: 'صنعاء - الحصبة', phone: '775556667', bookBalanceYER: 95000, bookBalanceSAR: 450, bookBalanceUSD: 0),
    Customer(code: 'C-105', name: 'مستوصف ابن سينا الطبي', area: 'صنعاء - مذبح', phone: '778889990', bookBalanceYER: 0, bookBalanceSAR: 0, bookBalanceUSD: 0),
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
      final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM customers')) ?? 0;

      if (count == 0) {
        await _repository.saveCustomers(_seedCustomers.map((c) => {
          'code': c.code, 'name': c.name, 'area': c.area, 'phone': c.phone,
          'balance_yer': c.bookBalanceYER, 'balance_sar': c.bookBalanceSAR, 'balance_usd': c.bookBalanceUSD,
        }).toList());
      }
      await _refreshData();
    } catch (e) {
      if (mounted) setState(() { _errorMessage = e.toString(); _isLoading = false; });
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
      if (mounted) setState(() { _errorMessage = e.toString(); _isLoading = false; });
    }
  }

  double _getPendingTotal(String customerCode, CurrencyType currency) {
    return _receipts
        .where((r) => r.customerCode == customerCode && r.currency == currency && r.status == ReceiptStatus.pending)
        .fold(0.0, (s, r) => s + r.amount);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: Center(child: CircularProgressIndicator(color: blue))));
    }

    final pages = [
      DashboardPage(customers: _customers, receipts: _receipts, onCollect: () => setState(() => _selectedIndex = 2), onShowCustomers: () => setState(() => _selectedIndex = 1), onShowHistory: () => setState(() => _selectedIndex = 3), onCustomerTap: _showCustomerSheet),
      CustomersPage(customers: _customers, receipts: _receipts, onTap: _showCustomerSheet),
      CollectPage(customers: _customers, receipts: _receipts, repository: _repository, onReceiptSaved: (r) async { await _refreshData(); if (mounted) setState(() => _selectedIndex = 3); }),
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
                      Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                      IconButton(icon: const Icon(Icons.refresh, color: Colors.white, size: 18), onPressed: _refreshData),
                    ],
                  ),
                ),
              Expanded(child: IndexedStack(index: _selectedIndex, children: pages)),
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

class DashboardPage extends StatelessWidget {
  final List<Customer> customers;
  final List<Receipt> receipts;
  final VoidCallback onCollect;
  final VoidCallback onShowCustomers;
  final VoidCallback onShowHistory;
  final ValueChanged<Customer> onCustomerTap;

  const DashboardPage({
    super.key, required this.customers, required this.receipts,
    required this.onCollect, required this.onShowCustomers,
    required this.onShowHistory, required this.onCustomerTap,
  });

  @override
  Widget build(BuildContext context) {
    final today = receipts.where((r) => DateUtils.isSameDay(r.createdAt, DateTime.now()) && r.status != ReceiptStatus.draft).toList();
    final todayYER = today.where((r) => r.currency == CurrencyType.yer).fold(0.0, (s, r) => s + r.amount);
    final todaySAR = today.where((r) => r.currency == CurrencyType.sar).fold(0.0, (s, r) => s + r.amount);
    final todayUSD = today.where((r) => r.currency == CurrencyType.usd).fold(0.0, (s, r) => s + r.amount);
    final totalDebtYER = customers.fold<double>(0, (s, c) => s + c.bookBalanceYER);
    final todayPendingCount = today.where((r) => r.status == ReceiptStatus.pending).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 22)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('محلات دواكم للأدوية والمستلزمات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ink)), Text('نظام التحصيل الميداني • الموزع #1001', style: TextStyle(fontSize: 11, color: muted))])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: green.withAlpha(31), borderRadius: BorderRadius.circular(8)), child: const Text('المرحلة 1: محلي', style: TextStyle(color: green, fontSize: 11, fontWeight: FontWeight.bold))),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [navy, Color(0xFF1E3A5F)]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: navy.withAlpha(51), blurRadius: 16, offset: const Offset(0, 6))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إجمالي تحصيلات اليوم (كاش وحوالات اليوم)', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Text('${_fmt(todayYER)} ر.ي', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Row(children: [Text('سعودي: ${_fmt(todaySAR)} ر.س', style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(width: 16), Text('دولار: ${_fmt(todayUSD)} \$', style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 12, fontWeight: FontWeight.bold))]),
              const Divider(color: Colors.white24, height: 24),
              Row(children: [const Icon(Icons.storage_rounded, size: 14, color: Colors.white70), const SizedBox(width: 6), const Text('قاعدة بيانات SQLite محلية', style: TextStyle(color: Colors.white70, fontSize: 11)), const Spacer(), Text(DateFormat('yyyy/MM/dd').format(DateTime.now()), style: const TextStyle(color: Colors.white70, fontSize: 11))]),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _StatCard(title: 'المديونية الدفترية', value: _fmt(totalDebtYER), icon: Icons.account_balance_wallet_outlined, color: amber)),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(title: 'عدد العملاء', value: '${customers.length}', icon: Icons.storefront_outlined, color: blue)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _StatCard(title: 'سندات اليوم', value: '${today.length}', icon: Icons.receipt_long_outlined, color: green)),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(title: 'بانتظار الترحيل', value: '$todayPendingCount', icon: Icons.hourglass_top_rounded, color: const Color(0xFF8B5CF6))),
        ]),
        const SizedBox(height: 20),
        SizedBox(height: 52, child: ElevatedButton.icon(onPressed: onCollect, icon: const Icon(Icons.add_rounded), label: const Text('تسجيل سند قبض جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), style: ElevatedButton.styleFrom(backgroundColor: blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
        const SizedBox(height: 22),
        _SectionHeader(title: 'آخر السندات المحررة', action: 'عرض السجل', onTap: onShowHistory),
        const SizedBox(height: 10),
        if (receipts.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(12), child: Text('لا توجد سندات مسجلة بعد', style: TextStyle(color: muted))))
        else ...receipts.take(3).map((r) => ReceiptTile(receipt: r, showDate: true)),
        const SizedBox(height: 16),
        _SectionHeader(title: 'دليل الصيدليات والمديونيات', action: 'عرض الكل', onTap: onShowCustomers),
        const SizedBox(height: 10),
        ...customers.take(3).map((c) => CustomerTile(customer: c, pendingYER: receipts.where((r) => r.customerCode == c.code && r.currency == CurrencyType.yer && r.status == ReceiptStatus.pending).fold(0, (s, r) => s + r.amount), onTap: () => onCustomerTap(c))),
      ],
    );
  }
}

class CustomersPage extends StatefulWidget {
  final List<Customer> customers;
  final List<Receipt> receipts;
  final ValueChanged<Customer> onTap;
  const CustomersPage({super.key, required this.customers, required this.receipts, required this.onTap});
  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final filtered = widget.customers.where((c) => c.name.contains(_query) || c.code.toLowerCase().contains(_query.toLowerCase()) || c.area.contains(_query)).toList();
    return Column(
      children: [
        const _PageHeader(title: 'دليل الصيدليات والعملاء', subtitle: 'كشف مديونيات العملاء مع احتساب السندات المعلقة فقط'),
        Padding(padding: const EdgeInsets.fromLTRB(18, 4, 18, 12), child: TextField(onChanged: (v) => setState(() => _query = v.trim()), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث باسم الصيدلية، الكود، أو الحي...', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: borderCol))))),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final c = filtered[i];
              final pYER = widget.receipts.where((r) => r.customerCode == c.code && r.currency == CurrencyType.yer && r.status == ReceiptStatus.pending).fold(0.0, (s, r) => s + r.amount);
              return CustomerTile(customer: c, pendingYER: pYER, onTap: () => widget.onTap(c));
            },
          ),
        ),
      ],
    );
  }
}

class CustomerSearchPicker extends StatelessWidget {
  final List<Customer> customers;
  const CustomerSearchPicker({super.key, required this.customers});

  @override
  Widget build(BuildContext context) {
    return _CustomerSearchModal(customers: customers);
  }
}

class _CustomerSearchModal extends StatefulWidget {
  final List<Customer> customers;
  const _CustomerSearchModal({required this.customers});

  @override
  State<_CustomerSearchModal> createState() => _CustomerSearchModalState();
}

class _CustomerSearchModalState extends State<_CustomerSearchModal> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.customers.where((c) =>
      c.name.contains(_query) ||
      c.code.toLowerCase().contains(_query.toLowerCase()) ||
      c.area.contains(_query)
    ).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 14),
            const Text('بحث واختيار الصيدلية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ink)),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'اكتب اسم الصيدلية أو الكود للبحث السريع...',
                filled: true,
                fillColor: bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: borderCol)),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final c = filtered[i];
                  return ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: borderCol)),
                    tileColor: bg,
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ink)),
                    subtitle: Text('${c.code} • ${c.area}', style: const TextStyle(fontSize: 11, color: muted)),
                    trailing: const Icon(Icons.chevron_left_rounded, color: blue),
                    onTap: () => Navigator.pop(context, c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CollectPage extends StatefulWidget {
  final List<Customer> customers;
  final List<Receipt> receipts;
  final ReceiptRepository repository;
  final Future<void> Function(Receipt) onReceiptSaved;

  const CollectPage({super.key, required this.customers, required this.receipts, required this.repository, required this.onReceiptSaved});
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

  Customer? get _selected => widget.customers.where((c) => c.code == _selectedCode).firstOrNull;
  double get _amount => double.tryParse(_normalizeDigits(_amountController.text)) ?? 0;
  double get _customerBookBalance => _selected?.getBookBalance(_currency) ?? 0.0;
  double get _customerPendingTotal => _selected == null ? 0.0 : widget.receipts.where((r) => r.customerCode == _selected!.code && r.currency == _currency && r.status == ReceiptStatus.pending).fold(0.0, (s, r) => s + r.amount);
  double get _effectiveCurrentBalance => _customerBookBalance - _customerPendingTotal;
  double get _projectedRemaining => _effectiveCurrentBalance - _amount;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _transferRefController.dispose();
    super.dispose();
  }

  void _openCustomerSearch() async {
    final Customer? chosen = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomerSearchPicker(customers: widget.customers),
    );
    if (chosen != null) {
      setState(() => _selectedCode = chosen.code);
    }
  }

  void _triggerVoucherReview(ReceiptStatus targetStatus) async {
    if (_isOpeningReview) return;
    final parsed = double.tryParse(_normalizeDigits(_amountController.text)) ?? 0.0;

    if (_selected == null) { _snack('يرجى اختيار الصيدلية أولاً'); return; }
    if (parsed <= 0) { _snack('يرجى كتابة مبلغ صحيح'); return; }
    if ((parsed * 100).roundToDouble() / 100 != parsed) { _snack('المبلغ لا يقبل أكثر من خانتين عشريتين.'); return; }
    if (_method == 'حوالة' && _transferRefController.text.trim().isEmpty && targetStatus != ReceiptStatus.draft) {
      _snack('يرجى إدخال رقم إشعار الحوالة'); return;
    }

    setState(() => _isOpeningReview = true);
    try {
      final previewSerial = await widget.repository.previewNextReceiptSerial('1001', targetStatus);
      if (!mounted) return;
      await _showVoucherModal(previewSerial, targetStatus);
    } catch (e) {
      if (mounted) _snack('خطأ: $e');
    } finally {
      if (mounted) setState(() => _isOpeningReview = false);
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
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)))),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: borderCol)),
                    child: Column(
                      children: [
                        const Text('محلات دواكم للأدوية والمستلزمات الطبية', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: ink)),
                        Text(targetStatus == ReceiptStatus.draft ? 'مسودة سند تحصيل' : 'سند تحصيل ميداني • محفوظ محلياً', style: const TextStyle(fontSize: 11, color: muted)),
                        const Divider(height: 20, color: borderCol),
                        _rowKV('الرقم التسلسلي المقترح', previewSerial, bold: true),
                        _rowKV('الصيدلية المستلم منها', '${_selected!.name} (${_selected!.code})'),
                        _rowKV('الرصيد الدفتري المسجل', '${_fmt(_customerBookBalance)} ${_currency.code}'),
                        if (_customerPendingTotal > 0) _rowKV('سندات معلقة بالجولة', '- ${_fmt(_customerPendingTotal)} ${_currency.code}', color: amber, bold: true),
                        _rowKV('الرصيد الميداني الفعلي', '${_fmt(_effectiveCurrentBalance)} ${_currency.code}', bold: true),
                        _rowKV('طريقة القبض', _method == 'نقداً' ? 'نقدي (كاش)' : 'حوالة ($_network) - مرجع: ${_transferRefController.text.trim()}'),
                        const Divider(height: 16, color: borderCol),
                        _rowKV('المبلغ المقبوض', '${_fmt(_amount)} ${_currency.code}', bold: true, color: blue),
                        const Divider(height: 16, color: borderCol),
                        _rowKV('الرصيد المتبقي التقديري', '${_fmt(remainingBeforeSave)} ${_currency.code}', color: green, bold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: isSubmitting ? null : () async {
                      setModalState(() => isSubmitting = true);
                      try {
                        final saved = await widget.repository.issueAndSaveReceipt(
                          distributorCode: '1001', customerCode: _selected!.code, customerName: _selected!.name,
                          amount: _amount, currency: _currency, method: _method,
                          network: _method == 'حوالة' ? _network : null,
                          transferRef: _method == 'حوالة' ? _transferRefController.text.trim() : null,
                          note: _noteController.text.trim(), status: targetStatus,
                          fixedDraftNumber: targetStatus == ReceiptStatus.draft ? previewSerial : null,
                        );

                        await widget.onReceiptSaved(saved);
                        if (!mounted) return;
                        Navigator.pop(ctx);

                        if (saved.status != ReceiptStatus.draft) {
                          _copyWhatsAppVoucher(saved, remainingBeforeSave);
                        } else {
                          _snack('تم حفظ المسودة بنجاح.');
                        }

                        setState(() => _selectedCode = null);
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
                    icon: isSubmitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle_rounded, size: 20),
                    label: Text(isSubmitting ? 'جاري الحفظ الذري في SQLite...' : (targetStatus == ReceiptStatus.draft ? 'تأكيد وحفظ المسودة' : 'تأكيد واعتماد السند محلياً')),
                    style: ElevatedButton.styleFrom(backgroundColor: blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: isSubmitting ? null : () => Navigator.pop(ctx), child: const Text('تراجع لتعديل البيانات')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _copyWhatsAppVoucher(Receipt r, double remaining) {
    final text = '''
*محلات دواكم للأدوية والمستلزمات*
📄 *إشعار سند تحصيل ميداني*
*(محفوظ محلياً — بانتظار الترحيل المركزي)*
───────────────────
▫️ *رقم السند:* ${r.number}
▫️ *الصيدلية:* ${r.customerName} (${r.customerCode})
▫️ *المبلغ المقبوض:* ${_fmt(r.amount)} ${r.currency.code}
▫️ *طريقة الدفع:* ${r.method == "نقداً" ? "نقداً (كاش)" : "حوالة ${r.network} (مرجع: ${r.transferRef})"}
▫️ *الرصيد المتبقي التقديري:* ${_fmt(remaining)} ${r.currency.code}
▫️ *التاريخ:* ${DateFormat('yyyy/MM/dd hh:mm a').format(r.createdAt)}
───────────────────
_تم توثيق السند داخل قاعدة بيانات المحطة الميدانية_
''';
    Clipboard.setData(ClipboardData(text: text));
    _snack('تم توثيق السند ونسخ الإشعار إلى الحافظة!');
  }

  Widget _rowKV(String k, String v, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: muted, fontSize: 12)),
          Text(v, style: TextStyle(color: color ?? ink, fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  void _snack(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        const _PageHeader(title: 'تسجيل سند قبض', subtitle: 'إصدار سند تحصيل نقد أو حوالة متوافق مع سوق الأدوية'),
        const SizedBox(height: 12),
        const _FieldLabel('الصيدلية / العميل المستلم منه'),
        
        InkWell(
          onTap: _openCustomerSearch,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderCol),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront_outlined, color: blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selected == null ? 'انقر هنا للبحث السريع عن الصيدلية...' : '${_selected!.name} (${_selected!.code})',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _selected == null ? muted : ink),
                  ),
                ),
                const Icon(Icons.search_rounded, color: muted),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),
        const _FieldLabel('عملة السند'),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderCol)),
          child: Row(
            children: CurrencyType.values.map((c) {
              final active = _currency == c;
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _currency = c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: active ? blue : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                    child: Text(c.label, textAlign: TextAlign.center, style: TextStyle(color: active ? Colors.white : ink, fontWeight: FontWeight.bold, fontSize: 12)),
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
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الرصيد الدفتري المسجل:', style: TextStyle(color: muted, fontSize: 12)), Text('${_fmt(_customerBookBalance)} ${_currency.code}', style: const TextStyle(color: navy, fontWeight: FontWeight.bold, fontSize: 13))]),
                if (_customerPendingTotal > 0) ...[
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('سندات معلقة بالجولة لم ترحل:', style: TextStyle(color: amber, fontSize: 12)), Text('- ${_fmt(_customerPendingTotal)} ${_currency.code}', style: const TextStyle(color: amber, fontWeight: FontWeight.bold, fontSize: 13))]),
                ],
                const Divider(height: 14, color: Color(0xFFBFDBFE)),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الرصيد الميداني الفعلي:', style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.bold)), Text('${_fmt(_effectiveCurrentBalance)} ${_currency.code}', style: const TextStyle(color: blue, fontWeight: FontWeight.w900, fontSize: 15))]),
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
          decoration: InputDecoration(hintText: '0', suffixText: _currency.code, prefixIcon: const Icon(Icons.payments_outlined), filled: true, fillColor: Colors.white, border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: borderCol))),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('طريقة القبض'),
        Row(
          children: ['نقداً', 'حوالة'].map((m) {
            final active = _method == m;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Center(child: Text(m)), selected: active,
                  onSelected: (_) => setState(() => _method = m),
                  selectedColor: const Color(0xFFDBEAFE),
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
            decoration: const InputDecoration(labelText: 'شبكة التحويل / الصرافة', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: borderCol))),
            items: _networks.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
            onChanged: (v) => setState(() => _network = v!),
          ),
          const SizedBox(height: 12),
          TextField(controller: _transferRefController, decoration: const InputDecoration(labelText: 'رقم السند أو إشعار الحوالة', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: borderCol)))),
        ],
        const SizedBox(height: 14),
        const _FieldLabel('ملاحظات إضافية'),
        TextField(controller: _noteController, maxLines: 2, decoration: const InputDecoration(hintText: 'سداد فاتورة، دفعة حساب...', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: borderCol)))),
        const SizedBox(height: 22),
        ElevatedButton.icon(
          onPressed: _isOpeningReview ? null : () => _triggerVoucherReview(ReceiptStatus.pending),
          icon: _isOpeningReview ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.description_outlined),
          label: const Text('معاينة السند وتأكيد الحفظ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          style: ElevatedButton.styleFrom(backgroundColor: blue, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        ),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: _isOpeningReview ? null : () => _triggerVoucherReview(ReceiptStatus.draft), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Text('حفظ كمسودة محليّة')),
      ],
    );
  }
}

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
      final matchesQuery = r.customerName.contains(_query) || r.number.toLowerCase().contains(_query.toLowerCase()) || r.customerCode.toLowerCase().contains(_query.toLowerCase());
      final matchesFilter = _filter == null || r.status == _filter;
      return matchesQuery && matchesFilter;
    }).toList();

    return Column(
      children: [
        const _PageHeader(title: 'سجل السندات المحررة', subtitle: 'أرشيف سندات القبض المحلية وحالات الترحيل والمسودات'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4), child: TextField(onChanged: (v) => setState(() => _query = v.trim()), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث برقم السند أو اسم الصيدلية...', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: borderCol))))),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Row(
            children: [
              _buildChip('الكل (${widget.receipts.length})', null),
              const SizedBox(width: 8),
              _buildChip('معتمد محلياً (${widget.receipts.where((r) => r.status == ReceiptStatus.pending).length})', ReceiptStatus.pending),
              const SizedBox(width: 8),
              _buildChip('مسودات (${widget.receipts.where((r) => r.status == ReceiptStatus.draft).length})', ReceiptStatus.draft),
              const SizedBox(width: 8),
              _buildChip('مرحل (${widget.receipts.where((r) => r.status == ReceiptStatus.posted).length})', ReceiptStatus.posted),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty ? const Center(child: Text('لا توجد سندات مطابقة للبحث', style: TextStyle(color: muted))) : ListView.builder(padding: const EdgeInsets.fromLTRB(18, 6, 18, 20), itemCount: filtered.length, itemBuilder: (_, i) => ReceiptTile(receipt: filtered[i], showDate: true)),
        ),
      ],
    );
  }

  Widget _buildChip(String label, ReceiptStatus? status) {
    final active = _filter == status;
    return FilterChip(
      label: Text(label), selected: active, onSelected: (_) => setState(() => _filter = status),
      selectedColor: blue.withAlpha(38), checkmarkColor: blue,
      labelStyle: TextStyle(color: active ? blue : ink, fontWeight: active ? FontWeight.bold : FontWeight.normal, fontSize: 12),
    );
  }
}

class CashDrawerPage extends StatelessWidget {
  final List<Receipt> receipts;
  const CashDrawerPage({super.key, required this.receipts});

  @override
  Widget build(BuildContext context) {
    final today = receipts.where((r) => DateUtils.isSameDay(r.createdAt, DateTime.now()) && r.status != ReceiptStatus.draft).toList();
    final cashYER = today.where((r) => r.currency == CurrencyType.yer && r.method == 'نقداً').fold(0.0, (s, r) => s + r.amount);
    final cashSAR = today.where((r) => r.currency == CurrencyType.sar && r.method == 'نقداً').fold(0.0, (s, r) => s + r.amount);
    final cashUSD = today.where((r) => r.currency == CurrencyType.usd && r.method == 'نقداً').fold(0.0, (s, r) => s + r.amount);

    final transYER = today.where((r) => r.currency == CurrencyType.yer && r.method == 'حوالة').fold(0.0, (s, r) => s + r.amount);
    final transSAR = today.where((r) => r.currency == CurrencyType.sar && r.method == 'حوالة').fold(0.0, (s, r) => s + r.amount);
    final transUSD = today.where((r) => r.currency == CurrencyType.usd && r.method == 'حوالة').fold(0.0, (s, r) => s + r.amount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        const _PageHeader(title: 'صندوق العهدة الميدانية (وردية اليوم)', subtitle: 'جرد المبالغ النقدية في الحقيبة وإشعارات الحوالات لوردية اليوم'),
        const SizedBox(height: 8),
        _buildCustodyCard(title: 'النقدية بالحقيبة (كاش اليوم)', icon: Icons.payments_rounded, color: green, yer: cashYER, sar: cashSAR, usd: cashUSD),
        const SizedBox(height: 16),
        _buildCustodyCard(title: 'إجمالي الحوالات الموثقة اليوم', icon: Icons.account_balance_rounded, color: blue, yer: transYER, sar: transSAR, usd: transUSD),
      ],
    );
  }

  Widget _buildCustodyCard({required String title, required IconData icon, required Color color, required double yer, required double sar, required double usd}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: borderCol)),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withAlpha(31), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 22)), const SizedBox(width: 12), Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: ink))]),
          const Divider(height: 24, color: borderCol),
          _rowVal('ريال يمني', yer, 'ر.ي'),
          const SizedBox(height: 8),
          _rowVal('ريال سعودي', sar, 'ر.س'),
          const SizedBox(height: 8),
          _rowVal('دولار أمريكي', usd, '\$'),
        ],
      ),
    );
  }

  Widget _rowVal(String label, double val, String sym) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 12, color: muted)), Text('${_fmt(val)} $sym', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: ink))]);
}

class CustomerStatementSheet extends StatelessWidget {
  final Customer customer;
  final List<Receipt> receipts;
  final double pendingYER;
  final double pendingSAR;
  final double pendingUSD;

  const CustomerStatementSheet({super.key, required this.customer, required this.receipts, required this.pendingYER, required this.pendingSAR, required this.pendingUSD});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)))),
            const SizedBox(height: 14),
            Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: blue.withAlpha(26), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.storefront_rounded, color: blue, size: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(customer.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ink)), Text('كود: ${customer.code} • المنطقة: ${customer.area}', style: const TextStyle(fontSize: 11, color: muted))])),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ]),
            const Divider(height: 24, color: borderCol),
            const Text('موقف الأرصدة والمديونيات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ink)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: borderCol)),
              child: Column(children: [
                _balanceRow('ريال يمني', customer.bookBalanceYER, pendingYER, 'ر.ي'),
                const Divider(height: 16, color: borderCol),
                _balanceRow('ريال سعودي', customer.bookBalanceSAR, pendingSAR, 'ر.س'),
                const Divider(height: 16, color: borderCol),
                _balanceRow('دولار أمريكي', customer.bookBalanceUSD, pendingUSD, '\$'),
              ]),
            ),
            const SizedBox(height: 16),
            const Text('سندات التحصيل الأخيرة للعميل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ink)),
            const SizedBox(height: 8),
            Expanded(
              child: receipts.isEmpty ? const Center(child: Text('لا توجد سندات محررة بالجولة الحالية', style: TextStyle(color: muted, fontSize: 12))) : ListView.builder(itemCount: receipts.length, itemBuilder: (_, i) => ReceiptTile(receipt: receipts[i], showDate: true)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceRow(String name, double book, double pending, String sym) {
    final eff = book - pending;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ink)),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('دفتري: ${_fmt(book)} $sym', style: const TextStyle(fontSize: 11, color: muted)),
          if (pending > 0) Text('معلق: -${_fmt(pending)}', style: const TextStyle(fontSize: 10, color: amber, fontWeight: FontWeight.bold)),
        ]),
        Text('${_fmt(eff)} $sym', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: eff > 0 ? red : green)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title; final String value; final IconData icon; final Color color;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderCol)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
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
    final statusColor = receipt.status == ReceiptStatus.draft
        ? muted
        : (receipt.status == ReceiptStatus.pending ? amber : green);
    final statusText = receipt.status == ReceiptStatus.draft
        ? 'مسودة'
        : (receipt.status == ReceiptStatus.pending ? 'بانتظار الترحيل' : 'مرحل للمركز');

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
                  '${receipt.number} • ${receipt.method}',
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
                if (showDate)
                  Text(
                    DateFormat('yyyy/MM/dd hh:mm a').format(receipt.createdAt),
                    style: const TextStyle(fontSize: 10, color: muted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${_fmt(receipt.amount)} ${receipt.currency.code}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: navy),
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
    final effective = customer.bookBalanceYER - pendingYER;
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
                  Text(
                    '${customer.code} • ${customer.area}',
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_fmt(effective)} ر.ي',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: effective > 0 ? red : green,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_left_rounded, color: muted, size: 20),
          ],
        ),
      ),
    );
  }
}
