import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api.dart';
import '../domain/models.dart';
import '../state/providers.dart';
import 'common.dart';

/// Rascunho local de um componente até ser salvo no servidor.
class _Draft {
  _Draft({this.classification, this.note = '', List<String>? photoIds})
      : photoIds = photoIds ?? [];

  Classification? classification;
  String note;
  final List<String> photoIds;
  bool dirty = false;

  bool get isComplete =>
      classification != null &&
      (!classification!.requiresNote || note.trim().isNotEmpty);
}

/// Tela do mecânico: inicia/retoma a inspeção, avalia componentes por grupo,
/// anexa fotos, salva o progresso e finaliza com confirmação.
class InspectionPage extends ConsumerStatefulWidget {
  const InspectionPage({super.key, required this.order});

  final ServiceOrder order;

  @override
  ConsumerState<InspectionPage> createState() => _InspectionPageState();
}

class _InspectionPageState extends ConsumerState<InspectionPage> {
  late Future<Inspection> _future;
  Inspection? _inspection;
  final Map<String, _Draft> _drafts = {};
  bool _busy = false;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ref
        .read(inspectionApiProvider)
        .openInspection(widget.order.id)
        .then((i) {
      _adopt(i);
      return i;
    });
  }

  /// Substitui o estado local pelo que o servidor devolveu (retomada).
  void _adopt(Inspection i) {
    _inspection = i;
    _drafts.clear();
    for (final c in i.checks.values) {
      _drafts[checkKey(c.group, c.component)] = _Draft(
        classification: c.classification,
        note: c.note,
        photoIds: List<String>.of(c.photoIds),
      );
    }
  }

  bool get _readOnly => _inspection?.finalized ?? true;

  int get _completeCount => _drafts.values.where((d) => d.isComplete).length;

  Future<void> _guarded(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Envia ao servidor os rascunhos completos e alterados. Devolve quantos
  /// foram salvos.
  Future<int> _saveDrafts() async {
    final api = ref.read(inspectionApiProvider);
    var saved = 0;
    for (final group in _inspection!.groups) {
      for (final component in group.components) {
        final d = _drafts[checkKey(group.name, component)];
        if (d == null || !d.dirty || !d.isComplete) continue;
        await api.saveCheck(
          widget.order.id,
          group: group.name,
          component: component,
          classification: d.classification!,
          note: d.note,
          photoIds: List<String>.of(d.photoIds),
        );
        d.dirty = false;
        saved++;
      }
    }
    return saved;
  }

  Future<void> _saveProgress() async {
    setState(() => _showErrors = true);
    await _guarded(() async {
      final saved = await _saveDrafts();
      if (mounted) showSnack(context, 'Progresso salvo ($saved alteração(ões)).');
    });
  }

  Future<void> _finalize() async {
    setState(() => _showErrors = true);
    final missing = _inspection!.totalComponents - _completeCount;
    if (missing > 0) {
      showSnack(context, 'Faltam $missing componente(s) a avaliar ou observações obrigatórias.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finalizar inspeção?'),
        content: const Text(
          'Após finalizar, o diagnóstico técnico não poderá ser alterado e a OS '
          'seguirá para o comercial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm-finalize'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _guarded(() async {
      await _saveDrafts();
      await ref.read(inspectionApiProvider).finalizeInspection(widget.order.id);
      if (!mounted) return;
      showSnack(context, 'Inspeção finalizada. OS enviada ao comercial.');
      Navigator.of(context).pop();
    });
  }

  Future<void> _addPhoto(_Draft draft) async {
    if (draft.classification == null) {
      showSnack(context, 'Classifique o componente antes de anexar uma foto.');
      return;
    }
    final id = await ref.read(photoPickerProvider).pick();
    if (id == null || !mounted) return;
    setState(() {
      draft.photoIds.add(id);
      draft.dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Scaffold(
      appBar: AppBar(title: Text('Inspeção · ${o.vehiclePlate}')),
      body: FutureBuilder<Inspection>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorRetry(error: snap.error!, onRetry: () => setState(_load));
          }
          return _content(snap.data!);
        },
      ),
    );
  }

  Widget _content(Inspection inspection) {
    final readOnly = inspection.finalized;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Queixa: ${widget.order.complaint}'),
                const SizedBox(height: 4),
                Text(
                  '$_completeCount/${inspection.totalComponents} componentes avaliados',
                  key: const Key('progress-text'),
                ),
                if (readOnly) ...[
                  const SizedBox(height: 8),
                  Text(inspection.summary ?? '', key: const Key('inspection-summary')),
                ],
                for (final group in inspection.groups)
                  SectionCard(
                    title: group.name,
                    child: Column(
                      children: [
                        for (final component in group.components)
                          _componentTile(group.name, component),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!readOnly)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('save-progress'),
                      onPressed: _busy ? null : _saveProgress,
                      child: const Text('Salvar progresso'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('finalize-inspection'),
                      onPressed: _busy ? null : _finalize,
                      child: const Text('Finalizar inspeção'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _componentTile(String group, String component) {
    final key = checkKey(group, component);
    final draft = _drafts.putIfAbsent(key, _Draft.new);
    final readOnly = _readOnly;
    final needsNote = draft.classification?.requiresNote ?? false;
    final noteError = _showErrors && needsNote && draft.note.trim().isEmpty
        ? 'Observação obrigatória'
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(component, style: Theme.of(context).textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: [
              for (final c in Classification.values)
                ChoiceChip(
                  key: Key('chip-${c.name}-$group-$component'),
                  label: Text(c.label),
                  selected: draft.classification == c,
                  onSelected: readOnly
                      ? null
                      : (_) => setState(() {
                            draft.classification = c;
                            draft.dirty = true;
                          }),
                ),
            ],
          ),
          if (needsNote)
            TextFormField(
              key: Key('note-$group-$component'),
              initialValue: draft.note,
              enabled: !readOnly,
              decoration: InputDecoration(labelText: 'Observação', errorText: noteError),
              onChanged: (v) => setState(() {
                draft.note = v;
                draft.dirty = true;
              }),
            ),
          Row(
            children: [
              if (!readOnly)
                TextButton.icon(
                  key: Key('photo-$group-$component'),
                  onPressed: () => _addPhoto(draft),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Foto'),
                ),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final p in draft.photoIds)
                      Chip(
                        key: Key('photo-chip-$group-$component-$p'),
                        label: Text(p.split('/').last),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
