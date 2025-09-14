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
  final Map<String, int> _lorryCounts = {};

  @override
  void initState() {
    super.initState();
    _future = _loadDeliveries();
  }

  Future<List<Delivery>> _loadDeliveries() async {
    final deliveries = await _repo.getDeliveries();
    
    // Count deliveries by lorry name
    _lorryCounts.clear();
    for (var delivery in deliveries) {
      _lorryCounts.update(
        delivery.lorryName, 
        (value) => value + 1, 
        ifAbsent: () => 1
      );
    }
    
    return deliveries;
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadDeliveries());
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), 
            child: const Text('Cancel')
          ),
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
    
    // Check if lorry already exists and add count if needed
    String finalName = name;
    if (_lorryCounts.containsKey(name)) {
      final count = _lorryCounts[name]! + 1;
      finalName = '$name $count';
    }
    
    final id = await _repo.createDelivery(lorryName: finalName);
    if (!mounted) return;
    
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditDeliveryPage(deliveryId: id))
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Lorry Wood Logger', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[800],
        elevation: 1,
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
            return _buildEmptyState();
          }
          
          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                // Header section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Deliveries',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${data.length} delivery${data.length == 1 ? '' : 's'} recorded',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Delivery list
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final d = data[index];
                      return _DeliveryCard(
                        delivery: d,
                        onOpen: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => EditDeliveryPage(deliveryId: d.id))
                          );
                          await _refresh();
                        },
                        onDelete: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Delivery'),
                              content: const Text('This will delete all groups and widths under this delivery.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false), 
                                  child: const Text('Cancel')
                                ),
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
                    childCount: data.length,
                  ),
                ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNew,
        icon: const Icon(Icons.add, size: 24),
        label: const Text('New Delivery', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_shipping,
              size: 60,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No deliveries yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Start by adding your first wood delivery to track thickness, length, and width measurements',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _addNew,
            icon: const Icon(Icons.add),
            label: const Text('Create First Delivery'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue[700],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
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
    final date = DateFormat('MMM dd, yyyy • HH:mm').format(d.date.toLocal());
    final groups = _counts?.$1 ?? 0;
    final widths = _counts?.$2 ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: widget.onOpen,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_shipping,
                    color: Colors.blue[700],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.lorryName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildCountChip(
                            icon: Icons.layers,
                            label: '$groups groups',
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          _buildCountChip(
                            icon: Icons.straighten,
                            label: '$widths widths',
                            color: Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: Icon(Icons.delete_outline, color: Colors.grey[500]),
                  onPressed: widget.onDelete,
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}