import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const WarehouseCollectionApp());
}

class WarehouseCollectionApp extends StatelessWidget {
  const WarehouseCollectionApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'تحصيل المخازن',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
        fontFamily: 'sans-serif',
      ),
      home: const ReceiptEntryScreen(
        customer: Customer(
          id: 101,
          name: 'صيدلية الأمل الحديثة',
          currentBalance: 850000.0,
          phone: '777000111',
        ),
      ),
    );
  }
}

class Customer {
  final int id;
  final String name;
  final double currentBalance;
  final String phone;

  const Customer({
    required this.id,
    required this.name,
    required this.currentBalance,
    required this.phone,
  });
}

class ReceiptEntryScreen extends StatefulWidget {
  final Customer customer;

  const ReceiptEntryScreen({Key? key, required this.customer}) : super(key: key);

  @override
  State<ReceiptEntryScreen> createState() => _ReceiptEntryScreenState();
}

class _ReceiptEntryScreenState extends State<ReceiptEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _transferNumberController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _paymentType = 'كاش';
  String _selectedNetwork = 'الكريمي';
  double _paidAmount = 0.0;
  bool _isSaving = false;

  final List<String> _networks = [
    'الكريمي',
    'النجم',
    'الامتياز',
    'يمن إكسبرس',
    'المريسي',
    'أخرى'
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _transferNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    setState(() {
      _paidAmount = double.tryParse(val) ?? 0.0;
    });
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

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

      if (h > 0) {
        res += hundreds[h]!;
      }

      if (rem > 0) {
        if (res.isNotEmpty) res += ' و';
        if (rem <= 19) {
          res += units[rem]!;
        } else {
          int t = rem ~/ 10;
          int u = rem % 10;
          if (u > 0) {
            res += '${units[u]} و${tens[t]}';
          } else {
            res += tens[t]!;
          }
        }
      }
      return res;
    }

    List<String> parts = [];
    int millions = val ~/ 1000000;
    int thousands = (val % 1000000) ~/ 1000;
    int remaining = val % 1000;

    if (millions > 0) {
      if (millions == 1) {
        parts.add('مليون');
      } else if (millions == 2) {
        parts.add('مليونان');
      } else if (millions >= 3 && millions <= 10) {
        parts.add('${convertThreeDigits(millions)} ملايين');
      } else {
        parts.add('${convertThreeDigits(millions)} مليون');
      }
    }

    if (thousands > 0) {
      if (thousands == 1) {
        parts.add('ألف');
      } else if (thousands == 2) {
        parts.add('ألفان');
      } else if (thousands >= 3 && thousands <= 10) {
        parts.add('${convertThreeDigits(thousands)} آلاف');
      } else {
        parts.add('${convertThreeDigits(thousands)} ألف');
      }
    }

    if (remaining > 0) {
      parts.add(convertThreeDigits(remaining));
    }

    return 'فقط ${parts.join(' و')} ريال يمني لا غير';
  }

  void _saveReceipt() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    Future.delayed(const Duration(seconds: 1), () {
      setState(() => _isSaving = false);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('تم الحفظ بنجاح', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('العميل: ${widget.customer.name}'),
              Text('المبلغ: ${_formatCurrency(_paidAmount)} ر.ي'),
              Text('طريقة الدفع: $_paymentType'),
              if (_paymentType == 'حوالة') ...[
                Text('الشبكة: $_selectedNetwork'),
                Text('رقم الحوالة: ${_transferNumberController.text}'),
              ],
              const Divider(height: 20),
              Text(
                'الرصيد المتبقي: ${_formatCurrency(widget.customer.currentBalance - _paidAmount)} ر.ي',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _amountController.clear();
                _transferNumberController.clear();
                _notesController.clear();
                setState(() => _paidAmount = 0.0);
              },
              child: const Text('تم'),
            )
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final double remainingBalance = widget.customer.currentBalance - _paidAmount;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تسجيل سند قبض', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCustomerCard(remainingBalance),
                const SizedBox(height: 16),
                _buildPaymentTypeSelector(),
                const SizedBox(height: 16),
                _buildPaymentDetailsCard(),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveReceipt,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'تأكيد وحفظ السند',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerCard(double remainingBalance) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.customer.name,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF263238)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('كود: ${widget.customer.id}', style: TextStyle(color: Colors.blue.shade800, fontSize: 12)),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الرصيد السابق', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('${_formatCurrency(widget.customer.currentBalance)} ر.ي',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('الرصيد المتبقي بعد القبض', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatCurrency(remainingBalance)} ر.ي',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: remainingBalance < 0 ? Colors.red : Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            label: const Center(child: Text('كاش (نقدي)', style: TextStyle(fontWeight: FontWeight.bold))),
            selected: _paymentType == 'كاش',
            selectedColor: Colors.blue.shade600,
            labelStyle: TextStyle(color: _paymentType == 'كاش' ? Colors.white : Colors.black87),
            onSelected: (val) {
              if (val) setState(() => _paymentType = 'كاش');
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ChoiceChip(
            label: const Center(child: Text('حوالة مالية', style: TextStyle(fontWeight: FontWeight.bold))),
            selected: _paymentType == 'حوالة',
            selectedColor: Colors.blue.shade600,
            labelStyle: TextStyle(color: _paymentType == 'حوالة' ? Colors.white : Colors.black87),
            onSelected: (val) {
              if (val) setState(() => _paymentType = 'حوالة');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'المبلغ المقبوض (ريال يمني)',
              prefixIcon: Icon(Icons.monetization_on_outlined),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Color(0xFFFAFAFA),
            ),
            onChanged: _onAmountChanged,
            validator: (v) {
              if (v == null || v.isEmpty) return 'يرجى إدخال المبلغ';
              if (double.tryParse(v) == null || double.parse(v) <= 0) return 'المبلغ غير صحيح';
              return null;
            },
          ),
          if (_paidAmount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.translate, size: 18, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _tafqeetYER(_paidAmount),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_paymentType == 'حوالة') ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedNetwork,
              decoration: const InputDecoration(
                labelText: 'شبكة التحويل',
                prefixIcon: Icon(Icons.account_balance_outlined),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Color(0xFFFAFAFA),
              ),
              items: _networks.map((net) => DropdownMenuItem(value: net, child: Text(net))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedNetwork = val);
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _transferNumberController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'رقم الحوالة / السند البنكي',
                prefixIcon: Icon(Icons.tag),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Color(0xFFFAFAFA),
              ),
              validator: (v) {
                if (_paymentType == 'حوالة' && (v == null || v.isEmpty)) {
                  return 'يرجى إدخال رقم الحوالة';
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 14),
          TextFormField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'ملاحظات إضافية (اختياري)',
              prefixIcon: Icon(Icons.note_alt_outlined),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Color(0xFFFAFAFA),
            ),
          ),
        ],
      ),
    );
  }
}
