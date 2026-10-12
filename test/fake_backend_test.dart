import 'package:flutter_test/flutter_test.dart';
import 'package:oficina_app/data/api.dart';
import 'package:oficina_app/data/fake_backend.dart';
import 'package:oficina_app/domain/models.dart';

import 'support/pump_app.dart' show seedAssignedOrder;

Matcher throwsKind(ApiErrorKind kind) =>
    throwsA(isA<ApiException>().having((e) => e.kind, 'kind', kind));

Future<void> fillAll(FakeBackend b, String orderId) async {
  for (final g in defaultChecklist) {
    for (final c in g.components) {
      await b.saveCheck(
        orderId,
        group: g.name,
        component: c,
        classification: Classification.ok,
        note: '',
        photoIds: const [],
      );
    }
  }
}

/// O FakeBackend espelha as regras do servidor; estes testes garantem que o
/// espelho é fiel o bastante para os testes de widget serem confiáveis.
void main() {
  late FakeBackend b;
  setUp(() => b = FakeBackend.seeded(now: () => DateTime(2026, 10, 9)));

  test('login rejeita senha errada e exige sessão nas demais chamadas', () async {
    await expectLater(b.login('atendente', 'errada'), throwsKind(ApiErrorKind.unauthorized));
    await expectLater(b.listOrders(), throwsKind(ApiErrorKind.unauthorized));
  });

  test('offline faz toda chamada falhar com erro de rede', () async {
    await b.login('atendente', 'atendente123');
    b.offline = true;
    await expectLater(b.listOrders(), throwsKind(ApiErrorKind.network));
    b.offline = false;
    expect(await b.listOrders(), isEmpty);
  });

  test('mecânico só enxerga e acessa as próprias OS', () async {
    final mine = await seedAssignedOrder(b, mechanicId: 'u-mec1', plate: 'AAA1A11');
    final other = await seedAssignedOrder(b, mechanicId: 'u-mec2', plate: 'BBB2B22');
    await b.login('mecanico1', 'mecanico123');
    expect((await b.listOrders()).map((o) => o.id), [mine]);
    await expectLater(b.getOrder(other), throwsKind(ApiErrorKind.forbidden));
    await expectLater(b.openInspection(other), throwsKind(ApiErrorKind.forbidden));
  });

  test('filtra por status', () async {
    await seedAssignedOrder(b);
    await b.login('atendente', 'atendente123');
    await b.openOrder(
      customerName: 'Joana', customerPhone: '19988887777', plate: 'CCC3C33',  chassi: "9BD 111 060 SE 002156",
      model: 'Uno', year: 2010, complaint: 'Não liga',
    );
    expect((await b.listOrders(status: OrderStatus.aberta)).length, 1);
    expect((await b.listOrders(status: OrderStatus.atribuida)).length, 1);
    expect((await b.listOrders()).length, 2);
  });

  test('atendente não inspeciona; mecânico não abre OS nem decide serviços', () async {
    final id = await seedAssignedOrder(b);
    await b.login('atendente', 'atendente123');
    await expectLater(b.openInspection(id), throwsKind(ApiErrorKind.forbidden));
    await b.logout();
    await b.login('mecanico1', 'mecanico123');
    await expectLater(
      b.openOrder(
        customerName: 'Joana', customerPhone: '19988887777', plate: 'CCC3C33', chassi: "9BWZZZ37ZRE024618",
        model: 'Uno', year: 2010, complaint: 'Não liga',
      ),
      throwsKind(ApiErrorKind.forbidden),
    );
    await expectLater(b.decide('rec-x', approve: true), throwsKind(ApiErrorKind.forbidden));
  });

  test('inspeção: idempotente, exige observação em crítico e só finaliza completa', () async {
    final id = await seedAssignedOrder(b);
    await b.login('mecanico1', 'mecanico123');
    final first = await b.openInspection(id);
    expect((await b.openInspection(id)).id, first.id);
    expect((await b.getOrder(id)).status, OrderStatus.emInspecao);

    await expectLater(
      b.saveCheck(id, group: 'Freios', component: 'Pastilhas',
          classification: Classification.critico, note: '  ', photoIds: const []),
      throwsKind(ApiErrorKind.validation),
    );
    await expectLater(
      b.saveCheck(id, group: 'Freios', component: 'Inexistente',
          classification: Classification.ok, note: '', photoIds: const []),
      throwsKind(ApiErrorKind.validation),
    );
    await expectLater(b.finalizeInspection(id), throwsKind(ApiErrorKind.conflict));
    expect((await b.getOrder(id)).status, OrderStatus.emInspecao);

    await fillAll(b, id);
    final done = await b.finalizeInspection(id);
    expect(done.finalized, isTrue);
    expect((await b.getOrder(id)).status, OrderStatus.aguardandoComercial);
    await expectLater(
      b.saveCheck(id, group: 'Freios', component: 'Pastilhas',
          classification: Classification.ok, note: '', photoIds: const []),
      throwsKind(ApiErrorKind.conflict),
    );
  });

  test('comercial: aprovar tudo leva a EM_EXECUCAO; decisão é definitiva; encerra', () async {
    final id = await seedAssignedOrder(b);
    await b.login('mecanico1', 'mecanico123');
    await b.openInspection(id);
    await fillAll(b, id);
    await b.finalizeInspection(id);
    await b.logout();

    await b.login('atendente', 'atendente123');
    final r1 = await b.addRecommendation(id, description: 'Trocar pastilhas', priceCents: 25000);
    final r2 = await b.addRecommendation(id, description: 'Alinhamento', priceCents: 9000);
    await b.decide(r1.id, approve: true);
    await expectLater(b.closeOrder(id), throwsKind(ApiErrorKind.conflict)); // r2 pendente
    await b.decide(r2.id, approve: false);
    expect((await b.getOrder(id)).status, OrderStatus.emExecucao);
    await expectLater(b.decide(r2.id, approve: true), throwsKind(ApiErrorKind.conflict));
    expect((await b.closeOrder(id)).status, OrderStatus.encerrada);
  });

  test('só recomenda serviços depois da inspeção finalizada', () async {
    final id = await seedAssignedOrder(b);
    await b.login('atendente', 'atendente123');
    await expectLater(
      b.addRecommendation(id, description: 'Trocar pastilhas', priceCents: 100),
      throwsKind(ApiErrorKind.conflict),
    );
  });
}
