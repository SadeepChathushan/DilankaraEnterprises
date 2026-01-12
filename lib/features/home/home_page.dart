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

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final _repo = Repository.instance;
  late Future<List<Delivery>> _future;
  final Map<String, int> _lorryCounts = {};
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _future = _loadDeliveries();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
    _fabAnimationController.forward();
  }

 @override
void dispose() {
  _fabAnimationController.stop();
  _fabAnimationController.dispose();
  super.dispose();
}


  Future<List<Delivery>> _loadDeliveries() async {
    final deliveries = await _repo.getDeliveries();
    _lorryCounts.clear();
    for (var d in deliveries) {
      _lorryCounts.update(d.lorryName, (v) => v + 1, ifAbsent: () => 1);
    }
    return deliveries;
  }

  Future<void> _refresh() async {
  setState(() {
    _future = _loadDeliveries();
  });
  await _future;
}


  Future<void> _addNew() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                Colors.white,
                const Color(0xFFE87A0D).withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE87A0D), Color(0xFFFF9E3D)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE87A0D).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.local_shipping, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'New Delivery',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF1A1A1A)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Lorry Name',
                  hintText: 'e.g., Supun, Kamal',
                  prefixIcon: const Icon(Icons.drive_eta, color: Color(0xFFE87A0D)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE87A0D)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE87A0D), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => Navigator.pop(ctx, true),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE87A0D), Color(0xFFFF9E3D)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE87A0D).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Create Delivery', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (ok != true) return;
    final name = controller.text.trim();
    if (name.isEmpty) return;

    String finalName = name;
    if (_lorryCounts.containsKey(name)) {
      finalName = '$name ${_lorryCounts[name]! + 1}';
    }

    final id = await _repo.createDelivery(lorryName: finalName);
    if (!mounted) return;

    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => EditDeliveryPage(deliveryId: id)));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    body: Container(
  decoration: const BoxDecoration(
    color: Colors.black,
  ),
    child: Stack(
          children: [
  // Background logo watermark
  // Positioned.fill(
  //   child: Opacity(
  //     opacity: 0.08,
  //     child: Image.asset(
  //       'assets/images/Back.png',
  //       fit: BoxFit.contain, // ✅ show full image
  //       alignment: Alignment.center,
  //     ),
  //   ),
  // ),

  // Content overlay
  Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.black.withOpacity(0.3),
          Colors.transparent,
          const Color(0xFFE87A0D).withOpacity(0.1),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverAppBar.large(
          pinned: true,
          floating: true,
          expandedHeight: 160,
          backgroundColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
  width: 48,
  height: 48,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.4),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.asset(
      'assets/images/Dila.png', // 🔥 YOUR LOGO
      fit: BoxFit.cover,
    ),
  ),
),

                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Dilankara Enterprises',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE87A0D).withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Wood Logger',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              // child: IconButton(
              //   tooltip: 'Refresh',
              //   onPressed: _refresh,
              //   icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              // ),
            ),
          ],
        ),
      ],
      body: FutureBuilder<List<Delivery>>(
        future: _future,
        builder: (context, snap) {
if (snap.connectionState == ConnectionState.waiting) {
            return Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE87A0D)),
                ),
              ),
            );
          }

          final data = snap.data ?? const <Delivery>[];
          if (data.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator.adaptive(
            onRefresh: _refresh,
            color: const Color(0xFFE87A0D),
            child: _buildDeliveryList(context, data),
          );
        },
      ),
    ),
  ),
],

        ),
      ),
floatingActionButton: ScaleTransition(
  scale: _fabAnimation,
  child: Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFE87A0D), Color(0xFFFF9E3D)],
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: FloatingActionButton.extended(
      onPressed: _addNew,
      icon: const Icon(Icons.add_rounded),
      label: const Text(
        'Add Delivery',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      elevation: 0,
      highlightElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      splashColor: Colors.transparent,
    ),
  ),
),


    );
  }

  Widget _buildDeliveryList(BuildContext context, List<Delivery> data) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.15),
                  const Color(0xFFE87A0D).withOpacity(0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.inventory_2_rounded, size: 28, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'All Deliveries',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              if (constraints.crossAxisExtent > 600) {
                return SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _DeliveryCard(
                      delivery: data[i],
                      onOpen: () => _openDelivery(data[i]),
                      onDelete: () => _deleteDelivery(data[i]),
                      isGridItem: true,
                    ),
                    childCount: data.length,
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DeliveryCard(
                      delivery: data[i],
                      onOpen: () => _openDelivery(data[i]),
                      onDelete: () => _deleteDelivery(data[i]),
                      isGridItem: false,
                    ),
                  ),
                  childCount: data.length,
                ),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.2),
                    const Color(0xFFE87A0D).withOpacity(0.2),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE87A0D).withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.local_shipping_rounded, size: 70, color: Colors.white),
            ),
            const SizedBox(height: 32),
            const Text(
              'No deliveries yet',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap the button below to add your first delivery.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE87A0D), Color(0xFFFF9E3D)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE87A0D).withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              // child: ElevatedButton.icon(
              //   onPressed: _addNew,
              //   icon: const Icon(Icons.add_rounded, size: 24),
              //   label: const Text('Add First Delivery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              //   style: ElevatedButton.styleFrom(
              //     backgroundColor: Colors.transparent,
              //     foregroundColor: Colors.white,
              //     shadowColor: Colors.transparent,
              //     padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              //   ),
              // ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDelivery(Delivery d) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => EditDeliveryPage(deliveryId: d.id)));
    await _refresh();
  }

  Future<void> _deleteDelivery(Delivery d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 32),
        ),
        title: const Text('Delete Delivery', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          'Delete "${d.lorryName}" delivery? This will remove all associated groups and measurements.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );

if (ok == true) {
  setState(() {
    _future = _future.then(
      (list) => list.where((item) => item.id != d.id).toList(),
    );
  });

  await Repository.instance.deleteDelivery(d.id);
  await _refresh();
}

  }
}

class _DeliveryCard extends StatefulWidget {
  const _DeliveryCard({
    required this.delivery,
    required this.onOpen,
    required this.onDelete,
    required this.isGridItem,
  });

  final Delivery delivery;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final bool isGridItem;

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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onOpen,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: widget.isGridItem
                ? _buildGridLayout(d, date, groups, widths)
                : _buildListLayout(d, date, groups, widths),
          ),
        ),
      ),
    );
  }

  Widget _buildListLayout(Delivery d, String date, int groups, int widths) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE87A0D), Color(0xFFFF9E3D)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE87A0D).withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                d.lorryName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7)),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _countChip(icon: Icons.layers_rounded, label: '$groups groups', color: const Color(0xFFE87A0D)),
                  const SizedBox(width: 8),
                  _countChip(icon: Icons.straighten_rounded, label: '$widths widths', color: const Color(0xFFFF9E3D)),
                ],
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            onPressed: widget.onDelete,
          ),
        ),
      ],
    );
  }

  Widget _buildGridLayout(Delivery d, String date, int groups, int widths) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE87A0D), Color(0xFFFF9E3D)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE87A0D).withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 20),
            ),
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                onPressed: widget.onDelete,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          d.lorryName,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(date, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
        const Spacer(),
        Row(
          children: [
            Expanded(child: _countChip(icon: Icons.layers_rounded, label: '$groups', color: const Color(0xFFE87A0D), compact: true)),
            const SizedBox(width: 8),
            Expanded(child: _countChip(icon: Icons.straighten_rounded, label: '$widths', color: const Color(0xFFFF9E3D), compact: true)),
          ],
        ),
      ],
    );
  }

  Widget _countChip({
    required IconData icon,
    required String label,
    required Color color,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 8 : 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}