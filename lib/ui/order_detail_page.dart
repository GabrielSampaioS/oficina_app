import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api.dart';
import '../domain/models.dart';
import '../domain/validators.dart';
import '../state/providers.dart';
import 'common.dart';

/// Visão do atendente: dados da OS, atribuição, diagnóstico técnico (somente
/// leitura), serviços recomendados e encerramento.
class OrderDetailPage extends ConsumerWidget {
  const OrderDetailPage({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId));
    return Scaffold(
      appBar: AppBar(title: const Text('Ordem de serviço')),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(orderProvider(orderId))),
        data: (o) => _Body(order: o),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.order});

  final ServiceOrder order;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  String? _selectedMechanic;
  bool _busy = false;

  void _refresh() {
    ref.invalidate(orderProvider(widget.order.id));
    ref.invalidate(inspectionViewProvider(widget.order.id));
    ref.invalidate(recommendationsProvider(widget.order.id));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _refresh();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addRecommendation() async {
    final result = await showDialog<({String description, int cents})>(
      context: context,
      builder: (_) => const _RecommendationDialog(),
    );
    if (result == null || !mounted) return;
    await _run(() => ref.read(commercialApiProvider).addRecommendation(
          widget.order.id,
          description: result.description,
          priceCents: result.cents,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final canAssign = o.status == OrderStatus.aberta || o.status == OrderStatus.atribuida;
    final inspection = ref.watch(inspectionViewProvider(o.id));
    final recs = ref.watch(recommendationsProvider(o.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: '${o.vehiclePlate} · ${o.vehicleModel} (${o.vehicleYear})',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cliente: ${o.customerName} — ${o.customerPhone}'),
              Text('Queixa: ${o.complaint}'),
              Text('Mecânico: ${o.mechanicName ?? 'não atribuído'}'),
              const SizedBox(height: 8),
              Chip(key: const Key('order-status'), label: Text(o.status.label)),
            ],
          ),
        ),
        if (canAssign) _assignSection(),
        SectionCard(
          title: 'Diagnóstico técnico',
          child: inspection.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => ErrorRetry(
              error: e,
              onRetry: () => ref.invalidate(inspectionViewProvider(o.id)),
            ),
            data: (i) => _inspectionView(i),
          ),
        ),
        if (o.status == OrderStatus.aguardandoComercial ||
            o.status == OrderStatus.emExecucao ||
            o.status == OrderStatus.encerrada)
          SectionCard(
            title: 'Serviços recomendados',
            child: recs.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => ErrorRetry(
                error: e,
                onRetry: () => ref.invalidate(recommendationsProvider(o.id)),
              ),
              data: (list) => _recommendationsView(o, list),
            ),
          ),
        if (o.status == OrderStatus.aguardandoComercial || o.status == OrderStatus.emExecucao)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              key: const Key('close-order'),
              onPressed: _busy
                  ? null
                  : () => _run(() => ref.read(ordersApiProvider).closeOrder(o.id)),
              child: const Text('Encerrar OS'),
            ),
          ),
      ],
    );
  }

  Widget _assignSection() {
    final mechanics = ref.watch(mechanicsProvider);
    return SectionCard(
      title: 'Atribuir mecânico',
      child: mechanics.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(mechanicsProvider)),
        data: (list) => Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: const Key('mechanic-dropdown'),
                value: _selectedMechanic,
                hint: const Text('Esc. o mecânico'),
                items: [
                  for (final m in list) DropdownMenuItem<String>(value: m.id, child: Text(m.name)),
                ],
                onChanged: (v) => setState(() => _selectedMechanic = v),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              key: const Key('assign-button'),
              onPressed: _busy || _selectedMechanic == null
                  ? null
                  : () => _run(() => ref
                      .read(ordersApiProvider)
                      .assignMechanic(widget.order.id, _selectedMechanic!)),
              child: const Text('Atribuir'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inspectionView(Inspection? i) {
    if (i == null) return const Text('Inspeção ainda não iniciada.');
    if (!i.finalized) {
      return Text('Inspeção em andamento: ${i.checks.length}/${i.totalComponents} componentes avaliados.');
    }
    final critical = i.criticalChecks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(i.summary ?? '', key: const Key('inspection-summary')),
        const SizedBox(height: 8),
        if (critical.isNotEmpty) const Text('Componentes críticos:'),
        for (final c in critical)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${c.group} / ${c.component}'),
            subtitle: Text(c.note),
            // Exibição das imagens depende do storage de fotos (fatia futura):
            // por ora mostra quantas fotos foram anexadas.
            trailing: Text('${c.photoIds.length} foto(s)'),
          ),
      ],
    );
  }

  Widget _recommendationsView(ServiceOrder o, List<Recommendation> list) {
    final canAdd = o.status == OrderStatus.aguardandoComercial;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (list.isEmpty) const Text('Nenhum serviço registrado.'),
        for (final r in list)
          ListTile(
            key: Key('rec-${r.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(r.description),
            subtitle: Text('${formatMoney(r.priceCents)} · ${r.status.label}'),
            trailing: r.status == RecommendationStatus.pendente && canAdd
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: Key('approve-${r.id}'),
                        tooltip: 'Aprovar',
                        icon: const Icon(Icons.check_circle_outline),
                        onPressed: _busy
                            ? null
                            : () => _run(() =>
                                ref.read(commercialApiProvider).decide(r.id, approve: true)),
                      ),
                      IconButton(
                        key: Key('decline-${r.id}'),
                        tooltip: 'Recusar',
                        icon: const Icon(Icons.cancel_outlined),
                        onPressed: _busy
                            ? null
                            : () => _run(() =>
                                ref.read(commercialApiProvider).decide(r.id, approve: false)),
                      ),
                    ],
                  )
                : null,
          ),
        if (canAdd)
          TextButton.icon(
            key: const Key('add-recommendation'),
            onPressed: _busy ? null : _addRecommendation,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar serviço'),
          ),
      ],
    );
  }
}

class _RecommendationDialog extends StatefulWidget {
  const _RecommendationDialog();

  @override
  State<_RecommendationDialog> createState() => _RecommendationDialogState();
}

class _RecommendationDialogState extends State<_RecommendationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _price = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop((
      description: _description.text.trim(),
      cents: parseMoneyToCents(_price.text)!,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Serviço recomendado'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('rec-desc'),
              controller: _description,
              decoration: const InputDecoration(labelText: 'Descrição'),
              validator: validateDescription,
            ),
            TextFormField(
              key: const Key('rec-price'),
              controller: _price,
              decoration: const InputDecoration(labelText: 'Valor (ex.: 250,00)'),
              keyboardType: TextInputType.number,
              validator: validateMoney,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(key: const Key('rec-save'), onPressed: _save, child: const Text('Salvar')),
      ],
    );
  }
}
