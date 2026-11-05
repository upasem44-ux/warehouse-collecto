import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

enum CurrencyType { yer, sar, usd }
enum ReceiptStatus { draft, pending, posted }

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

  factory CustomerRecord.fromMap(Map<String, Object?> map) => CustomerRecord(
    code: map['code'] as String,
    name: map['name'] as String,
    area: map['area'] as String? ?? '',
    phone: map['phone'] as String? ?? '',
    balanceYer: (map['balance_yer'] as num?)?.toDouble() ?? 0,
    balanceSar: (map['balance_sar'] as num?)?.toDouble() ?? 0,
    balanceUsd: (map['balance_usd'] as num?)?.toDouble() ?? 0,
  );

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

class Receipt {
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
  final String shiftDate;
  final String syncStatus;

  const Receipt({
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
    required this.shiftDate,
    this.syncStatus = 'pending',
  });

  factory Receipt.fromMap(Map<String, Object?> map) => Receipt(
    id: map['id'] as int?,
    number: map['number'] as String,
    distributorCode: map['distributor_code'] as String,
    customerCode: map['customer_code'] as String,
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
    createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    shiftDate: map['shift_date'] as String? ?? '',
    syncStatus: map['sync_status'] as String? ?? 'pending',
  );

  Map<String, Object?> toMap() => {
    'number': number,
    'distributor_code': distributorCode,
    'customer_code': customerCode,
    'customer_name': customerName,
    'amount': amount,
    'currency': currency.name,
    'method': method,
    'network': network,
    'transfer_ref': transferRef,
    'note': note ?? '',
    'status': status.name,
    'created_at': createdAt.toIso8601String(),
    'shift_date': shiftDate,
    'sync_status': syncStatus,
  };
}

class ReceiptRepository {
  final DatabaseHelper _helper = DatabaseHelper.instance;
  static const String distributorCode = '1001';

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

  Future<String> _nextReceiptNumber(Transaction txn, String date) async {
    final rows = await txn.query(
      'daily_sequences',
      where: 'distributor_code = ? AND shift_date = ?',
      whereArgs: [distributorCode, date],
      limit: 1,
    );
    final next = rows.isEmpty ? 1 : (rows.first['last_number'] as num).toInt() + 1;
    if (rows.isEmpty) {
      await txn.insert('daily_sequences', {
        'distributor_code': distributorCode,
        'shift_date': date,
        'last_number': next,
      });
    } else {
      await txn.update(
        'daily_sequences',
        {'last_number': next},
        where: 'distributor_code = ? AND shift_date = ?',
        whereArgs: [distributorCode, date],
      );
    }
    return 'DWK-$distributorCode-$date-${next.toString().padLeft(4, '0')}';
  }

  Future<void> saveCustomer(CustomerRecord customer) async {
    final db = await _helper.database;
    await db.insert('customers', customer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveCustomers(List<CustomerRecord> customers) async {
    final db = await _helper.database;
    await db.transaction((txn) async {
      for (final customer in customers) {
        await txn.insert('customers', customer.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<CustomerRecord>> getCustomers({String search = ''}) async {
    final db = await _helper.database;
    final term = search.trim();
    final rows = await db.query(
      'customers',
      where: term.isEmpty ? null : 'name LIKE ? OR code LIKE ? OR phone LIKE ?',
      whereArgs: term.isEmpty ? null : ['%$term%', '%$term%', '%$term%'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(CustomerRecord.fromMap).toList();
  }

  Future<Receipt> issueAndSaveReceipt({
    required String customerCode,
    required double amount,
    required CurrencyType currency,
    required String method,
    String? network,
    String? transferRef,
    String? note,
  }) async {
    if (!amount.isFinite || amount <= 0 ||
        (amount * 100 - (amount * 100).round()).abs() > 0.000001) {
      throw Exception('أدخل مبلغاً صحيحاً أكبر من صفر وبحد أقصى منزلتين عشريتين');
    }
    if (method == 'حوالة' &&
        ((network == null || network.trim().isEmpty) ||
         (transferRef == null || transferRef.trim().isEmpty))) {
      throw Exception('حدد شبكة الحوالة وأدخل رقم إشعارها');
    }

    final db = await _helper.database;
    final now = DateTime.now();
    final date = _dateKey(now);
    return db.transaction((txn) async {
      final customerRows = await txn.query('customers',
        where: 'code = ?', whereArgs: [customerCode], limit: 1);
      if (customerRows.isEmpty) throw Exception('العميل غير موجود');

      final customer = CustomerRecord.fromMap(customerRows.first);
      if (method == 'حوالة') {
        final duplicate = await txn.query('receipts',
          columns: ['id'],
          where: "method = ? AND network = ? AND transfer_ref = ? AND status != 'draft'",
          whereArgs: [method, network!.trim(), transferRef!.trim()],
          limit: 1);
        if (duplicate.isNotEmpty) throw Exception('رقم الحوالة مسجل مسبقاً');
      }

      final receipt = Receipt(
        number: await _nextReceiptNumber(txn, date),
        distributorCode: distributorCode,
        customerCode: customer.code,
        customerName: customer.name,
        amount: amount,
        currency: currency,
        method: method,
        network: network?.trim(),
        transferRef: transferRef?.trim(),
        note: note?.trim(),
        status: ReceiptStatus.pending,
        createdAt: now,
        shiftDate: date,
        syncStatus: 'pending',
      );
      final id = await txn.insert('receipts', receipt.toMap());
      return Receipt(
        id: id, number: receipt.number,
        distributorCode: receipt.distributorCode,
        customerCode: receipt.customerCode,
        customerName: receipt.customerName,
        amount: receipt.amount, currency: receipt.currency,
        method: receipt.method, network: receipt.network,
        transferRef: receipt.transferRef, note: receipt.note,
        status: receipt.status, createdAt: receipt.createdAt,
        shiftDate: receipt.shiftDate, syncStatus: receipt.syncStatus,
      );
    });
  }

  Future<List<Receipt>> getReceipts({String? customerCode, int limit = 500}) async {
    final db = await _helper.database;
    final rows = await db.query('receipts',
      where: customerCode == null ? null : 'customer_code = ?',
      whereArgs: customerCode == null ? null : [customerCode],
      orderBy: 'id DESC', limit: limit);
    return rows.map(Receipt.fromMap).toList();
  }

  Future<Map<String, double>> getLocalTotals() async {
    final db = await _helper.database;
    final rows = await db.rawQuery("""
      SELECT currency, SUM(amount) AS total
      FROM receipts WHERE status != 'draft'
      GROUP BY currency
    """);
    final totals = <String, double>{'yer': 0, 'sar': 0, 'usd': 0};
    for (final row in rows) {
      final key = row['currency'] as String?;
      if (key != null) totals[key] = (row['total'] as num?)?.toDouble() ?? 0;
    }
    return totals;
  }

  Future<int> getPendingCount() async {
    final db = await _helper.database;
    final result = await db.rawQuery("""
      SELECT COUNT(*) AS total FROM receipts
      WHERE sync_status IN ('pending', 'failed') AND status != 'draft'
    """);
    return (result.first['total'] as num).toInt();
  }

  Future<void> close() => _helper.close();
}

/// Shared repository instance used by the customer and receipt screens.
final ReceiptRepository repository = ReceiptRepository();
