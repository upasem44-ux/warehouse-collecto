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
