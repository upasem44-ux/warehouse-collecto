import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

enum CurrencyType { yer, sar, usd }
enum ReceiptStatus { draft, pending, posted }

class Receipt {
  final String number;
  final String customerCode;
  final String customerName;
  final double amount;
  final CurrencyType currency;
  final String method;
  final String? network;
  final String? transferRef;
  final String note;
  final ReceiptStatus status;
  final DateTime createdAt;

  const Receipt({
    required this.number,
    required this.customerCode,
    required this.customerName,
    required this.amount,
    required this.currency,
    required this.method,
    this.network,
    this.transferRef,
    required this.note,
    required this.status,
    required this.createdAt,
  });

  factory Receipt.fromDatabase(Map<String, Object?> row) {
    return Receipt(
      number: row['number'] as String,
      customerCode: row['customer_code'] as String,
      customerName: row['customer_name'] as String,
      amount: (row['amount'] as num).toDouble(),
      currency: CurrencyType.values.firstWhere(
        (e) => e.name == row['currency'],
        orElse: () => CurrencyType.yer,
      ),
      method: row['method'] as String,
      network: row['network'] as String?,
      transferRef: row['transfer_ref'] as String?,
      note: row['note'] as String? ?? '',
      status: ReceiptStatus.values.firstWhere(
        (e) => e.name == row['status'],
        orElse: () => ReceiptStatus.draft,
      ),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}

class ReceiptPersistenceException implements Exception {
  final String message;
  ReceiptPersistenceException(this.message);
  @override
  String toString() => message;
}

class ReceiptRepository {
  final DatabaseHelper _helper;

  ReceiptRepository({DatabaseHelper? helper})
      : _helper = helper ?? DatabaseHelper.instance;

  String _dateKey([DateTime? date]) {
    return DateFormat('yyMMdd').format(date ?? DateTime.now());
  }

  String _serial(String distributorCode, String date, int counter) {
    return 'DWK-$distributorCode-$date-${counter.toString().padLeft(4, '0')}';
  }

  String normalizeDigits(String input) {
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    for (int i = 0; i < arabic.length; i++) {
      input = input.replaceAll(arabic[i], english[i]);
    }
    return input.replaceAll(' ', '').trim();
  }

  Future<List<Receipt>> getReceipts() async {
    final db = await _helper.database;
    final rows = await db.query('receipts', orderBy: 'id DESC');
    return rows.map(Receipt.fromDatabase).toList();
  }

  Future<List<Receipt>> getCustomerReceipts(String customerCode) async {
    final db = await _helper.database;
    final rows = await db.query(
      'receipts',
      where: 'customer_code = ?',
      whereArgs: [customerCode],
      orderBy: 'id DESC',
    );
    return rows.map(Receipt.fromDatabase).toList();
  }

  Future<String> previewNextReceiptSerial(String distributorCode, ReceiptStatus status) async {
    final now = DateTime.now();
    final today = _dateKey(now);
    if (status == ReceiptStatus.draft) {
      return 'DRAFT-$distributorCode-${now.microsecondsSinceEpoch}';
    }

    final db = await _helper.database;
    final rows = await db.query(
      'daily_sequences',
      columns: ['last_number'],
      where: 'distributor_code = ? AND shift_date = ?',
      whereArgs: [distributorCode, today],
      limit: 1,
    );

    final last = rows.isEmpty ? 0 : (rows.first['last_number'] as int);
    return _serial(distributorCode, today, last + 1);
  }

  Future<Receipt> issueAndSaveReceipt({
    required String distributorCode,
    required String customerCode,
    required String customerName,
    required double amount,
    required CurrencyType currency,
    required String method,
    String? network,
    String? transferRef,
    required String note,
    required ReceiptStatus status,
    String? fixedDraftNumber,
  }) async {
    if (distributorCode.trim().isEmpty) {
      throw ArgumentError('كود الموزع مطلوب.');
    }
    if (customerCode.trim().isEmpty || customerName.trim().isEmpty) {
      throw ArgumentError('بيانات العميل غير مكتملة.');
    }
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('مبلغ السند غير صحيح.');
    }
    if ((amount * 100).roundToDouble() / 100 != amount) {
      throw ArgumentError('المبلغ لا يمكن أن يحتوي على أكثر من خانتين عشريتين.');
    }
    if (method != 'نقداً' && method != 'حوالة') {
      throw ArgumentError('طريقة القبض غير صحيحة.');
    }

    final cleanTransferRef = transferRef != null ? normalizeDigits(transferRef) : null;
    if (method == 'حوالة' &&
        (cleanTransferRef == null || cleanTransferRef.isEmpty) &&
        status != ReceiptStatus.draft) {
      throw ArgumentError('رقم إشعار الحوالة مطلوب.');
    }

    final db = await _helper.database;

    try {
      return await db.transaction((txn) async {
        final customer = await txn.query(
          'customers',
          columns: ['code'],
          where: 'code = ?',
          whereArgs: [customerCode],
          limit: 1,
        );

        if (customer.isEmpty) {
          throw StateError('العميل غير موجود في قاعدة البيانات المحلية: $customerCode');
        }

        final now = DateTime.now();
        final date = _dateKey(now);
        String receiptNumber;

        if (status == ReceiptStatus.draft) {
          receiptNumber = fixedDraftNumber ?? 'DRAFT-$distributorCode-${now.microsecondsSinceEpoch}';
        } else {
          final sequenceRows = await txn.query(
            'daily_sequences',
            columns: ['last_number'],
            where: 'distributor_code = ? AND shift_date = ?',
            whereArgs: [distributorCode, date],
            limit: 1,
          );

          final lastNumber = sequenceRows.isEmpty
              ? 0
              : (sequenceRows.first['last_number'] as int);

          final nextNumber = lastNumber + 1;
          receiptNumber = _serial(distributorCode, date, nextNumber);

          if (sequenceRows.isEmpty) {
            await txn.insert('daily_sequences', {
              'distributor_code': distributorCode,
              'shift_date': date,
              'last_number': nextNumber,
            });
          } else {
            await txn.update(
              'daily_sequences',
              {'last_number': nextNumber},
              where: 'distributor_code = ? AND shift_date = ?',
              whereArgs: [distributorCode, date],
            );
          }
        }

        final receipt = Receipt(
          number: receiptNumber,
          customerCode: customerCode,
          customerName: customerName,
          amount: amount,
          currency: currency,
          method: method,
          network: method == 'حوالة' ? network : null,
          transferRef: method == 'حوالة' ? cleanTransferRef : null,
          note: note.trim(),
          status: status,
          createdAt: now,
        );

        await txn.insert(
          'receipts',
          {
            'number': receipt.number,
            'distributor_code': distributorCode,
            'customer_code': receipt.customerCode,
            'customer_name': receipt.customerName,
            'amount': receipt.amount,
            'currency': receipt.currency.name,
            'method': receipt.method,
            'network': receipt.network,
            'transfer_ref': receipt.transferRef,
            'note': receipt.note,
            'status': receipt.status.name,
            'created_at': receipt.createdAt.toIso8601String(),
            'shift_date': date,
            'sync_status': 'pending',
            'synced_at': null,
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
        );

        return receipt;
      });
    } on DatabaseException catch (e) {
      final err = e.toString();
      if (e.isUniqueConstraintError() || err.contains('UNIQUE constraint failed')) {
        if (err.contains('receipts.transfer_ref') || err.contains('receipts.network')) {
          throw ReceiptPersistenceException('رقم إشعار الحوالة ($cleanTransferRef) مسجل مسبقاً لشبكة ($network).');
        }
        throw ReceiptPersistenceException('رقم السند مكرر في قاعدة البيانات.');
      }
      rethrow;
    }
  }

  Future<void> saveCustomers(List> customers) async {
    final db = await _helper.database;
    await db.transaction((txn) async {
      for (final customer in customers) {
        await txn.insert(
          'customers',
          {
            ...customer,
            'updated_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<double> getPendingTotal(String customerCode, CurrencyType currency) async {
    final db = await _helper.database;
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM receipts
      WHERE customer_code = ?
        AND currency = ?
        AND status = 'pending'
      ''',
      [customerCode, currency.name],
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<void> close() => _helper.close();
}
