import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/wallet/transfer_amount.dart';

void main() {
  group('TransferAmount', () {
    test('accepts only exact positive decimal wire values', () {
      const accepted = <String>[
        '1',
        '1.0',
        '1.2500',
        '0.1',
        '0.0100',
        '0.0010',
        '9999999999999999999999999999999999999999.00000001',
      ];

      for (final source in accepted) {
        final amount = TransferAmount.tryParse(source);
        expect(amount, isNotNull, reason: source);
        expect(amount!.wire, source, reason: source);
      }
    });

    test('preserves trailing zeros in the display and future wire value', () {
      final amount = TransferAmount.tryParse('1.2500');

      expect(amount, isNotNull);
      expect(amount!.wire, '1.2500');
      expect(amount.displayWithAsset('ETH'), '1.2500 ETH');
    });

    test('accepts the exact maximum length and rejects longer values', () {
      final maximum = List<String>.filled(
        TransferAmount.maxWireLength,
        '1',
      ).join();

      expect(TransferAmount.tryParse(maximum), isNotNull);
      expect(TransferAmount.tryParse('${maximum}1'), isNull);
    });

    test('rejects noncanonical, zero, signed, exponent, and spaced input', () {
      const rejected = <String>[
        '',
        '0',
        '0.0',
        '0.000',
        '00.1',
        '01',
        '01.0',
        '+1',
        '-1',
        '.5',
        '1.',
        '1e3',
        '1E3',
        ' 1',
        '1 ',
        '1,000',
        '1\n',
        '1\r\n',
        '1\u2028',
        '1\u2029',
      ];

      for (final source in rejected) {
        expect(TransferAmount.tryParse(source), isNull, reason: source);
      }
    });
  });
}
