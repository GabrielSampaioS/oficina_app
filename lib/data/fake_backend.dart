import '../domain/models.dart';
import '../domain/validators.dart';
import 'api.dart';

class _Account {
  const _Account(this.user, this.password);

  final User user;
  final String password;
}

/// Backend em memória que implementa os mesmos contratos da API real e espelha
/// as regras do servidor (permissões, transições, validações). Serve a testes de
/// widget, a `integration_test` e ao modo demonstração. **Não é** o backend:
/// só os testes contra a API real provam o contrato (E2E de API, fatia futura).
class FakeBackend
    implements AuthApi, OrdersApi, InspectionApi, CommercialApi {
  FakeBackend._(this._accounts, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  /// Contas de demonstração (somente para uso local/testes).
  factory FakeBackend.seeded({DateTime Function()? now}) => FakeBackend._({
        'atendente': const _Account(
          User(id: 'u-atendente', name: 'Ana Atendente', role: Role.atendente),
          'atendente123',
        ),
        'mecanico1': const _Account(
          User(id: 'u-mec1', name: 'Carlos Mecânico', role: Role.mecanico),
          'mecanico123',
        ),
        'mecanico2': const _Account(
          User(id: 'u-mec2XC  SCVS', name: 'Paulo Mecânico', role: Role.mecanico),
          'mecanico123',
        ),
        '1': const _Account(
          User(id: 'u-mec3', name: 'root', role: Role.admin),
          'root123',
        ),
      }, now: now);

  final Map<String, _Account> _accounts;
  final DateTime Function() _now;

  /// Simula perda de conexão: toda chamada falha com [ApiErrorKind.network].
  bool offline = false;

  User? _current;
  int _seq = 0;
  final Map<String, ServiceOrder> _orders = {};
  final Map<String, Inspection> _inspections = {}; // por orderId
  final Map<String, Recommendation> _recs = {};

  // ---------------------------------------------------------------- helpers

  void _guard() {
    if (offline) {
      throw const ApiException(
        ApiErrorKind.network,
        'Sem conexão com o servidor. Verifique a internet e tente novamente.',
      );
    }
  }

  User _user() {
    final u = _current;
    if (u == null) {
      throw const ApiException(ApiErrorKind.unauthorized, 'Sessão expirada. Entre novamente.');
    }
    return u;
  }

  User _requireRole(Set<Role> allowed) {
    final u = _user();
    if (!allowed.contains(u.role)) {
      throw const ApiException(ApiErrorKind.forbidden, 'Seu perfil não tem permissão para esta ação.');
    }
    return u;
  }

  ServiceOrder _order(String id) {
    final o = _orders[id];
    if (o == null) {
      throw const ApiException(ApiErrorKind.notFound, 'Ordem de serviço não encontrada.');
    }
    return o;
  }

  /// Mecânico só acessa OS atribuídas a ele.
  ServiceOrder _orderFor(User u, String id) {
    final o = _order(id);
    if (u.role == Role.mecanico && o.mechanicId != u.id) {
      throw const ApiException(ApiErrorKind.forbidden, 'Acesso negado a esta ordem de serviço.');
    }
    return o;
  }

  ApiException _conflict(String m) => ApiException(ApiErrorKind.conflict, m);
  ApiException _invalid(String m) => ApiException(ApiErrorKind.validation, m);

  // ------------------------------------------------------------------- auth

  @override
  Future<User> login(String username, String password) async {
    _guard();
    final acc = _accounts[username.trim()];
    if (acc == null || acc.password != password) {
      throw const ApiException(ApiErrorKind.unauthorized, 'Usuário ou senha inválidos.');
    }
    _current = acc.user;
    return acc.user;
  }

  @override
  Future<void> logout() async {
    _current = null;
  }

  // ----------------------------------------------------------------- orders

  @override
  Future<List<ServiceOrder>> listOrders({OrderStatus? status}) async {
    _guard();
    final u = _user();
    final all = _orders.values.where((o) => u.role != Role.mecanico || o.mechanicId == u.id);
    final filtered = status == null ? all : all.where((o) => o.status == status);
    return filtered.toList().reversed.toList();
  }

  @override
  Future<ServiceOrder> getOrder(String orderId) async {
    _guard();
    return _orderFor(_user(), orderId);
  }

  @override
  Future<List<User>> listMechanics() async {
    _guard();
    _requireRole({Role.atendente, Role.admin});
    return _accounts.values
        .map((a) => a.user)
        .where((u) => u.role == Role.mecanico)
        .toList();
  }

  @override
  Future<ServiceOrder> openOrder({
    required String customerName,
    required String customerPhone,
    required String plate,
    required String chassi,
    required String model,
    required int year,
    required String complaint,
  }) async {
    _guard();
    _requireRole({Role.atendente, Role.admin});
    final error = validateName(customerName) ??
        validatePhone(customerPhone) ??
        validatePlate(plate) ??
        validateChassi(chassi) ??
        validateModel(model) ??
        validateYear('$year', currentYear: _now().year) ??
        validateComplaint(complaint);
    if (error != null) throw _invalid(error);
    final order = ServiceOrder(
      id: 'os-${++_seq}',
      customerName: customerName.trim(),
      customerPhone: customerPhone.replaceAll(RegExp(r'\D'), ''),
      vehiclePlate: normalizePlate(plate),
      vehicleChassi: normalizeChassis(chassi),
      vehicleModel: model.trim(),
      vehicleYear: year,
      complaint: complaint.trim(),
      status: OrderStatus.aberta,
    );
    _orders[order.id] = order;
    return order;
  }

  @override
  Future<ServiceOrder> assignMechanic(String orderId, String mechanicId) async {
    _guard();
    _requireRole({Role.atendente, Role.admin});
    final order = _order(orderId);
    final mech = _accounts.values
        .map((a) => a.user)
        .where((u) => u.id == mechanicId && u.role == Role.mecanico)
        .firstOrNull;
    if (mech == null) throw _invalid('O usuário informado não é um mecânico.');
    if (order.status != OrderStatus.aberta && order.status != OrderStatus.atribuida) {
      throw _conflict('Não é possível atribuir mecânico com a OS em ${order.status.label}.');
    }
    final updated = order.copyWith(
      status: OrderStatus.atribuida,
      mechanicId: mech.id,
      mechanicName: mech.name,
    );
    _orders[orderId] = updated;
    return updated;
  }

  @override
  Future<ServiceOrder> closeOrder(String orderId) async {
    _guard();
    _requireRole({Role.atendente, Role.admin});
    final order = _order(orderId);
    if (_recs.values.any((r) => r.orderId == orderId && r.status == RecommendationStatus.pendente)) {
      throw _conflict('Existem serviços pendentes de aprovação ou recusa.');
    }
    if (order.status != OrderStatus.aguardandoComercial && order.status != OrderStatus.emExecucao) {
      throw _conflict('OS em ${order.status.label} não pode ser encerrada.');
    }
    final updated = order.copyWith(status: OrderStatus.encerrada);
    _orders[orderId] = updated;
    return updated;
  }

  // ------------------------------------------------------------- inspection

  @override
  Future<Inspection> openInspection(String orderId) async {
    _guard();
    final u = _requireRole({Role.mecanico});
    final order = _orderFor(u, orderId);
    final existing = _inspections[orderId];
    if (existing != null) return existing;
    if (order.status != OrderStatus.atribuida) {
      throw _conflict('A inspeção não pode ser iniciada com a OS em ${order.status.label}.');
    }
    final inspection = Inspection(
      id: 'insp-${++_seq}',
      orderId: orderId,
      groups: defaultChecklist,
      checks: const {},
    );
    _inspections[orderId] = inspection;
    _orders[orderId] = order.copyWith(status: OrderStatus.emInspecao);
    return inspection;
  }

  @override
  Future<Inspection?> getInspection(String orderId) async {
    _guard();
    _orderFor(_user(), orderId);
    return _inspections[orderId];
  }

  @override
  Future<Inspection> saveCheck(
    String orderId, {
    required String group,
    required String component,
    required Classification classification,
    required String note,
    required List<String> photoIds,
  }) async {
    _guard();
    final u = _requireRole({Role.mecanico});
    _orderFor(u, orderId);
    final inspection = _inspections[orderId];
    if (inspection == null) {
      throw const ApiException(ApiErrorKind.notFound, 'Inspeção não iniciada para esta OS.');
    }
    if (inspection.finalized) {
      throw _conflict('Inspeção finalizada não pode ser alterada.');
    }
    final known = defaultChecklist.any((g) => g.name == group && g.components.contains(component));
    if (!known) throw _invalid('Componente inexistente no checklist: $group / $component.');
    final trimmed = note.trim();
    if (classification.requiresNote && trimmed.isEmpty) {
      throw _invalid('Componentes em Atenção ou Crítico exigem uma observação.');
    }
    final checks = Map<String, ComponentCheck>.of(inspection.checks)
      ..[checkKey(group, component)] = ComponentCheck(
        group: group,
        component: component,
        classification: classification,
        note: trimmed,
        photoIds: List<String>.of(photoIds),
      );
    final updated = inspection.copyWith(checks: checks);
    _inspections[orderId] = updated;
    return updated;
  }

  @override
  Future<Inspection> finalizeInspection(String orderId) async {
    _guard();
    final u = _requireRole({Role.mecanico});
    final order = _orderFor(u, orderId);
    final inspection = _inspections[orderId];
    if (inspection == null) {
      throw const ApiException(ApiErrorKind.notFound, 'Inspeção não iniciada para esta OS.');
    }
    if (inspection.finalized || order.status != OrderStatus.emInspecao) {
      throw _conflict('A inspeção já foi finalizada.');
    }
    if (inspection.missingCount > 0) {
      throw _conflict('Inspeção incompleta. Faltam ${inspection.missingCount} componente(s).');
    }
    final done = inspection.copyWith(finalized: true, summary: _summary(inspection));
    _inspections[orderId] = done;
    _orders[orderId] = order.copyWith(status: OrderStatus.aguardandoComercial);
    return done;
  }

  String _summary(Inspection i) {
    int count(Classification c) => i.checks.values.where((x) => x.classification == c).length;
    final lines = <String>[
      'Resumo técnico: ${i.checks.length} componentes avaliados — '
          '${count(Classification.ok)} OK, ${count(Classification.atencao)} em atenção, '
          '${count(Classification.critico)} críticos.',
    ];
    for (final level in [Classification.critico, Classification.atencao]) {
      for (final c in i.checks.values.where((x) => x.classification == level)) {
        lines.add('[${level.label}] ${c.group} / ${c.component}: ${c.note}');
      }
    }
    return lines.join('\n');
  }

  // ------------------------------------------------------------- commercial

  @override
  Future<List<Recommendation>> listRecommendations(String orderId) async {
    _guard();
    _orderFor(_user(), orderId);
    return _recs.values.where((r) => r.orderId == orderId).toList();
  }

  @override
  Future<Recommendation> addRecommendation(
    String orderId, {
    required String description,
    required int priceCents,
  }) async {
    _guard();
    _requireRole({Role.atendente, Role.admin});
    final order = _order(orderId);
    if (order.status != OrderStatus.aguardandoComercial) {
      throw _conflict('Serviços só podem ser recomendados após a inspeção finalizada.');
    }
    final error = validateDescription(description);
    if (error != null) throw _invalid(error);
    if (priceCents < 0) throw _invalid('Valor não pode ser negativo.');
    final rec = Recommendation(
      id: 'rec-${++_seq}',
      orderId: orderId,
      description: description.trim(),
      priceCents: priceCents,
      status: RecommendationStatus.pendente,
    );
    _recs[rec.id] = rec;
    return rec;
  }

  @override
  Future<Recommendation> decide(String recommendationId, {required bool approve}) async {
    _guard();
    _requireRole({Role.atendente, Role.admin});
    final rec = _recs[recommendationId];
    if (rec == null) {
      throw const ApiException(ApiErrorKind.notFound, 'Serviço recomendado não encontrado.');
    }
    final order = _order(rec.orderId);
    if (order.status != OrderStatus.aguardandoComercial) {
      throw _conflict('OS em ${order.status.label} não aceita decisão sobre serviços.');
    }
    if (rec.status != RecommendationStatus.pendente) {
      throw _conflict('Serviço já foi ${rec.status.label.toLowerCase()}; a decisão não pode ser alterada.');
    }
    final updated = rec.copyWith(
      status: approve ? RecommendationStatus.aprovada : RecommendationStatus.recusada,
    );
    _recs[rec.id] = updated;
    final all = _recs.values.where((r) => r.orderId == order.id);
    final pending = all.any((r) => r.status == RecommendationStatus.pendente);
    final anyApproved = all.any((r) => r.status == RecommendationStatus.aprovada);
    if (!pending && anyApproved) {
      _orders[order.id] = order.copyWith(status: OrderStatus.emExecucao);
    }
    return updated;
  }
}
