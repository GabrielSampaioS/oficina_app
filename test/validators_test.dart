import 'package:flutter_test/flutter_test.dart';
import 'package:oficina_app/domain/validators.dart';

void main() {
  group('parseMoneyToCents', () {
    test('converte inteiros e decimais com vírgula', () {
      expect(parseMoneyToCents('250'), 25000);
      expect(parseMoneyToCents('250,5'), 25050);
      expect(parseMoneyToCents('250,50'), 25050);
      expect(parseMoneyToCents('0'), 0);
      expect(parseMoneyToCents(' R\$ 99,90 '), 9990);
    });

    test('rejeita formatos ambíguos ou inválidos', () {
      for (final bad in ['', 'abc', '1.250', '1.250,00', '10,999', '-5', '10,', ',50']) {
        expect(parseMoneyToCents(bad), isNull, reason: 'entrada: "$bad"');
      }
    });

    test('formatMoney é o inverso para valores válidos', () {
      expect(formatMoney(25050), 'R\$ 250,50');
      expect(formatMoney(5), 'R\$ 0,05');
      expect(formatMoney(0), 'R\$ 0,00');
    });
  });

  group('placa', () {
    test('aceita antiga e Mercosul, com hífen ou espaço', () {
      expect(validatePlate('ABC1D23'), isNull);
      expect(validatePlate('abc-1234'), isNull);
      expect(validatePlate('ABC 1D23'), isNull);
      expect(normalizePlate('abc-1234'), 'ABC1234');
    });

    test('rejeita inválidas', () {
      for (final bad in ['', 'AB1234', 'ABCD123', '1234ABC', 'ABC12345']) {
        expect(validatePlate(bad), isNotNull, reason: 'entrada: "$bad"');
      }
    });
  });

  group('demais validadores', () {
    test('nome, telefone, modelo, queixa e descrição', () {
      expect(validateName('A'), isNotNull);
      expect(validateName('Ana'), isNull);
      expect(validatePhone('12345'), isNotNull);
      expect(validatePhone('(19) 99999-1234'), isNull);
      expect(validateModel(' '), isNotNull);
      expect(validateComplaint('ab'), isNotNull);
      expect(validateComplaint('abc'), isNull);
      expect(validateComplaint('x' * 2001), isNotNull);
      expect(validateDescription('ab'), isNotNull);
    });

    test('ano respeita os limites (1950 até ano atual + 1)', () {
      expect(validateYear('1949', currentYear: 2026), isNotNull);
      expect(validateYear('1950', currentYear: 2026), isNull);
      expect(validateYear('2027', currentYear: 2026), isNull);
      expect(validateYear('2028', currentYear: 2026), isNotNull);
      expect(validateYear('abc', currentYear: 2026), isNotNull);
    });
  });
}
