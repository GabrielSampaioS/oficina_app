import 'package:flutter_riverpod/flutter_riverpod.dart';      

import '../data/api.dart';
import '../data/photo_picker.dart';
import '../domain/models.dart';

// Dependências externas: sobrescritas em `main.dart` e nos testes (DIP).
// Sem implementação padrão de propósito: esquecer o override falha alto.
final authApiProvider = Provider<AuthApi>(
  (ref) => throw UnimplementedError('authApiProvider não foi sobrescrito'),
);
final ordersApiProvider = Provider<OrdersApi>(
  (ref) => throw UnimplementedError('ordersApiProvider não foi sobrescrito'),
);
final inspectionApiProvider = Provider<InspectionApi>(
  (ref) => throw UnimplementedError('inspectionApiProvider não foi sobrescrito'),
);
final commercialApiProvider = Provider<CommercialApi>(
  (ref) => throw UnimplementedError('commercialApiProvider não foi sobrescrito'),
);
final photoPickerProvider = Provider<PhotoPicker>(
  (ref) => throw UnimplementedError('photoPickerProvider não foi sobrescrito'),
);


/// Usuário autenticado (`null` = deslogado).
class SessionNotifier extends Notifier<User?> {
  @override
  User? build() => null;

  Future<void> login(String username, String password) async {
    state = await ref.read(authApiProvider).login(username, password);
  }

  Future<void> logout() async {
    await ref.read(authApiProvider).logout();
    state = null;
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, User?>(SessionNotifier.new);

class StatusFilterNotifier extends Notifier<OrderStatus?> {
  @override
  OrderStatus? build() => null;

  void setStatus(OrderStatus? status) {
    state = status;
  }
}

final statusFilterProvider =
    NotifierProvider<StatusFilterNotifier, OrderStatus?>(
  StatusFilterNotifier.new,
);

final ordersProvider = FutureProvider.autoDispose<List<ServiceOrder>>((ref) {
  ref.watch(sessionProvider);
  final status = ref.watch(statusFilterProvider);
  return ref.watch(ordersApiProvider).listOrders(status: status);
});

final orderProvider =
    FutureProvider.autoDispose.family<ServiceOrder, String>((ref, id) {
  return ref.watch(ordersApiProvider).getOrder(id);
});

final mechanicsProvider = FutureProvider.autoDispose<List<User>>((ref) {
  return ref.watch(ordersApiProvider).listMechanics();
});

final inspectionViewProvider =
    FutureProvider.autoDispose.family<Inspection?, String>((ref, orderId) {
  return ref.watch(inspectionApiProvider).getInspection(orderId);
});

final recommendationsProvider =
    FutureProvider.autoDispose.family<List<Recommendation>, String>((ref, orderId) {
  return ref.watch(commercialApiProvider).listRecommendations(orderId);
});
