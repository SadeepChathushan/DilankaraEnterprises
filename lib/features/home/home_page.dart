import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../delivery/edit_delivery_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _repo = Repository.instance;
  late Future<List<Delivery>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getDeliveries();
  }

  Future<void> _refresh() async {
    setState(() => _future = _repo.getDeliveries());
  }

  Future<void> _addNew() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Delivery'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Lorry name (e.g., Supun)',
          ),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final name = controller.text.trim();
    if (name.isEmpty) return;
    final id = await _repo.createDelivery(lorryName: name);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditDeliveryPage(deliveryId: id)));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lorry Wood Logger'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Delivery>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data ?? const <Delivery>[];
          if (data.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_shipping, size: 64),
                  const SizedBox(height: 12),
                  const Text('No deliveries yet.', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _addNew,
                    icon: const Icon(Icons.add),
                    label: const Text('New Delivery'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: data.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final d = data[i];
                return _DeliveryCard(
                  delivery: d,
                  onOpen: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditDeliveryPage(deliveryId: d.id)));
                    await _refresh();
                  },
                  onDelete: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Delivery'),
                        content: const Text('This will delete all groups and widths under this delivery.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          FilledButton.tonal(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await Repository.instance.deleteDelivery(d.id);
                      await _refresh();
                    }
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNew,
        icon: const Icon(Icons.add),
        label: const Text('New Delivery'),
      ),
    );
  }
}

class _DeliveryCard extends StatefulWidget {
  const _DeliveryCard({
    required this.delivery,
    required this.onOpen,
    required this.onDelete,
  });

  final Delivery delivery;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  State<_DeliveryCard> createState() => _DeliveryCardState();
}

class _DeliveryCardState extends State<_DeliveryCard> {
  (int, int)? _counts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _counts = await Repository.instance.deliveryCounts(widget.delivery.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.delivery;
    final date = DateFormat('yyyy-MM-dd HH:mm').format(d.date.toLocal());
    final groups = _counts?.$1 ?? 0;
    final widths = _counts?.$2 ?? 0;

    return Card(
      elevation: 1,
      child: InkWell(
        onTap: widget.onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              const CircleAvatar(child: Icon(Icons.local_shipping)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.lorryName, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(date, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      children: [
                        Chip(label: Text('Groups: $groups')),
                        Chip(label: Text('Widths: $widths')),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: widget.onDelete,
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
