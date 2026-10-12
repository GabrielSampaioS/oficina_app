/// Validações de formulário. Cada função devolve a mensagem de erro, ou `null`
/// quando o valor é válido (formato esperado por `TextFormField.validator`).
/// O servidor continua sendo a fonte da verdade; isto só dá feedback imediato.
library;

String? validateName(String? v) {
  if ((v ?? '').trim().length < 2)
    return 'Informe o nome (mínimo 2 caracteres).';
  return null;
}

String? validatePhone(String? v) {
  final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.length < 10 || digits.length > 11) {
    return 'Telefone com DDD (10 ou 11 dígitos).';
  }
  return null;
}

String normalizePlate(String raw) =>
    raw.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

String normalizeChassis(String raw) =>
    raw.replaceAll(RegExp(r'\s'), '').toUpperCase();

final RegExp _plate = RegExp(r'^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$');
final RegExp _chassis = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$');


String? validatePlate(String? v) {
  if (!_plate.hasMatch(normalizePlate(v ?? ''))) {
    return 'Placa inválida (ex.: ABC1D23 ou ABC-1234).';
  }
  return null;
}

String? validateChassi(String? v) {
  if(!_chassis.hasMatch(normalizeChassis(v ?? ''))){
    return 'Chassi inválido (deve conter 17 caracteres).';
  }

  return null;
}

String? validateModel(String? v) {
  if ((v ?? '').trim().length < 2) return 'Informe o modelo.';
  return null;
}

String? validateYear(String? v, {required int currentYear}) {
  final year = int.tryParse((v ?? '').trim());
  if (year == null || year < 1950 || year > currentYear + 1) {
    return 'Ano inválido.';
  }
  return null;
}

String? validateComplaint(String? v) {
  final t = (v ?? '').trim();
  if (t.length < 3) return 'Descreva a queixa (mínimo 3 caracteres).';
  if (t.length > 2000) return 'Queixa muito longa (máximo 2000).';
  return null;
}

String? validateDescription(String? v) {
  if ((v ?? '').trim().length < 3)
    return 'Descreva o serviço (mínimo 3 caracteres).';
  return null;
}

/// Converte "250" ou "250,50" em centavos. Formato estrito: dígitos com no
/// máximo duas casas após a vírgula. Ponto é rejeitado de propósito, porque
/// "1.250" seria ambíguo (milhar ou decimal) e erro em dinheiro é caro.
int? parseMoneyToCents(String input) {
  final t = input.trim().replaceAll('R\$', '').replaceAll(' ', '');
  final m = RegExp(r'^(\d+)(?:,(\d{1,2}))?$').firstMatch(t);
  if (m == null) return null;
  final reais = int.parse(m.group(1)!);
  final cents = int.parse((m.group(2) ?? '0').padRight(2, '0'));
  return reais * 100 + cents;
}

String? validateMoney(String? v) {
  if (parseMoneyToCents(v ?? '') == null) {
    return 'Valor no formato 250,00 (sem ponto de milhar).';
  }
  return null;
}

String formatMoney(int cents) {
  final reais = cents ~/ 100;
  final c = (cents % 100).toString().padLeft(2, '0');
  return 'R\$ $reais,$c';
}
