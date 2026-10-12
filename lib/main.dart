import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/fake_backend.dart';
import 'data/photo_picker.dart';
import 'state/providers.dart';


/// Ponto de entrada em MODO DEMONSTRAÇÃO: usa o backend em memória, sem
/// servidor. Quando a API HTTP existir, as implementações HTTP dos contratos de
/// `data/api.dart` substituem o [FakeBackend] aqui, sem tocar na interface.
///
/// Contas: atendente/atendente123, mecanico1/mecanico123, mecanico2/mecanico123.
void main() {
  final backend = FakeBackend.seeded();
  runApp(
    ProviderScope(
      overrides: [
        authApiProvider.overrideWithValue(backend),
        ordersApiProvider.overrideWithValue(backend),
        inspectionApiProvider.overrideWithValue(backend),
        commercialApiProvider.overrideWithValue(backend),
        photoPickerProvider.overrideWithValue(ImagePickerPhotoPicker()),
      ],
      child: const OficinaApp(),
    ),
  );
}
