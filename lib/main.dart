import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const DawacomApp());
}

// ============================================================
// THEME & PALETTE
// ============================================================
class DawacomTheme {
  static const background = Color(0xFF071426);
  static const surface = Color(0xFF10233B);
  static const surface2 = Color(0xFF152B45);
  static const border = Color(0xFF263D56);

  static const gold = Color(0xFFD6AD55);
  static const teal = Color(0xFF14B8A6);
  static const red = Color(0xFFEF6464);
  static const amber = Color(0xFFF59E0B);
  static const blue = Color(0xFF38BDF8);

  static const white = Color(0xFFF1F5F9);
  static const muted = Color(0xFF91A4BA);
}

// ============================================================
// DOMAIN MODELS
// ============================================================
class Customer {
  final int id;
  final String name;
  final double currentBalance;
  final String phone;
  final String city;

  const Customer({
    required this.id,
    required this.name,
    required this.currentBalance,
    required this.phone,
    required this.city,
  });
}

enum PaymentType { cash, transfer }

enum ReceiptStatus {
  draft,     // مسودة
  pending,   // بانتظار الترحيل
  posted,    // مرحّل فعلياً
}

class ReceiptItem {
  final String receiptNumber;
  final Customer customer;
  final double amount;
  final PaymentType paymentType;
  final String? network;
  final String? transferNumber;
  final String notes;
  final ReceiptStatus status;
  final DateTime createdAt;

  const ReceiptItem({
    required this.receiptNumber,
    required this.customer,
    required this.amount,
    required this.paymentType,
    this.network,
    this.transferNumber,
    required this.notes,
    required this.status,
    required this.createdAt,
  });
}

// ============================================================
// DATA STORE (OFFLINE-FIRST)
// ============================================================
class LocalReceiptStore {
  static final LocalReceiptStore _instance = LocalReceiptStore._internal();
  factory LocalReceiptStore() => _instance;
  LocalReceiptStore._internal();

  final List<ReceiptItem> _receipts = [
    ReceiptItem(
      receiptNumber: 'REC-904120',
      customer: const Customer(
        id: 102,
        name: 'صيدلية النور الحديثة',
        currentBalance: 420000,
        phone: '771234567',
        city: 'صنعاء - حدة',
      ),
      amount: 120000,
      paymentType: PaymentType.cash,
      notes: 'دفعة سداد فاتورة 481',
      status: ReceiptStatus.pending,
      createdAt: DateTime.now(),
    ),
  ];

  List<ReceiptItem> getReceipts() => List.unmodifiable(_receipts);

  void addReceipt(ReceiptItem item) {
    _receipts.insert(0, item);
  }
}

// ============================================================
// APP ENTRY POINT
// ============================================================
class DawacomApp extends StatelessWidget {
  const DawacomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'دواكم - تحصيل الموزعين',
      theme: ThemeData(
        fontFamily: 'sans-serif',
        scaffoldBackgroundColor: DawacomTheme.background,
        colorScheme: const ColorScheme.dark(
          primary: DawacomTheme.gold,
          surface: DawacomTheme.surface,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

// ============================================================
// 1. LOGIN SCREEN
// ============================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pinController = TextEditingController(text: '1001');
  bool _loading = false;

  void _login() {
    if (_pinController.text.trim().length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال رمز موزع صالح (4 أرقام)'),
          backgroundColor: DawacomTheme.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShellScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.local_shipping_rounded, size: 68, color: DawacomTheme.gold),
                const SizedBox(height: 14),
                const Text(
                  'محلات دواكم للأدوية والمستلزمات',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: DawacomTheme.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'نظام تحصيل الموزعين الميداني',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: DawacomTheme.muted, fontSize: 13),
                ),
                const SizedBox(height: 38),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: DawacomTheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: DawacomTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'الرمز التعريفي للموزع (PIN)',
                        style: TextStyle(color: DawacomTheme.muted, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 4,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: DawacomTheme.white, fontSize: 28, letterSpacing: 14, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: DawacomTheme.surface2,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DawacomTheme.gold,
                            foregroundColor: DawacomTheme.background,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: DawacomTheme.background))
                              : const Text('تسجيل الدخول للميدان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'المرحلة 1: تجربة الواجهة ونظام السندات دون اتصال',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: DawacomTheme.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MAIN SHELL SCREEN (BOTTOM NAV)
// ============================================================
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    CustomersListScreen(),
    ReceiptsLogScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: _pages[_currentIndex],
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: DawacomTheme.border)),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            backgroundColor: DawacomTheme.surface,
            selectedItemColor: DawacomTheme.gold,
            unselectedItemColor: DawacomTheme.muted,
            onTap: (i) => setState(() => _currentIndex = i),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.storefront_rounded),
                label: 'العملاء والمديونيات',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_rounded),
                label: 'سجل السندات',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 2. CUSTOMERS LIST SCREEN
// ============================================================
class CustomersListScreen extends StatefulWidget {
  const CustomersListScreen({super.key});

  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<Customer> _allCustomers = const [
    Customer(id: 101, name: 'صيدلية الأمل الحديثة', currentBalance: 850000, phone: '777000111', city: 'صنعاء - التحرير'),
    Customer(id: 102, name: 'صيدلية النور المركزية', currentBalance: 420000, phone: '771234567', city: 'صنعاء - حدة'),
    Customer(id: 103, name: 'صيدلية الحياة التخصصية', currentBalance: 1250000, phone: '773334445', city: 'صنعاء - شميلة'),
    Customer(id: 104, name: 'صيدلية المستقبل الحديثة', currentBalance: 95000, phone: '775556667', city: 'صنعاء - الحصبة'),
    Customer(id: 105, name: 'صيدلية ابن سينا للأدوية', currentBalance: 0, phone: '778889990', city: 'صنعاء - مذبح'),
  ];

  String _query = '';

  String _formatMoney(double amount) => NumberFormat('#,##0', 'en_US').format(amount);

  @override
  Widget build(BuildContext context) {
    final filtered = _allCustomers.where((c) {
      return c.name.contains(_query) || c.id.toString().contains(_query) || c.city.contains(_query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: DawacomTheme.background,
        elevation: 0,
        title: const Text('دليل العملاء والمديونيات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: DawacomTheme.white)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: DawacomTheme.white),
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'ابحث باسم الصيدلية أو الكود أو المنطقة...',
                hintStyle: const TextStyle(color: DawacomTheme.muted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: DawacomTheme.gold),
                filled: true,
                fillColor: DawacomTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: DawacomTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: DawacomTheme.border)),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (ctx, index) {
                final c = filtered[index];
                return _buildCustomerItem(c);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerItem(Customer c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DawacomTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DawacomTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: DawacomTheme.surface2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront_rounded, color: DawacomTheme.gold, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(c.name, style: const TextStyle(color: DawacomTheme.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(width: 8),
                    Text('#${c.id}', style: const TextStyle(color: DawacomTheme.gold, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(c.city, style: const TextStyle(color: DawacomTheme.muted, fontSize: 12)),
                const SizedBox(height: 6),
                Text(
                  'المديونية: ${_formatMoney(c.currentBalance)} ر.ي',
                  style: TextStyle(
                    color: c.currentBalance > 0 ? DawacomTheme.red : DawacomTheme.teal,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReceiptEntryScreen(customer: c),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DawacomTheme.gold,
              foregroundColor: DawacomTheme.background,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('قبض', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 3. RECEIPT ENTRY SCREEN
// ============================================================
class ReceiptEntryScreen extends StatefulWidget {
  final Customer customer;
  const ReceiptEntryScreen({super.key, required this.customer});

  @override
  State<ReceiptEntryScreen> createState() => _ReceiptEntryScreenState();
}

class _ReceiptEntryScreenState extends State<ReceiptEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _transferController = TextEditingController();
  final _notesController = TextEditingController();

  PaymentType _paymentType = PaymentType.cash;
  String _network = 'الكريمي';
  bool _saving = false;

  double get _amount => double.tryParse(_amountController.text) ?? 0;
  double get _remaining => widget.customer.currentBalance - _amount;

  final List<String> _networks = ['الكريمي', 'النجم', 'الامتياز', 'يمن إكسبرس', 'المريسي', 'أخرى'];

  String _formatMoney(double amount) => NumberFormat('#,##0', 'en_US').format(amount);

  String _tafqeetYER(double amount) {
    int val = amount.toInt();
    if (val <= 0) return 'صفر ريال يمني لا غير';

    final Map<int, String> units = {
      1: 'واحد', 2: 'اثنان', 3: 'ثلاثة', 4: 'أربعة', 5: 'خمسة',
      6: 'ستة', 7: 'سبعة', 8: 'ثمانية', 9: 'تسعة', 10: 'عشرة',
      11: 'أحد عشر', 12: 'اثنا عشر', 13: 'ثلاثة عشر', 14: 'أربعة عشر',
      15: 'خمسة عشر', 16: 'ستة عشر', 17: 'سبعة عشر', 18: 'ثمانية عشر',
      19: 'تسعة عشر'
    };

    final Map<int, String> tens = {
      2: 'عشرون', 3: 'ثلاثون', 4: 'أربعون', 5: 'خمسون',
      6: 'ستون', 7: 'سبعون', 8: 'ثمانون', 9: 'تسعون'
    };

    final Map<int, String> hundreds = {
      1: 'مائة', 2: 'مئتان', 3: 'ثلاثمائة', 4: 'أربعمائة', 5: 'خمسمائة',
      6: 'ستمائة', 7: 'سبعمائة', 8: 'ثمانمائة', 9: 'تسعمائة'
    };

    String convertThreeDigits(int n) {
      String res = '';
      int h = n ~/ 100;
      int rem = n % 100;
      if (h > 0) res += hundreds[h]!;
      if (rem > 0) {
        if (res.isNotEmpty) res += ' و';
        if (rem <= 19) {
          res += units[rem]!;
        } else {
          int t = rem ~/ 10;
          int u = rem % 10;
          res += u > 0 ? '${units[u]} و${tens[t]}' : tens[t]!;
        }
      }
      return res;
    }

    List<String> parts = [];
    int millions = val ~/ 1000000;
    int thousands = (val % 1000000) ~/ 1000;
    int remaining = val % 1000;

    if (millions > 0) {
      if (millions == 1) parts.add('مليون');
      else if (millions == 2) parts.add('مليونان');
      else if (millions <= 10) parts.add('${convertThreeDigits(millions)} ملايين');
      else parts.add('${convertThreeDigits(millions)} مليون');
    }

    if (thousands > 0) {
      if (thousands == 1) parts.add('ألف');
      else if (thousands == 2) parts.add('ألفان');
      else if (thousands <= 10) parts.add('${convertThreeDigits(thousands)} آلاف');
      else parts.add('${convertThreeDigits(thousands)} ألف');
    }

    if (remaining > 0) parts.add(convertThreeDigits(remaining));
    return 'فقط ${parts.join(' و')} ريال يمني لا غير';
  }

  void _submitReceipt(ReceiptStatus targetStatus) {
    if (targetStatus != ReceiptStatus.draft) {
      if (!_formKey.currentState!.validate()) return;
    } else {
      if (_amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى تحديد المبلغ لحفظ المسودة'), backgroundColor: DawacomTheme.red),
        );
        return;
      }
    }

    setState(() => _saving = true);

    final newReceipt = ReceiptItem(
      receiptNumber: 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      customer: widget.customer,
      amount: _amount,
      paymentType: _paymentType,
      network: _paymentType == PaymentType.transfer ? _network : null,
      transferNumber: _paymentType == PaymentType.transfer ? _transferController.text.trim() : null,
      notes: _notesController.text.trim(),
      status: targetStatus,
      createdAt: DateTime.now(),
    );

    LocalReceiptStore().addReceipt(newReceipt);

    setState(() => _saving = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: DawacomTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                targetStatus == ReceiptStatus.draft ? Icons.edit_note_rounded : Icons.schedule_send_rounded,
                color: targetStatus == ReceiptStatus.draft ? DawacomTheme.amber : DawacomTheme.blue,
              ),
              const SizedBox(width: 8),
              Text(
                targetStatus == ReceiptStatus.draft ? 'تم حفظ المسودة' : 'معتمد (بانتظار الترحيل)',
                style: const TextStyle(color: DawacomTheme.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            targetStatus == ReceiptStatus.draft
                ? 'تم حفظ السند كمسودة محلياً في هاتفك. يمكنك تعديله واعتماده لاحقاً.'
                : 'تم اعتماد السند رقم ${newReceipt.receiptNumber}.\nحالة السند: بانتظار الترحيل.\nلن يُسجل كمرحل حتى يتم الربط الفعلي مع Life Ex Pro في المرحلة 2.',
            style: const TextStyle(color: DawacomTheme.muted, fontSize: 13, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: DawacomTheme.gold,
                foregroundColor: DawacomTheme.background,
              ),
              child: const Text('إغلاق والعودة'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: DawacomTheme.background,
          elevation: 0,
          title: const Text('تسجيل سند قبض', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: DawacomTheme.white)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _buildCustomerCard(),
                const SizedBox(height: 18),
                _buildPaymentTypeSwitch(),
                const SizedBox(height: 18),
                _buildAmountInputCard(),
                if (_paymentType == PaymentType.transfer) ...[
                  const SizedBox(height: 18),
                  _buildTransferDetailsCard(),
                ],
                const SizedBox(height: 18),
                _buildNotesCard(),
                const SizedBox(height: 26),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DawacomTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DawacomTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.customer.name, style: const TextStyle(color: DawacomTheme.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text('#${widget.customer.id}', style: const TextStyle(color: DawacomTheme.gold, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(widget.customer.city, style: const TextStyle(color: DawacomTheme.muted, fontSize: 12)),
          const Divider(color: DawacomTheme.border, height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الرصيد المقيد حالياً', style: TextStyle(color: DawacomTheme.muted, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text('${_formatMoney(widget.customer.currentBalance)} ر.ي', style: const TextStyle(color: DawacomTheme.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('الرصيد التقديري بعد السند', style: TextStyle(color: DawacomTheme.muted, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text('${_formatMoney(_remaining)} ر.ي', style: const TextStyle(color: DawacomTheme.teal, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTypeSwitch() {
    return Row(
      children: [
        Expanded(
          child: _typeTab('كاش (نقدي)', Icons.payments_outlined, _paymentType == PaymentType.cash, () {
            setState(() => _paymentType = PaymentType.cash);
          }),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _typeTab('حوالة بنكية', Icons.account_balance_outlined, _paymentType == PaymentType.transfer, () {
            setState(() => _paymentType = PaymentType.transfer);
          }),
        ),
      ],
    );
  }

  Widget _typeTab(String title, IconData icon, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: active ? DawacomTheme.surface2 : DawacomTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? DawacomTheme.gold : DawacomTheme.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: active ? DawacomTheme.gold : DawacomTheme.muted),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: active ? DawacomTheme.white : DawacomTheme.muted, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountInputCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DawacomTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DawacomTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('المبلغ المقبوض (ريال يمني)', style: TextStyle(color: DawacomTheme.muted, fontSize: 12)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: DawacomTheme.white, fontSize: 30, fontWeight: FontWeight.w900),
            onChanged: (v) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(color: DawacomTheme.muted),
              border: InputBorder.none,
            ),
            validator: (v) {
              if (v == null || v.isEmpty || double.tryParse(v) == null || double.parse(v) <= 0) {
                return 'أدخل مبلغاً صالحاً';
              }
              return null;
            },
          ),
          if (_amount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DawacomTheme.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: DawacomTheme.border),
              ),
              child: Text(
                _tafqeetYER(_amount),
                style: const TextStyle(color: DawacomTheme.gold, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              _amountQuickChip('+50,000', 50000),
              _amountQuickChip('+100,000', 100000),
              InkWell(
                onTap: () {
                  _amountController.text = widget.customer.currentBalance.toStringAsFixed(0);
                  setState(() {});
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: DawacomTheme.gold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('كامل الرصيد', style: TextStyle(color: DawacomTheme.background, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amountQuickChip(String label, double val) {
    return InkWell(
      onTap: () {
        final current = double.tryParse(_amountController.text) ?? 0;
        _amountController.text = (current + val).toStringAsFixed(0);
        setState(() {});
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: DawacomTheme.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: DawacomTheme.border),
        ),
        child: Text(label, style: const TextStyle(color: DawacomTheme.white, fontSize: 11)),
      ),
    );
  }

  Widget _buildTransferDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DawacomTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DawacomTheme.border),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _network,
            dropdownColor: DawacomTheme.surface2,
            style: const TextStyle(color: DawacomTheme.white),
            decoration: const InputDecoration(labelText: 'شبكة الصرافة / التحويل', filled: true, fillColor: DawacomTheme.surface2),
            items: _networks.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _network = v);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _transferController,
            style: const TextStyle(color: DawacomTheme.white),
            decoration: const InputDecoration(labelText: 'رقم السند أو إشعار الحوالة', filled: true, fillColor: DawacomTheme.surface2),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'رقم الحوالة مطلوب' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return TextFormField(
      controller: _notesController,
      maxLines: 2,
      style: const TextStyle(color: DawacomTheme.white),
      decoration: const InputDecoration(
        labelText: 'ملاحظات إضافية (اختياري)',
        filled: true,
        fillColor: DawacomTheme.surface,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _saving ? null : () => _submitReceipt(ReceiptStatus.pending),
            style: ElevatedButton.styleFrom(
              backgroundColor: DawacomTheme.gold,
              foregroundColor: DawacomTheme.background,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: DawacomTheme.background, strokeWidth: 2))
                : const Text('اعتماد (بانتظار الترحيل)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: _saving ? null : () => _submitReceipt(ReceiptStatus.draft),
            style: OutlinedButton.styleFrom(
              foregroundColor: DawacomTheme.white,
              side: const BorderSide(color: DawacomTheme.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('مسودة'),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 4. RECEIPTS LOG SCREEN
// ============================================================
class ReceiptsLogScreen extends StatefulWidget {
  const ReceiptsLogScreen({super.key});

  @override
  State<ReceiptsLogScreen> createState() => _ReceiptsLogScreenState();
}

class _ReceiptsLogScreenState extends State<ReceiptsLogScreen> {
  ReceiptStatus? _selectedStatusFilter;

  String _formatMoney(double amount) => NumberFormat('#,##0', 'en_US').format(amount);

  @override
  Widget build(BuildContext context) {
    final all = LocalReceiptStore().getReceipts();
    final filtered = _selectedStatusFilter == null
        ? all
        : all.where((r) => r.status == _selectedStatusFilter).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: DawacomTheme.background,
        elevation: 0,
        title: const Text('سجل سندات التحصيل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: DawacomTheme.white)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('لا توجد سندات في هذا التصنيف', style: TextStyle(color: DawacomTheme.muted)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, idx) => _buildReceiptCard(filtered[idx]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _filterBadge('الكل', null),
          _filterBadge('بانتظار الترحيل', ReceiptStatus.pending),
          _filterBadge('مسودة', ReceiptStatus.draft),
          _filterBadge('مرحّل', ReceiptStatus.posted),
        ],
      ),
    );
  }

  Widget _filterBadge(String title, ReceiptStatus? status) {
    final active = _selectedStatusFilter == status;
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: InkWell(
        onTap: () => setState(() => _selectedStatusFilter = status),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? DawacomTheme.gold : DawacomTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? DawacomTheme.gold : DawacomTheme.border),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: active ? DawacomTheme.background : DawacomTheme.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptCard(ReceiptItem r) {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    switch (r.status) {
      case ReceiptStatus.posted:
        badgeColor = DawacomTheme.teal;
        badgeText = 'مرحّل بالسيرفر';
        badgeIcon = Icons.done_all_rounded;
        break;
      case ReceiptStatus.pending:
        badgeColor = DawacomTheme.blue;
        badgeText = 'بانتظار الترحيل';
        badgeIcon = Icons.hourglass_top_rounded;
        break;
      case ReceiptStatus.draft:
        badgeColor = DawacomTheme.amber;
        badgeText = 'مسودة محليّة';
        badgeIcon = Icons.edit_note_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DawacomTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DawacomTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(r.receiptNumber, style: const TextStyle(color: DawacomTheme.gold, fontWeight: FontWeight.bold, fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor),
                ),
                child: Row(
                  children: [
                    Icon(badgeIcon, size: 13, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(badgeText, style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(r.customer.name, style: const TextStyle(color: DawacomTheme.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatMoney(r.amount)} ر.ي (${r.paymentType == PaymentType.cash ? "كاش" : r.network ?? "حوالة"})',
                style: const TextStyle(color: DawacomTheme.white, fontSize: 13),
              ),
              Text(
                DateFormat('yyyy/MM/dd hh:mm a').format(r.createdAt),
                style: const TextStyle(color: DawacomTheme.muted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
