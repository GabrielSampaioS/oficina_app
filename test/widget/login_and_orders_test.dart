import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oficina_app/data/fake_backend.dart';

import '../support/pump_app.dart';

void main() {
  group('Login', () {
    testWidgets('valida campos vazios sem chamar o servidor', (tester) async {
      await pumpApp(tester, FakeBackend.seeded());
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Informe o usuário.'), findsOneWidget);
      expect(find.text('Informe a senha.'), findsOneWidget);
    });

    testWidgets('mostra erro com credenciais inválidas e permanece no login', (tester) async {
      await pumpApp(tester, FakeBackend.seeded());
      await loginAs(tester, 'atendente', 'senha-errada');
      expect(find.byKey(const Key('login-error')), findsOneWidget);
      expect(find.text('Usuário ou senha inválidos.'), findsOneWidget);
      expect(find.byKey(const Key('login-submit')), findsOneWidget);
    });

    testWidgets('mostra falha de conexão no login', (tester) async {
      final backend = FakeBackend.seeded()..offline = true;
      await pumpApp(tester, backend);
      await loginAs(tester, 'atendente', 'atendente123');
      expect(find.textContaining('Sem conexão'), findsOneWidget);
    });

    testWidgets('atendente entra e vê a lista de OS; sair volta ao login', (tester) async {
      await pumpApp(tester, FakeBackend.seeded());
      await loginAs(tester, 'atendente', 'atendente123');
      expect(find.text('Ordens de serviço'), findsOneWidget);
      expect(find.text('Nenhuma ordem de serviço.'), findsOneWidget);
      await tapKey(tester, 'logout-button');
      expect(find.byKey(const Key('login-submit')), findsOneWidget);
    });
  });

  group('Lista de OS', () {
    testWidgets('mecânico vê somente as OS atribuídas a ele', (tester) async {
      final backend = FakeBackend.seeded();
      await seedAssignedOrder(backend, mechanicId: 'u-mec1', plate: 'AAA1A11');
      await seedAssignedOrder(backend, mechanicId: 'u-mec2', plate: 'BBB2B22');
      await pumpApp(tester, backend);
      await loginAs(tester, 'mecanico1', 'mecanico123');
      expect(find.text('Minhas OS'), findsOneWidget);
      expect(find.textContaining('AAA1A11'), findsOneWidget);
      expect(find.textContaining('BBB2B22'), findsNothing);
      expect(find.byKey(const Key('new-order-fab')), findsNothing);
    });

    testWidgets('atendente vê todas e pesquisa por placa', (tester) async {
      final backend = FakeBackend.seeded();
      await seedAssignedOrder(backend, mechanicId: 'u-mec1', plate: 'AAA1A11');
      await seedAssignedOrder(backend, mechanicId: 'u-mec2', plate: 'BBB2B22');
      await pumpApp(tester, backend);
      await loginAs(tester, 'atendente', 'atendente123');
      expect(find.textContaining('AAA1A11'), findsOneWidget);
      expect(find.textContaining('BBB2B22'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('search-field')), 'bbb');
      await tester.pumpAndSettle();
      expect(find.textContaining('AAA1A11'), findsNothing);
      expect(find.textContaining('BBB2B22'), findsOneWidget);
    });

    testWidgets('falha de conexão mostra erro e "Tentar novamente" recupera', (tester) async {
      final backend = FakeBackend.seeded();
      final id = await seedAssignedOrder(backend, plate: 'AAA1A11');
      await pumpApp(tester, backend);
      await loginAs(tester, 'atendente', 'atendente123');

      backend.offline = true;
      await tapKey(tester, 'order-$id');
      expect(find.textContaining('Sem conexão'), findsOneWidget);

      backend.offline = false;
      await tapKey(tester, 'retry-button');
      expect(find.textContaining('AAA1A11'), findsOneWidget);
      expect(find.byKey(const Key('order-status')), findsOneWidget);
    });
  });

  group('Nova OS', () {
    testWidgets('formulário inválido mostra erros e não cria OS', (tester) async {
      final backend = FakeBackend.seeded();
      await pumpApp(tester, backend);
      await loginAs(tester, 'atendente', 'atendente123');
      await tapKey(tester, 'new-order-fab');
      await tester.enterText(find.byKey(const Key('field-plate')), 'XX');
      await tapKey(tester, 'submit-order');
      expect(find.text('Placa inválida (ex.: ABC1D23 ou ABC-1234).'), findsOneWidget);
      expect(find.text('Informe o nome (mínimo 2 caracteres).'), findsOneWidget);
      expect(await backend.listOrders(), isEmpty);
    });

    testWidgets('formulário válido abre a OS e ela aparece na lista', (tester) async {
      final backend = FakeBackend.seeded();
      await pumpApp(tester, backend);
      await loginAs(tester, 'atendente', 'atendente123');
      await tapKey(tester, 'new-order-fab');
      await tester.enterText(find.byKey(const Key('field-name')), 'Maria Souza');
      await tester.enterText(find.byKey(const Key('field-phone')), '(19) 99999-1234');
      await tester.enterText(find.byKey(const Key('field-plate')), 'abc-1234');
      await tester.enterText(find.byKey(const Key('field-model')), 'Palio');
      await tester.enterText(find.byKey(const Key('field-year')), '2015');
      await tester.enterText(find.byKey(const Key('field-complaint')), 'Barulho ao frear');
      await tapKey(tester, 'submit-order');

      expect(find.text('Ordens de serviço'), findsOneWidget);
      expect(find.textContaining('ABC1234'), findsOneWidget);
      expect(find.text('Aberta'), findsWidgets);
    });
  });
}
