import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../api_client.dart';
import '../../models.dart';
import '../../widgets/offline_view.dart';

/// Xodim (ustadan tortib sotuvchi/haydovchigacha) — o'z firmasi
/// buyurtmalarini boshqaradi (status: qabul qilish/yetkazish) VA faqat
/// o'ziga biriktirilgan ishlab chiqarish bosqichlarini bajaradi
/// (progress/complete). Ikkinchisi `/orders/` ichidagi nested
/// `workflow_steps`dan EMAS — u kompaniyaning barcha bosqichini qamrab
/// oladi — balki alohida `/workflow-instances/`dan olinadi, chunki
/// backend shu yerda xodimni o'ziniki bo'lmagan bosqichlarni ko'rishdan
/// avtomatik cheklaydi (qarang apps/workflow/views.py get_queryset).
class WorkerOrdersScreen extends StatefulWidget {
  const WorkerOrdersScreen({super.key});
  @override
  State<WorkerOrdersScreen> createState() => _WorkerOrdersScreenState();
}

class _WorkerOrdersScreenState extends State<WorkerOrdersScreen> {
  List<Order> _orders = [];
  List<WorkflowStepInstance> _myTasks = [];
  bool _loading = true;
  Object? _error;

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
      final ordersPage = await ApiClient.instance.get(
        '/orders/',
        (j) => Paginated<Order>.fromJson(j, Order.fromJson),
        auth: true,
      );
      final tasksPage = await ApiClient.instance.get(
        '/workflow-instances/',
        (j) => Paginated<WorkflowStepInstance>.fromJson(j, WorkflowStepInstance.fromJson),
        auth: true,
      );
      setState(() {
        _orders = ordersPage.results;
        _myTasks = tasksPage.results;
      });
    } catch (e) {
      setState(() => _error = e);
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Shu buyurtmaga tegishli, MENGA biriktirilgan bosqichlar — order'ning
  /// o'z (barcha xodimlarga tegishli) `workflowSteps`i emas.
  List<WorkflowStepInstance> _myStepsFor(Order order) =>
      _myTasks.where((t) => t.order == order.id).toList();

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _postProgress(WorkflowStepInstance step, {required bool complete}) async {
    final commentController = TextEditingController();
    XFile? photo;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(complete ? 'Bosqichni yakunlash' : 'Yangilanish qo\'shish'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: commentController,
                decoration: const InputDecoration(labelText: 'Izoh (ixtiyoriy)'),
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              if (complete && step.photoRequirement == 'required')
                Text(
                  'Bu bosqichni yakunlash uchun rasm majburiy',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error, fontSize: 12),
                ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 85);
                  if (picked != null) setDialogState(() => photo = picked);
                },
                icon: const Icon(Icons.camera_alt_outlined, size: 16),
                label: Text(photo == null ? 'Rasm olish' : 'Rasm olindi ✓'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yuborish')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    if (complete && step.photoRequirement == 'required' && photo == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu bosqich uchun rasm majburiy')),
        );
      }
      return;
    }
    try {
      await ApiClient.instance.postMultipart(
        '/workflow-instances/${step.id}/${complete ? 'complete' : 'progress'}/',
        (j) => j,
        fields: {
          if (commentController.text.isNotEmpty) 'comment': commentController.text,
        },
        imageFieldName: photo != null ? 'image' : null,
        imagePath: photo?.path,
        auth: true,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && OfflineView.isNetworkError(_error) && _orders.isEmpty && _myTasks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Buyurtmalar')),
        body: OfflineView(onRetry: _load),
      );
    }

    final manualTasks = _myTasks.where((t) => t.order == null).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Buyurtmalar')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && !OfflineView.isNetworkError(_error)
                ? Center(child: Text(_error.toString(), style: const TextStyle(color: Colors.red)))
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (manualTasks.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8, left: 4),
                          child: Text('Qo\'shimcha vazifalar', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            children: manualTasks
                                .map((step) => _StepTile(step: step, onProgress: _postProgress))
                                .toList(),
                          ),
                        ),
                      ],
                      if (_orders.isEmpty && manualTasks.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(child: Text('Hozircha vazifa yo\'q.', style: TextStyle(color: Colors.black54))),
                        ),
                      for (final order in _orders)
                        _OrderCard(
                          order: order,
                          mySteps: _myStepsFor(order),
                          onSetStatus: _setStatus,
                          onProgress: _postProgress,
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final Order order;
  final List<WorkflowStepInstance> mySteps;
  final Future<void> Function(Order, String) onSetStatus;
  final Future<void> Function(WorkflowStepInstance, {required bool complete}) onProgress;
  const _OrderCard({
    required this.order,
    required this.mySteps,
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
                  child: Text(o.phone, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Text(o.statusDisplay, style: const TextStyle(fontSize: 12)),
              ],
            ),
            Text(o.address, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text('${formatSom(o.totalPrice)} so\'m', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final s in nextStatuses)
                  OutlinedButton(
                    onPressed: () => widget.onSetStatus(o, s),
                    style: s == 'cancelled' ? OutlinedButton.styleFrom(foregroundColor: Colors.red) : null,
                    child: Text(orderStatusLabel[s] ?? s),
                  ),
                if (widget.mySteps.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: const Icon(Icons.handyman, size: 16),
                    label: Text('Mening bosqichlarim (${widget.mySteps.length})'),
                  ),
              ],
            ),
            if (_expanded)
              ...widget.mySteps.map((step) => _StepTile(step: step, onProgress: widget.onProgress)),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final WorkflowStepInstance step;
  final Future<void> Function(WorkflowStepInstance, {required bool complete}) onProgress;
  const _StepTile({required this.step, required this.onProgress});

  @override
  Widget build(BuildContext context) {
    final canAct = step.status != 'completed' && (step.status == 'in_progress' || step.isAvailable);
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
      subtitle: Text(
        [
          if (step.roleDisplay != null) step.roleDisplay!,
          step.statusDisplay,
          if (step.deadline != null) 'muddat: ${step.deadline}',
        ].join(' · '),
        style: step.isOverdue ? const TextStyle(color: Colors.red, fontWeight: FontWeight.w600) : null,
      ),
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
