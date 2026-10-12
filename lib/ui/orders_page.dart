import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../state/providers.dart';
import 'common.dart';
import 'inspection_page.dart';
import 'new_order_page.dart';
import 'order_detail_page.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  String _query = '';

  Future<void> _logout() async {
    Navigator.of(context).popUntil((route) => route.isFirst);
    await ref.read(sessionProvider.notifier).logout();
  }

  Future<void> _open(ServiceOrder order, User user) async {
    final Widget page = user.role == Role.mecanico
        ? InspectionPage(order: order)
        : OrderDetailPage(orderId: order.id);
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) ref.invalidate(ordersProvider);
  }

  Future<void> _newOrder() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const NewOrderPage()),
    );
    if (mounted) ref.invalidate(ordersProvider);
  }

  bool _matches(ServiceOrder o) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return o.vehiclePlate.toLowerCase().contains(q) ||
        o.customerName.toLowerCase().contains(q) ||
        o.vehicleModel.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider);
    if (user == null) return const SizedBox.shrink();
    final orders = ref.watch(ordersProvider);
    final status = ref.watch(statusFilterProvider);
    final isMechanic = user.role == Role.mecanico;

    return Scaffold(
      appBar: AppBar(
        title: Text(isMechanic ? 'Minhas OS' : 'Ordens de serviço'),
        actions: [
          Center(child: Text(user.name)),
          IconButton(
            key: const Key('logout-button'),
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: isMechanic
          ? null
          : FloatingActionButton.extended(
              key: const Key('new-order-fab'),
              onPressed: _newOrder,
              icon: const Icon(Icons.add),
              label: const Text('Nova OS'),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('search-field'),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar por placa, cliente ou modelo',
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<OrderStatus?>(
                  key: const Key('status-filter'),
                  value: status,
                  hint: const Text('Status'),
                  onChanged: (v) => ref.read(statusFilterProvider.notifier).state = v,
                  items: [
                    const DropdownMenuItem<OrderStatus?>(value: null, child: Text('Todos')),
                    for (final s in OrderStatus.values)
                      DropdownMenuItem<OrderStatus?>(value: s, child: Text(s.label)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: orders.when(
              loading: () => const Center(
                child: CircularProgressIndicator(key: Key('orders-loading')),
              ),
              error: (e, _) => ErrorRetry(
                error: e,
                onRetry: () => ref.invalidate(ordersProvider),
              ),
              data: (list) {
                final visible = list.where(_matches).toList();
                if (visible.isEmpty) {
                  return const Center(child: Text('Nenhuma ordem de serviço.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(ordersProvider),
                  child: ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final o = visible[i];
                      return ListTile(
                        key: Key('order-${o.id}'),
                        title: Text('${o.vehiclePlate} · ${o.vehicleModel}'),
                        subtitle: Text('${o.customerName} — ${o.complaint}'),
                        trailing: Chip(label: Text(o.status.label)),
                        onTap: () => _open(o, user),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
