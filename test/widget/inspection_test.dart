import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oficina_app/data/fake_backend.dart';
import 'package:oficina_app/data/photo_picker.dart';
import 'package:oficina_app/domain/models.dart';

import '../support/pump_app.dart';

Future<(FakeBackend, String)> openInspectionAsMechanic(
  WidgetTester tester, {
  PhotoPicker? picker,
}) async {
  final backend = FakeBackend.seeded();
  final orderId = await seedAssignedOrder(backend);
  await pumpApp(tester, backend, picker: picker);
  await loginAs(tester, 'mecanico1', 'mecanico123');
  await tapKey(tester, 'order-$orderId');
  return (backend, orderId);
}

void main() {
  testWidgets('abrir a OS inicia a inspeção e mostra o progresso zerado', (tester) async {
    final (backend, orderId) = await openInspectionAsMechanic(tester);
    expect(find.textContaining('Inspeção ·'), findsOneWidget);
    expect(find.text('0/10 componentes avaliados'), findsOneWidget);
    for (final g in defaultChecklist) {
      expect(find.text(g.name), findsOneWidget);
    }
    await backend.login('mecanico1', 'mecanico123');
    expect((await backend.getOrder(orderId)).status, OrderStatus.emInspecao);
  });

  testWidgets('selecionar classificação atualiza o progresso', (tester) async {
    await openInspectionAsMechanic(tester);
    await tapKey(tester, 'chip-ok-Motor-Velas');
    expect(find.text('1/10 componentes avaliados'), findsOneWidget);
  });

  testWidgets('Atenção/Crítico exige observação: erro aparece ao salvar', (tester) async {
    await openInspectionAsMechanic(tester);
    await tapKey(tester, 'chip-critico-Freios-Pastilhas');
    expect(find.byKey(const Key('note-Freios-Pastilhas')), findsOneWidget);
    expect(find.text('Observação obrigatória'), findsNothing);
    await tapKey(tester, 'save-progress');
    expect(find.text('Observação obrigatória'), findsOneWidget);
    // Com a observação preenchida, o componente passa a contar como avaliado.
    await tester.enterText(find.byKey(const Key('note-Freios-Pastilhas')), 'Sem material');
    await tester.pumpAndSettle();
    expect(find.text('1/10 componentes avaliados'), findsOneWidget);
    expect(find.text('Observação obrigatória'), findsNothing);
  });

  testWidgets('foto exige classificação e usa o seletor simulado', (tester) async {
    await openInspectionAsMechanic(tester);
    await tapKey(tester, 'photo-Freios-Pastilhas');
    expect(find.text('Classifique o componente antes de anexar uma foto.'), findsOneWidget);

    await tapKey(tester, 'chip-atencao-Freios-Pastilhas');
    await tapKey(tester, 'photo-Freios-Pastilhas');
    expect(find.byKey(const Key('photo-chip-Freios-Pastilhas-foto-1.jpg')), findsOneWidget);
  });

  testWidgets('finalizar incompleta é bloqueado e a OS continua em inspeção', (tester) async {
    final (backend, orderId) = await openInspectionAsMechanic(tester);
    await tapKey(tester, 'chip-ok-Motor-Velas');
    await tapKey(tester, 'finalize-inspection');
    expect(find.textContaining('Faltam 9 componente(s)'), findsOneWidget);
    expect(find.byKey(const Key('confirm-finalize')), findsNothing);
    await backend.login('mecanico1', 'mecanico123');
    expect((await backend.getOrder(orderId)).status, OrderStatus.emInspecao);
  });

  testWidgets('salvar progresso persiste e a inspeção é retomada ao reabrir', (tester) async {
    final (backend, orderId) = await openInspectionAsMechanic(tester);
    await tapKey(tester, 'chip-ok-Motor-Velas');
    await tapKey(tester, 'chip-critico-Freios-Pastilhas');
    await tester.enterText(find.byKey(const Key('note-Freios-Pastilhas')), 'Sem material');
    await tester.pumpAndSettle();
    await tapKey(tester, 'photo-Freios-Pastilhas');
    await tapKey(tester, 'save-progress');

    final saved = (await backend.getInspection(orderId))!;
    expect(saved.checks.length, 2);
    expect(saved.checks[checkKey('Freios', 'Pastilhas')]!.photoIds, ['foto-1.jpg']);

    // Volta para a lista e reabre a mesma OS.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapKey(tester, 'order-$orderId');
    expect(find.text('2/10 componentes avaliados'), findsOneWidget);
    expect(find.byKey(const Key('photo-chip-Freios-Pastilhas-foto-1.jpg')), findsOneWidget);
  });

  testWidgets('fluxo completo: preencher, confirmar e enviar ao comercial', (tester) async {
    final (backend, orderId) = await openInspectionAsMechanic(tester);
    await markAllOk(tester, skip: {'Freios/Pastilhas'});
    await tapKey(tester, 'chip-critico-Freios-Pastilhas');
    await tester.enterText(find.byKey(const Key('note-Freios-Pastilhas')), 'Sem material');
    await tester.pumpAndSettle();
    expect(find.text('10/10 componentes avaliados'), findsOneWidget);

    await tapKey(tester, 'finalize-inspection');
    expect(find.text('Finalizar inspeção?'), findsOneWidget);
    await tapKey(tester, 'confirm-finalize');

    // Voltou para a lista e a OS foi para o comercial.
    expect(find.text('Minhas OS'), findsOneWidget);
    expect(find.text('Aguardando comercial'), findsWidgets);
    await backend.login('mecanico1', 'mecanico123');
    final inspection = (await backend.getInspection(orderId))!;
    expect(inspection.finalized, isTrue);
    expect(inspection.summary, contains('1 críticos'));
  });

  testWidgets('cancelar a confirmação mantém a inspeção editável', (tester) async {
    final (backend, orderId) = await openInspectionAsMechanic(tester);
    await markAllOk(tester);
    await tapKey(tester, 'finalize-inspection');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('finalize-inspection')), findsOneWidget);
    await backend.login('mecanico1', 'mecanico123');
    expect((await backend.getInspection(orderId))!.finalized, isFalse);
  });

  testWidgets('falha de conexão ao abrir mostra erro e permite tentar de novo', (tester) async {
    final backend = FakeBackend.seeded();
    final orderId = await seedAssignedOrder(backend);
    await pumpApp(tester, backend);
    await loginAs(tester, 'mecanico1', 'mecanico123');
    backend.offline = true;
    await tapKey(tester, 'order-$orderId');
    expect(find.textContaining('Sem conexão'), findsOneWidget);

    backend.offline = false;
    await tapKey(tester, 'retry-button');
    expect(find.text('0/10 componentes avaliados'), findsOneWidget);
  });
}
