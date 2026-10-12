import '../domain/models.dart';

enum ApiErrorKind { network, unauthorized, forbidden, validation, notFound, conflict }

/// Erro de API já traduzido para algo que a interface pode mostrar.
class ApiException implements Exception {
  const ApiException(this.kind, this.message);

  final ApiErrorKind kind;
  final String message;

  bool get isNetwork => kind == ApiErrorKind.network;

  @override
  String toString() => 'ApiException($kind): $message';
}

String messageOf(Object error) =>
    error is ApiException ? error.message : 'Erro inesperado. Tente novamente.';

// Contratos pequenos e específicos (ISP): a UI depende deles, não de HTTP.

abstract interface class AuthApi {
  Future<User> login(String username, String password);
  Future<void> logout();
}

abstract interface class OrdersApi {
  Future<List<ServiceOrder>> listOrders({OrderStatus? status});
  Future<ServiceOrder> getOrder(String orderId);
  Future<List<User>> listMechanics();
  Future<ServiceOrder> openOrder({
    required String customerName,
    required String customerPhone,
    required String plate,
    required String chassi,
    required String model,
    required int year,
    required String complaint,
  });
  Future<ServiceOrder> assignMechanic(String orderId, String mechanicId);
  Future<ServiceOrder> closeOrder(String orderId);
}

abstract interface class InspectionApi {
  /// Inicia a inspeção ou devolve a existente (retomada). Idempotente.
  Future<Inspection> openInspection(String orderId);

  /// Consulta somente leitura; `null` quando a inspeção não foi iniciada.
  Future<Inspection?> getInspection(String orderId);

  Future<Inspection> saveCheck(
    String orderId, {
    required String group,
    required String component,
    required Classification classification,
    required String note,
    required List<String> photoIds,
  });

  Future<Inspection> finalizeInspection(String orderId);
}

abstract interface class CommercialApi {
  Future<List<Recommendation>> listRecommendations(String orderId);
  Future<Recommendation> addRecommendation(
    String orderId, {
    required String description,
    required int priceCents,
  });
  Future<Recommendation> decide(String recommendationId, {required bool approve});
}
