import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse_collector/main.dart';

void main() {
  group('Password security', () {
    test('same password and salt produce the same derived key', () async {
      final salt = List<int>.generate(16, (i) => i + 1);
      final first = await derivePasswordHash('Correct-Horse-42!', salt);
      final second = await derivePasswordHash('Correct-Horse-42!', salt);
      expect(first, second);
    });

    test('different salts produce different derived keys', () async {
      final saltA = List<int>.generate(16, (i) => i + 1);
      final saltB = List<int>.generate(16, (i) => i + 2);
      final first = await derivePasswordHash('Correct-Horse-42!', saltA);
      final second = await derivePasswordHash('Correct-Horse-42!', saltB);
      expect(first, isNot(second));
    });

    test('different passwords produce different derived keys', () async {
      final salt = List<int>.generate(16, (i) => i + 1);
      final first = await derivePasswordHash('Correct-Horse-42!', salt);
      final second = await derivePasswordHash('Different-Pass-93!', salt);
      expect(first, isNot(second));
    });
  });

  test('central user mapping preserves the server identity', () {
    final user = UserAccount.fromServerMap({
      'id': 42,
      'username': 'field.user',
      'displayName': 'Field User',
      'distributorCode': 'D-42',
      'role': 'distributor',
      'isActive': true,
    });
    expect(user.id, 42);
    expect(user.distributorCode, 'D-42');
    expect(user.isAdmin, isFalse);
  });

  test('central receipt mapping preserves server receipt fields', () {
    final receipt = ReceiptModel.fromServerMap({
      'id': 7,
      'operationId': 'operation-00000007',
      'number': 'DWK-D42-20261105-0007',
      'distributorCode': 'D42',
      'customerCode': 'C100',
      'customerName': 'Test Customer',
      'amount': 1250.50,
      'currency': 'yer',
      'method': 'نقد',
      'createdAtUtc': '2026-11-05T10:30:00Z',
    });
    expect(receipt.id, 7);
    expect(receipt.operationId, 'operation-00000007');
    expect(receipt.amount, 1250.50);
    expect(receipt.status, ReceiptStatus.posted);
    expect(receipt.syncStatus, 'synced');
    expect(receipt.currency, CurrencyType.yer);
  });

  test('user account model identifies administrator role', () {
    final user = UserAccount.fromMap({
      'id': 1,
      'username': 'admin',
      'display_name': 'System Admin',
      'distributor_code': 'ADMIN',
      'role': 'admin',
      'is_active': 1,
    });
    expect(user.isAdmin, isTrue);
    expect(user.isActive, isTrue);
  });
}
