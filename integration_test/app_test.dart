import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oficina_app/data/fake_backend.dart';
import 'package:oficina_app/domain/models.dart';

import '../test/support/pump_app.dart';

/// Percorre os fluxos 1 a 3 pela interface, trocando de perfil como na oficina.
/// Roda o app de verdade (`flutter test integration_test`), mas contra o
/// FakeBackend em memória: prova a interface, NÃO o contrato com a API real.
/// O E2E contra o backend de verdade entra com a API HTTP (fatia futura).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('entrada → inspeção → retorno ao comercial → encerramento', (tester) async {
    final backend = FakeBackend.seeded();
    await pumpApp(tester, backend);

    // Fluxo 1: atendente abre a OS e atribui o mecânico.
    await loginAs(tester, 'atendente', 'atendente123');
    await tapKey(tester, 'new-order-fab');
    await tester.enterText(find.byKey(const Key('field-name')), 'Maria Souza');
    await tester.enterText(find.byKey(const Key('field-phone')), '(19) 99999-1234');
    await tester.enterText(find.byKey(const Key('field-plate')), 'ABC1D23');
    await tester.enterText(find.byKey(const Key('field-model')), 'Gol 1.0');
    await tester.enterText(find.byKey(const Key('field-year')), '2018');
    await tester.enterText(find.byKey(const Key('field-complaint')), 'Barulho ao frear');
    await tapKey(tester, 'submit-order');
    expect(find.textContaining('ABC1D23'), findsOneWidget);

    await tapKey(tester, 'order-os-1');
    await tapKey(tester, 'mechanic-dropdown');
    await tester.tap(find.text('Carlos Mecânico').last);
    await tester.pumpAndSettle();
    await tapKey(tester, 'assign-button');
    expect(find.text('Mecânico: Carlos Mecânico'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapKey(tester, 'logout-button');

    // Fluxo 2: mecânico inspeciona, salva, e finaliza.
    await loginAs(tester, 'mecanico1', 'mecanico123');
    expect(find.textContaining('ABC1D23'), findsOneWidget);
    await tapKey(tester, 'order-os-1');
    await markAllOk(tester, skip: {'Freios/Pastilhas'});
    await tapKey(tester, 'chip-critico-Freios-Pastilhas');
    await tester.enterText(find.byKey(const Key('note-Freios-Pastilhas')), 'Sem material de atrito');
    await tester.pumpAndSettle();
    await tapKey(tester, 'photo-Freios-Pastilhas');
    await tapKey(tester, 'save-progress');
    await tapKey(tester, 'finalize-inspection');
    await tapKey(tester, 'confirm-finalize');
    expect(find.text('Aguardando comercial'), findsWidgets);
    await tapKey(tester, 'logout-button');

    // Fluxo 3: atendente vê o diagnóstico, registra e decide serviços, encerra.
    await loginAs(tester, 'atendente', 'atendente123');
    await tapKey(tester, 'order-os-1');
    expect(find.text('Freios / Pastilhas'), findsOneWidget);
    expect(find.text('1 foto(s)'), findsOneWidget);
    await tapKey(tester, 'add-recommendation');
    await tester.enterText(find.byKey(const Key('rec-desc')), 'Trocar pastilhas');
    await tester.enterText(find.byKey(const Key('rec-price')), '250,00');
    await tapKey(tester, 'rec-save');
    final rec = (await backend.listRecommendations('os-1')).single;
    await tapKey(tester, 'approve-${rec.id}');
    expect(find.text('Em execução'), findsWidgets);
    await tapKey(tester, 'close-order');
    expect(find.text('Encerrada'), findsWidgets);

    // O diagnóstico técnico original foi preservado.
    final inspection = (await backend.getInspection('os-1'))!;
    expect(inspection.finalized, isTrue);
    expect(inspection.checks[checkKey('Freios', 'Pastilhas')]!.classification,
        Classification.critico);
  });
}
