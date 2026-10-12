import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oficina_app/data/fake_backend.dart';
import 'package:oficina_app/domain/models.dart';

import '../support/pump_app.dart';

/// Deixa uma OS com inspeção finalizada (um componente crítico com foto),
/// pronta para o atendente.
Future<String> orderAwaitingCommercial(FakeBackend backend) async {
  final id = await seedAssignedOrder(backend);
  await backend.login('mecanico1', 'mecanico123');
  await backend.openInspection(id);
  for (final g in defaultChecklist) {
    for (final c in g.components) {
      final critical = g.name == 'Freios' && c == 'Pastilhas';
      await backend.saveCheck(
        id,
        group: g.name,
        component: c,
        classification: critical ? Classification.critico : Classification.ok,
        note: critical ? 'Sem material de atrito' : '',
        photoIds: critical ? const ['foto-1.jpg'] : const [],
      );
    }
  }
  await backend.finalizeInspection(id);
  await backend.logout();
  return id;
}

void main() {
  testWidgets('atendente vê diagnóstico, críticos e fotos sem poder alterá-los', (tester) async {
    final backend = FakeBackend.seeded();
    final id = await orderAwaitingCommercial(backend);
    await pumpApp(tester, backend);
    await loginAs(tester, 'atendente', 'atendente123');
    await tapKey(tester, 'order-$id');

    expect(find.byKey(const Key('inspection-summary')), findsOneWidget);
    expect(find.textContaining('1 críticos'), findsOneWidget);
    expect(find.text('Freios / Pastilhas'), findsOneWidget);
    expect(find.text('Sem material de atrito'), findsOneWidget);
    expect(find.text('1 foto(s)'), findsOneWidget);
    // Nenhum controle de edição da inspeção na visão comercial.
    expect(find.byKey(const Key('save-progress')), findsNothing);
    expect(find.byKey(const Key('finalize-inspection')), findsNothing);
  });

  testWidgets('registra serviços, aprova e recusa, e a OS segue para execução', (tester) async {
    final backend = FakeBackend.seeded();
    final id = await orderAwaitingCommercial(backend);
    await pumpApp(tester, backend);
    await loginAs(tester, 'atendente', 'atendente123');
    await tapKey(tester, 'order-$id');

    await tapKey(tester, 'add-recommendation');
    await tester.enterText(find.byKey(const Key('rec-desc')), 'Trocar pastilhas');
    await tester.enterText(find.byKey(const Key('rec-price')), '250,00');
    await tapKey(tester, 'rec-save');
    await tapKey(tester, 'add-recommendation');
    await tester.enterText(find.byKey(const Key('rec-desc')), 'Alinhamento');
    await tester.enterText(find.byKey(const Key('rec-price')), '90,50');
    await tapKey(tester, 'rec-save');

    expect(find.text('R\$ 250,00 · Pendente'), findsOneWidget);
    expect(find.text('R\$ 90,50 · Pendente'), findsOneWidget);

    final recs = await backend.listRecommendations(id);
    await tapKey(tester, 'approve-${recs[0].id}');
    await tapKey(tester, 'decline-${recs[1].id}');

    expect(find.text('R\$ 250,00 · Aprovada'), findsOneWidget);
    expect(find.text('R\$ 90,50 · Recusada'), findsOneWidget);
    expect(find.text('Em execução'), findsWidgets);
  });

  testWidgets('valor em formato ambíguo é rejeitado no diálogo', (tester) async {
    final backend = FakeBackend.seeded();
    final id = await orderAwaitingCommercial(backend);
    await pumpApp(tester, backend);
    await loginAs(tester, 'atendente', 'atendente123');
    await tapKey(tester, 'order-$id');

    await tapKey(tester, 'add-recommendation');
    await tester.enterText(find.byKey(const Key('rec-desc')), 'Trocar pastilhas');
    await tester.enterText(find.byKey(const Key('rec-price')), '1.250');
    await tapKey(tester, 'rec-save');
    expect(find.text('Valor no formato 250,00 (sem ponto de milhar).'), findsOneWidget);
    expect(await backend.listRecommendations(id), isEmpty);
  });

  testWidgets('não encerra com serviço pendente; encerra depois de decidir', (tester) async {
    final backend = FakeBackend.seeded();
    final id = await orderAwaitingCommercial(backend);
    await pumpApp(tester, backend);
    await loginAs(tester, 'atendente', 'atendente123');
    await tapKey(tester, 'order-$id');

    await tapKey(tester, 'add-recommendation');
    await tester.enterText(find.byKey(const Key('rec-desc')), 'Trocar pastilhas');
    await tester.enterText(find.byKey(const Key('rec-price')), '250');
    await tapKey(tester, 'rec-save');

    await tapKey(tester, 'close-order');
    expect(find.text('Existem serviços pendentes de aprovação ou recusa.'), findsOneWidget);

    final rec = (await backend.listRecommendations(id)).single;
    await tapKey(tester, 'decline-${rec.id}');
    await tapKey(tester, 'close-order');
    expect(find.text('Encerrada'), findsWidgets);
    expect(find.byKey(const Key('close-order')), findsNothing);
  });

  testWidgets('atendente atribui mecânico a uma OS aberta', (tester) async {
    final backend = FakeBackend.seeded();
    await backend.login('atendente', 'atendente123');
    final order = await backend.openOrder(
      customerName: 'Joana', customerPhone: '19988887777', plate: 'CCC3C33',
      model: 'Uno', year: 2010, complaint: 'Não liga',
    );
    await backend.logout();
    await pumpApp(tester, backend);
    await loginAs(tester, 'atendente', 'atendente123');
    await tapKey(tester, 'order-${order.id}');

    expect(find.text('Mecânico: não atribuído'), findsOneWidget);
    await tapKey(tester, 'mechanic-dropdown');
    await tester.tap(find.text('Carlos Mecânico').last);
    await tester.pumpAndSettle();
    await tapKey(tester, 'assign-button');

    expect(find.text('Mecânico: Carlos Mecânico'), findsOneWidget);
    expect(find.text('Atribuída'), findsWidgets);
  });
}
