import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'receipt_repository.dart';

class CollectPage extends StatefulWidget {
  const CollectPage({super.key});

  @override
  State<CollectPage> createState() => _CollectPageState();
}

class _CollectPageState extends State<CollectPage> {
  final formKey = GlobalKey<FormState>();

  final amountController = TextEditingController();
  final transferController = TextEditingController();
  final noteController = TextEditingController();

  List<CustomerRecord> customers = [];
  CustomerRecord? selectedCustomer;

  CurrencyType currency = CurrencyType.yer;
  String method = 'نقد';
  String network = 'الكريمي';

  bool loadingCustomers = true;
  bool saving = false;

  final List<String> networksList = [
    'الكريمي',
    'النجم',
    'الامتياز',
    'يمن إكسبرس',
    'المريسي',
    'أخرى'
  ];

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
      final result = await repository.getCustomers();
      if (!mounted) return;
      setState(() {
        customers = result;
        loadingCustomers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loadingCustomers = false);
      showMessage('تعذر تحميل العملاء: $e', error: true);
    }
  }

  void openCustomerSearch() async {
    final chosen = await showModalBottomSheet<CustomerRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerSearchModal(customers: customers),
    );

    if (chosen != null) {
      setState(() => selectedCustomer = chosen);
    }
  }

  Future<void> saveReceipt() async {
    if (!formKey.currentState!.validate()) return;

    if (selectedCustomer == null) {
      showMessage('الرجاء اختيار العميل أو الصيدلية أولاً', error: true);
      return;
    }

    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      showMessage('أدخل مبلغاً صحيحاً', error: true);
      return;
    }

    setState(() => saving = true);

    try {
      final receipt = await repository.issueAndSaveReceipt(
        customerCode: selectedCustomer!.code,
        amount: amount,
        currency: currency,
        method: method,
        network: method == 'حوالة' ? network : null,
        transferRef: method == 'حوالة' ? transferController.text.trim() : null,
        note: noteController.text.trim(),
      );

      if (!mounted) return;

      amountController.clear();
      transferController.clear();
      noteController.clear();
      setState(() {
        saving = false;
        method = 'نقد';
        selectedCustomer = null;
      });

      showMessage('تم حفظ سند القبض محلياً بنجاح');
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      showMessage('خطأ في الحفظ: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'تسجيل سند قبض جديد',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          const Text('الصيدلية أو العميل المستلم منه:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          InkWell(
            onTap: loadingCustomers ? null : openCustomerSearch,
            borderRadius: BorderRadius.circular(13),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFFE7EBF1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.storefront_outlined, color: Color(0xFF0B1F3A)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedCustomer == null
                          ? 'انقر هنا للبحث السريع عن الصيدلية...'
                          : '${selectedCustomer!.name} (${selectedCustomer!.code})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selectedCustomer == null ? FontWeight.normal : FontWeight.bold,
                        color: selectedCustomer == null ? Colors.grey : const Color(0xFF172B45),
                      ),
                    ),
                  ),
                  const Icon(Icons.search, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('عملة السند:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          SegmentedButton<CurrencyType>(
            segments: const [
              ButtonSegment(value: CurrencyType.yer, label: Text('ريال يمني')),
              ButtonSegment(value: CurrencyType.sar, label: Text('سعودي')),
              ButtonSegment(value: CurrencyType.usd, label: Text('دولار')),
            ],
            selected: {currency},
            onSelectionChanged: (val) => setState(() => currency = val.first),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: const InputDecoration(
              labelText: 'مبلغ التحصيل',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
            validator: (value) => value == null || value.isEmpty ? 'أدخل المبلغ' : null,
          ),
          const SizedBox(height: 20),
          const Text('طريقة القبض:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('نقداً (كاش)'),
                  value: 'نقد',
                  groupValue: method,
                  onChanged: (val) => setState(() => method = val!),
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('حوالة'),
                  value: 'حوالة',
                  groupValue: method,
                  onChanged: (val) => setState(() => method = val!),
                ),
              ),
            ],
          ),
          if (method == 'حوالة') ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: network,
              decoration: const InputDecoration(labelText: 'شبكة التحويل'),
              items: networksList.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
              onChanged: (val) => setState(() => network = val!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: transferController,
              decoration: const InputDecoration(labelText: 'رقم إشعار الحوالة'),
              validator: (val) => method == 'حوالة' && (val == null || val.isEmpty) ? 'أدخل رقم الحوالة' : null,
            ),
          ],
          const SizedBox(height: 20),
          TextFormField(
            controller: noteController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'ملاحظات إضافية (اختياري)'),
          ),
          const SizedBox(height: 25),
          SizedBox(
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0B1F3A)),
              onPressed: saving ? null : saveReceipt,
              child: saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('حفظ واعتماد السند محلياً', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerSearchModal extends StatefulWidget {
  final List<CustomerRecord> customers;
  const _CustomerSearchModal({required this.customers});

  @override
  State<_CustomerSearchModal> createState() => _CustomerSearchModalState();
}

class _CustomerSearchModalState extends State<_CustomerSearchModal> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.customers
        .where((c) => c.name.contains(query) || c.code.toLowerCase().contains(query.toLowerCase()) || c.area.contains(query))
        .toList();

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
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 15),
            const Text('بحث واختيار الصيدلية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              onChanged: (val) => setState(() => query = val.trim()),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'اكتب اسم الصيدلية أو الكود للبحث...',
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final c = filtered[index];
                  return ListTile(
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('الكود: ${c.code} • المنطقة: ${c.area}'),
                    trailing: const Icon(Icons.arrow_back_ios_new, size: 14, color: Colors.grey),
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
