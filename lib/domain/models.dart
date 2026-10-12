/// Modelos de apresentação. As regras de negócio vivem no backend; o app apenas
/// reflete estados e permissões que o servidor informa (ver ADR-001).
enum Role { atendente, mecanico, admin }

enum OrderStatus {
  aberta,
  atribuida,
  emInspecao,
  aguardandoComercial,
  emExecucao,
  encerrada,
  cancelada,
}

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
        OrderStatus.aberta => 'Aberta',
        OrderStatus.atribuida => 'Atribuída',
        OrderStatus.emInspecao => 'Em inspeção',
        OrderStatus.aguardandoComercial => 'Aguardando comercial',
        OrderStatus.emExecucao => 'Em execução',
        OrderStatus.encerrada => 'Encerrada',
        OrderStatus.cancelada => 'Cancelada',
      };
}

enum Classification { ok, atencao, critico, naoAplicavel }

extension ClassificationX on Classification {
  String get label => switch (this) {
        Classification.ok => 'OK',
        Classification.atencao => 'Atenção',
        Classification.critico => 'Crítico',
        Classification.naoAplicavel => 'N/A',
      };

  /// Atenção e Crítico exigem observação do mecânico.
  bool get requiresNote =>
      this == Classification.atencao || this == Classification.critico;
}

enum RecommendationStatus { pendente, aprovada, recusada }

extension RecommendationStatusX on RecommendationStatus {
  String get label => switch (this) {
        RecommendationStatus.pendente => 'Pendente',
        RecommendationStatus.aprovada => 'Aprovada',
        RecommendationStatus.recusada => 'Recusada',
      };
}

class User {
  const User({required this.id, required this.name, required this.role});

  final String id;
  final String name;
  final Role role;
}

class ServiceOrder {
  const ServiceOrder({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.vehiclePlate,
    required this.vehicleChassi,
    required this.vehicleModel,
    required this.vehicleYear,
    required this.complaint,
    required this.status,
    this.mechanicId,
    this.mechanicName,
  });

  final String id;
  final String customerName;
  final String customerPhone;
  final String vehiclePlate;
  final String vehicleChassi;
  final String vehicleModel;
  final int vehicleYear;
  final String complaint;
  final OrderStatus status;
  final String? mechanicId;
  final String? mechanicName;

  ServiceOrder copyWith({
    OrderStatus? status,
    String? mechanicId,
    String? mechanicName,
  }) {
    return ServiceOrder(
      id: id,
      customerName: customerName,
      customerPhone: customerPhone,
      vehiclePlate: vehiclePlate,
      vehicleChassi: vehicleChassi,
      vehicleModel: vehicleModel,
      vehicleYear: vehicleYear,
      complaint: complaint,
      status: status ?? this.status,
      mechanicId: mechanicId ?? this.mechanicId,
      mechanicName: mechanicName ?? this.mechanicName,
    );
  }
}

class ChecklistGroup {
  const ChecklistGroup(this.name, this.components);

  final String name;
  final List<String> components;
}

/// Mesmo checklist provisório do backend (ADR-003). Em produção deve vir da API.
const List<ChecklistGroup> defaultChecklist = [
  ChecklistGroup('Motor', ['Nível de óleo', 'Correia dentada', 'Velas', 'Filtro de Oleo']),
  ChecklistGroup('Freios', ['Pastilhas', 'Discos', 'Fluido de freio']),
  ChecklistGroup('Suspensão', ['Amortecedores', 'Buchas']),
  ChecklistGroup('Pneus', ['Desgaste', 'Calibragem']),
];

String checkKey(String group, String component) => '$group::$component';

class ComponentCheck {
  const ComponentCheck({
    required this.group,
    required this.component,
    required this.classification,
    this.note = '',
    this.photoIds = const [],
  });

  final String group;
  final String component;
  final Classification classification;
  final String note;
  final List<String> photoIds;
}

class Inspection {
  const Inspection({
    required this.id,
    required this.orderId,
    required this.groups,
    required this.checks,
    this.finalized = false,
    this.summary,
  });

  final String id;
  final String orderId;
  final List<ChecklistGroup> groups;

  /// Indexado por [checkKey].
  final Map<String, ComponentCheck> checks;
  final bool finalized;
  final String? summary;

  int get totalComponents =>
      groups.fold<int>(0, (n, g) => n + g.components.length);

  int get missingCount => totalComponents - checks.length;

  List<ComponentCheck> get criticalChecks => checks.values
      .where((c) => c.classification == Classification.critico)
      .toList();

  Inspection copyWith({
    Map<String, ComponentCheck>? checks,
    bool? finalized,
    String? summary,
  }) {
    return Inspection(
      id: id,
      orderId: orderId,
      groups: groups,
      checks: checks ?? this.checks,
      finalized: finalized ?? this.finalized,
      summary: summary ?? this.summary,
    );
  }
}

class Recommendation {
  const Recommendation({
    required this.id,
    required this.orderId,
    required this.description,
    required this.priceCents,
    required this.status,
  });

  final String id;
  final String orderId;
  final String description;
  final int priceCents;
  final RecommendationStatus status;

  Recommendation copyWith({RecommendationStatus? status}) => Recommendation(
        id: id,
        orderId: orderId,
        description: description,
        priceCents: priceCents,
        status: status ?? this.status,
      );
}
