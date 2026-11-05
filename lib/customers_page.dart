import 'package:flutter/material.dart';
import 'receipt_repository.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final searchController = TextEditingController();
  late Future<List<CustomerRecord>> future;

  @override
  void initState() {
    super.initState();
    future = repository.getCustomers();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void reload() {
    setState(() {
      future = repository.getCustomers(search: searchController.text);
    });
  }

  void showCustomerStatement(CustomerRecord customer) async {
    final receipts = await repository.getReceipts(customerCode: customer.code);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomerStatementSheet(
        customer: customer,
        receipts: receipts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: (_) => reload(),
                  decoration: const InputDecoration(
                    hintText: 'ابحث باسم العميل أو رقمه...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<CustomerRecord>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final customers = snapshot.data ?? [];

              if (customers.isEmpty) {
                return const Center(
                  child: Text('لا يوجد عملاء مطابقة للبحث'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(15),
                itemCount: customers.length,
                itemBuilder: (context, index) {
                  final customer = customers[index];

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: const BorderSide(color: Color(0xFFE7EBF1)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      onTap: () => showCustomerStatement(customer),
                      title: Text(
                        customer.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          'الكود: ${customer.code} • ${customer.area}',
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ),
                      trailing: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Color(0xFF0B1F3A),
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

class CustomerStatementSheet extends StatelessWidget {
  final CustomerRecord customer;
  final List<Receipt> receipts;

  const CustomerStatementSheet({
    super.key,
    required this.customer,
    required this.receipts,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              customer.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'كود العميل: ${customer.code} • المنطقة: ${customer.area}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const Divider(height: 25),
            const Text(
              'الأرصدة الدفترية المسجلة:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE7EBF1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _balanceItem('يمني', customer.balanceYer, 'ر.ي'),
                  _balanceItem('سعودي', customer.balanceSar, 'ر.س'),
                  _balanceItem('دولار', customer.balanceUsd, '\$'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'سندات التحصيل المحلية للعميل',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: receipts.isEmpty
                  ? const Center(child: Text('لا توجد سندات محلية مسجلة لهذا العميل'))
                  : ListView.builder(
                      itemCount: receipts.length,
                      itemBuilder: (context, index) {
                        final r = receipts[index];
                        return ListTile(
                          title: Text('${r.amount} ${r.currency.name.toUpperCase()}'),
                          subtitle: Text('رقم السند: ${r.number} - الطريقة: ${r.method}'),
                          trailing: Text(r.status.name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceItem(String label, double val, String symbol) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 3),
        Text(
          '$val $symbol',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}
