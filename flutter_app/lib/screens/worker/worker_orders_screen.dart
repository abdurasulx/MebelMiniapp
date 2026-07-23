import 'package:flutter/material.dart';
import '../../api_client.dart';
import '../../models.dart';

/// Usta: o'z firmasi buyurtmalari — statusni o'zgartiradi va o'ziga tegishli
/// ishlab chiqarish bosqichlarini bajaradi (progress/complete).
///
/// Eslatma (qamrov): rasm yuklash bu yerda hozircha yo'q (web/iOS'da bor) —
/// image_picker + Android ruxsatlari alohida bosqichda qo'shiladi, matnli
/// izoh bilan progress/complete hoziroq ishlaydi.
class WorkerOrdersScreen extends StatefulWidget {
  const WorkerOrdersScreen({super.key});
  @override
  State<WorkerOrdersScreen> createState() => _WorkerOrdersScreenState();
}

class _WorkerOrdersScreenState extends State<WorkerOrdersScreen> {
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ApiClient.instance.get(
        '/orders/',
        (j) => Paginated<Order>.fromJson(j, Order.fromJson),
        auth: true,
      );
      setState(() => _orders = page.results);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _setStatus(Order order, String status) async {
    try {
      await ApiClient.instance.post(
        '/orders/${order.id}/set_status/',
        (j) => j,
        body: {'status': status},
        auth: true,
      );
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _postProgress(
    WorkflowStepInstance step, {
    required bool complete,
  }) async {
    final commentController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(complete ? 'Bosqichni yakunlash' : 'Yangilanish qo\'shish'),
        content: TextField(
          controller: commentController,
          decoration: const InputDecoration(labelText: 'Izoh (ixtiyoriy)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yuborish'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.instance.postMultipart(
        '/workflow-instances/${step.id}/${complete ? 'complete' : 'progress'}/',
        (j) => j,
        fields: {
          if (commentController.text.isNotEmpty)
            'comment': commentController.text,
        },
        auth: true,
      );
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buyurtmalar')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _orders.length,
                itemBuilder: (context, i) => _OrderCard(
                  order: _orders[i],
                  onSetStatus: _setStatus,
                  onProgress: _postProgress,
                ),
              ),
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final Order order;
  final Future<void> Function(Order, String) onSetStatus;
  final Future<void> Function(WorkflowStepInstance, {required bool complete})
  onProgress;
  const _OrderCard({
    required this.order,
    required this.onSetStatus,
    required this.onProgress,
  });

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final nextStatuses = nextOrderStatus[o.status] ?? [];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    o.phone,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(o.statusDisplay, style: const TextStyle(fontSize: 12)),
              ],
            ),
            Text(o.address, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(
              '${formatSom(o.totalPrice)} so\'m',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final s in nextStatuses)
                  OutlinedButton(
                    onPressed: () => widget.onSetStatus(o, s),
                    style: s == 'cancelled'
                        ? OutlinedButton.styleFrom(foregroundColor: Colors.red)
                        : null,
                    child: Text(orderStatusLabel[s] ?? s),
                  ),
                if (o.workflowSteps.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: const Icon(Icons.handyman, size: 16),
                    label: Text(
                      'Ishlab chiqarish (${o.progressPercent ?? 0}%)',
                    ),
                  ),
              ],
            ),
            if (_expanded)
              ...o.workflowSteps.map(
                (step) => _StepTile(step: step, onProgress: widget.onProgress),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final WorkflowStepInstance step;
  final Future<void> Function(WorkflowStepInstance, {required bool complete})
  onProgress;
  const _StepTile({required this.step, required this.onProgress});

  @override
  Widget build(BuildContext context) {
    final canAct =
        step.status != 'completed' &&
        (step.status == 'in_progress' || step.isAvailable);
    return ListTile(
      dense: true,
      leading: Icon(
        step.status == 'completed'
            ? Icons.check_circle
            : step.status == 'in_progress'
            ? Icons.autorenew
            : Icons.radio_button_unchecked,
        color: step.status == 'completed'
            ? Colors.green
            : step.status == 'in_progress'
            ? Colors.blue
            : Colors.grey,
      ),
      title: Text(step.name),
      subtitle: Text('${step.roleDisplay ?? ''} · ${step.statusDisplay}'),
      trailing: canAct
          ? Wrap(
              spacing: 4,
              children: [
                IconButton(
                  icon: const Icon(Icons.send, size: 18),
                  tooltip: 'Yangilanish qo\'shish',
                  onPressed: () => onProgress(step, complete: false),
                ),
                IconButton(
                  icon: const Icon(Icons.check, size: 18),
                  tooltip: 'Yakunlash',
                  onPressed: () => onProgress(step, complete: true),
                ),
              ],
            )
          : null,
    );
  }
}
