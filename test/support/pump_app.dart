import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oficina_app/app.dart';
import 'package:oficina_app/data/fake_backend.dart';
import 'package:oficina_app/data/photo_picker.dart';
import 'package:oficina_app/domain/models.dart';
import 'package:oficina_app/state/providers.dart';

/// Sobe o app com backend e câmera simulados (nada depende de rede, câmera
/// física ou credenciais reais). A viewport é alta para que formulários longos
/// fiquem todos construídos e visíveis.
Future<void> pumpApp(
  WidgetTester tester,
  FakeBackend backend, {
  PhotoPicker? picker,
}) async {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authApiProvider.overrideWithValue(backend),
        ordersApiProvider.overrideWithValue(backend),
        inspectionApiProvider.overrideWithValue(backend),
        commercialApiProvider.overrideWithValue(backend),
        photoPickerProvider.overrideWithValue(picker ?? FakePhotoPicker()),
      ],
      child: const OficinaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> loginAs(WidgetTester tester, String user, String password) async {
  await tester.enterText(find.byKey(const Key('login-user')), user);
  await tester.enterText(find.byKey(const Key('login-password')), password);
  await tester.tap(find.byKey(const Key('login-submit')));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Cria, direto no backend, uma OS atribuída ao mecânico informado.
/// Termina com o backend deslogado, para o teste fazer login pela interface.
Future<String> seedAssignedOrder(
  FakeBackend backend, {
  String mechanicId = 'u-mec1',
  String plate = 'ABC1D23',
  String customer = 'Maria Souza',
}) async {
  await backend.login('atendente', 'atendente123');
  final order = await backend.openOrder(
    customerName: customer,
    customerPhone: '(19) 99999-1234',
    plate: plate,
    model: 'Gol 1.0',
    year: 2018,
    complaint: 'Barulho ao frear',
  );
  await backend.assignMechanic(order.id, mechanicId);
  await backend.logout();
  return order.id;
}

/// Marca todos os componentes como OK pela interface, exceto os de [skip]
/// (formato "Grupo/Componente").
Future<void> markAllOk(WidgetTester tester, {Set<String> skip = const {}}) async {
  for (final g in defaultChecklist) {
    for (final c in g.components) {
      if (skip.contains('${g.name}/$c')) continue;
      await tapKey(tester, 'chip-ok-${g.name}-$c');
    }
  }
}
