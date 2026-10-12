import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api.dart';
import '../domain/validators.dart';
import '../state/providers.dart';
import 'common.dart';

/// Entrada do veículo: cadastra cliente + veículo e abre a OS numa só ação.
class NewOrderPage extends ConsumerStatefulWidget {
  const NewOrderPage({super.key});

  @override
  ConsumerState<NewOrderPage> createState() => _NewOrderPageState();
}

class _NewOrderPageState extends ConsumerState<NewOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _plate = TextEditingController();
  final _chassis = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _complaint = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _plate,
      _chassis,
      _model,
      _year,
      _complaint,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(ordersApiProvider)
          .openOrder(
            customerName: _name.text,
            customerPhone: _phone.text,
            plate: _plate.text,
            chassi: _chassis.text,
            model: _model.text,
            year: int.parse(_year.text.trim()),
            complaint: _complaint.text,
          );
      if (!mounted) return;
      showSnack(context, 'Ordem de serviço aberta.');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    return Scaffold(
      appBar: AppBar(title: const Text('Nova ordem de serviço')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('field-name'),
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nome do cliente'),
                validator: validateName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('field-phone'),
                controller: _phone,
                decoration: const InputDecoration(
                  labelText: 'Telefone (com DDD)',
                ),
                keyboardType: TextInputType.phone,
                validator: validatePhone,
              ),

              const SizedBox(height: 16),
              TextFormField(
                key: const Key('field-plate'),
                controller: _plate,
                decoration: const InputDecoration(labelText: 'Placa'),
                textCapitalization: TextCapitalization.characters,
                validator: validatePlate,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('field-chassis'),
                controller: _chassis,
                decoration: const InputDecoration(labelText: 'Chassi (VIN)'),
                textCapitalization: TextCapitalization.characters,
                validator: validateChassi,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('field-model'),
                controller: _model,
                decoration: const InputDecoration(labelText: 'Modelo'),
                validator: validateModel,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('field-year'),
                controller: _year,
                decoration: const InputDecoration(labelText: 'Ano'),
                keyboardType: TextInputType.number,
                validator: (v) => validateYear(v, currentYear: currentYear),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('field-complaint'),
                controller: _complaint,
                decoration: const InputDecoration(
                  labelText: 'Queixa do cliente',
                ),
                maxLines: 3,
                validator: validateComplaint,
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('submit-order'),
                onPressed: _busy ? null : _submit,
                child: const Text('Abrir OS'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
