import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../api_client.dart';
import '../../models.dart';
import '../../widgets/offline_view.dart';

/// Xodim (ustadan tortib sotuvchi/haydovchigacha) — o'z firmasi
/// buyurtmalarini KO'RADI (holatini o'zgartirish — qabul qilish/bekor
/// qilish — bu yerda YO'Q, faqat firma egasi/menejer web/admin panelida
/// qila oladi) VA faqat o'ziga biriktirilgan ishlab chiqarish
/// bosqichlarini bajaradi (progress/complete). Ikkinchisi `/orders/`
/// ichidagi nested `workflow_steps`dan EMAS — u kompaniyaning barcha
/// bosqichini qamrab oladi — balki alohida `/workflow-instances/`dan
/// olinadi, chunki backend shu yerda xodimni o'ziniki bo'lmagan
/// bosqichlarni ko'rishdan avtomatik cheklaydi (qarang
/// apps/workflow/views.py get_queryset).
class WorkerOrdersScreen extends StatefulWidget {
  const WorkerOrdersScreen({super.key});
  @override
  State<WorkerOrdersScreen> createState() => _WorkerOrdersScreenState();
}

class _WorkerOrdersScreenState extends State<WorkerOrdersScreen> {
  List<Order> _orders = [];
  List<WorkflowStepInstance> _myTasks = [];
  List<WorkflowStepInstance> _openTasks = [];
  bool _loading = true;
  Object? _error;
  String? _applyingId;

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
      final openPage = await ApiClient.instance.get(
        '/workflow-instances/open/',
        (j) => Paginated<WorkflowStepInstance>.fromJson(j, WorkflowStepInstance.fromJson),
        auth: true,
      );
      setState(() {
        _orders = ordersPage.results;
        _myTasks = tasksPage.results;
        _openTasks = openPage.results;
      });
    } catch (e) {
      setState(() => _error = e);
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Xodimi hali yo'q ("erkin") bosqichga zayavka yuboradi — firma egasi
  /// tasdiqlashini kutadi, darhol biriktirmaydi (qarang backend `apply`).
  Future<void> _applyToOpenTask(WorkflowStepInstance step) async {
    setState(() => _applyingId = step.id);
    try {
      await ApiClient.instance.post(
        '/workflow-instances/${step.id}/apply/',
        (j) => j,
        body: {},
        auth: true,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _applyingId = null);
    }
  }

  /// Shu buyurtmaga tegishli, MENGA biriktirilgan bosqichlar — order'ning
  /// o'z (barcha xodimlarga tegishli) `workflowSteps`i emas.
  List<WorkflowStepInstance> _myStepsFor(Order order) =>
      _myTasks.where((t) => t.order == order.id).toList();

  Future<void> _startTask(WorkflowStepInstance step) async {
    try {
      await ApiClient.instance.patch(
        '/workflow-instances/${step.id}/',
        (j) => j,
        body: {'status': 'in_progress'},
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
                decoration: InputDecoration(
                  labelText: complete && step.commentRequirement == 'required'
                      ? 'Izoh (majburiy)'
                      : 'Izoh (ixtiyoriy)',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              if (complete && step.commentRequirement == 'required')
                Text(
                  'Bu bosqichni yakunlash uchun izoh majburiy',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error, fontSize: 12),
                ),
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
    if (complete && step.commentRequirement == 'required' && commentController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu bosqich uchun izoh majburiy')),
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
                      if (_openTasks.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8, left: 4),
                          child: Text('Erkin topshiriqlar', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8, left: 4, right: 4),
                          child: Text(
                            'Bu bosqichlarga hali usta biriktirilmagan — zayavka yuboring, firma egasi tasdiqlasa sizga o\'tadi.',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ),
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            children: _openTasks
                                .map((step) => _OpenTaskTile(
                                      step: step,
                                      applying: _applyingId == step.id,
                                      onApply: () => _applyToOpenTask(step),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                      if (manualTasks.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8, left: 4),
                          child: Text('Qo\'shimcha vazifalar', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            children: manualTasks
                                .map((step) => _StepTile(step: step, onProgress: _postProgress, onStart: _startTask))
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
                          onProgress: _postProgress,
                          onStart: _startTask,
                        ),
                    ],
                  ),
      ),
    );
  }
}

/// Usta buyurtma HOLATINI o'zgartira olmaydi (qabul qilish/bekor qilish —
/// faqat firma egasi/menejer, admin panelida) — shuning uchun bu yerda
/// endi status tugmalari yo'q, butun karta bosilganda tafsilot ekrani
/// (`_OrderStepsScreen`, mijozning OrderDetailScreen'iga o'xshash) ochiladi.
class _OrderCard extends StatelessWidget {
  final Order order;
  final List<WorkflowStepInstance> mySteps;
  final Future<void> Function(WorkflowStepInstance, {required bool complete}) onProgress;
  final Future<void> Function(WorkflowStepInstance) onStart;
  const _OrderCard({
    required this.order,
    required this.mySteps,
    required this.onProgress,
    required this.onStart,
  });

  /// Karta sarlavhasi — avval telefon raqami bo'lib, qaysi mahsulot
  /// haqida ekani umuman ko'rinmasdi (ayniqsa test ma'lumotlarida manzil
  /// ham "Erkin zayavka testi" kabi mazmunsiz bo'lganda). Endi buyurtma
  /// qatoridagi mahsulot nomlari asosiy sarlavha sifatida ko'rsatiladi.
  String get _title {
    final names = order.items.map((i) => i.productName).where((n) => n.isNotEmpty).toSet();
    return names.isEmpty ? order.phone : names.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final o = order;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _OrderStepsScreen(
              order: o,
              mySteps: mySteps,
              onProgress: onProgress,
              onStart: onStart,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(_title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Text(o.statusDisplay, style: const TextStyle(fontSize: 12)),
                ],
              ),
              Text(
                o.phone,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(o.address, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${formatSom(o.totalPrice)} so\'m', style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (mySteps.isNotEmpty)
                    Text(
                      'Mening bosqichlarim: ${mySteps.length}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Buyurtma tafsiloti — avval `_OrderCard` ichida joyida ochilardi, endi
/// alohida ekranda (buyurtmalar ro'yxati toza qolishi uchun). Ko'rinishi
/// mijozning `OrderDetailScreen`iga o'xshash (narx/holat/progress bar +
/// bosqichlar tarixi), farqi: FAQAT MENGA biriktirilgan bosqichlarda
/// harakat (Boshlash/Yangilash/Yakunlash) tugmalari ko'rinadi — boshqa
/// ustalarning bosqichlari shu yerda faqat holat sifatida ko'rsatiladi.
class _OrderStepsScreen extends StatelessWidget {
  final Order order;
  final List<WorkflowStepInstance> mySteps;
  final Future<void> Function(WorkflowStepInstance, {required bool complete}) onProgress;
  final Future<void> Function(WorkflowStepInstance) onStart;
  const _OrderStepsScreen({
    required this.order,
    required this.mySteps,
    required this.onProgress,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final myStepIds = mySteps.map((s) => s.id).toSet();
    // Ko'p vazifa buyurtmaga bog'liq bo'lmasligi mumkin (qo'lda qo'shilgan) —
    // shunda `order.workflowSteps` bo'sh bo'ladi, faqat mySteps ko'rsatiladi.
    final allSteps = order.workflowSteps.isNotEmpty ? order.workflowSteps : mySteps;
    final productNames = order.items.map((i) => i.productName).where((n) => n.isNotEmpty).toSet();
    final title = productNames.isEmpty ? order.phone : productNames.join(', ');
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.phone, style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
                  const SizedBox(height: 2),
                  Text(
                    '${formatSom(order.totalPrice)} so\'m',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECC299).withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(order.statusDisplay, style: const TextStyle(fontSize: 12)),
                  ),
                  if (order.progressPercent != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (order.progressPercent ?? 0) / 100,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFECC299).withOpacity(0.25),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF8A5A2B)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ishlab chiqarish: ${order.progressPercent}%',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8A7357)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Ishlab chiqarish jarayoni',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          ...allSteps.map(
            (step) => _StepTile(
              step: step,
              isMine: myStepIds.contains(step.id),
              onProgress: onProgress,
              onStart: onStart,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final WorkflowStepInstance step;
  // Boshqa ustaning bosqichi bo'lsa `false` — harakat tugmalari
  // (Boshlash/Yangilash/Yakunlash) yashiriladi, faqat holat ko'rsatiladi.
  final bool isMine;
  final Future<void> Function(WorkflowStepInstance, {required bool complete}) onProgress;
  final Future<void> Function(WorkflowStepInstance) onStart;
  const _StepTile({
    required this.step,
    this.isMine = true,
    required this.onProgress,
    required this.onStart,
  });

  // "Bajardim"/"Yangilanish" tugmalari faqat hali yakunlanmagan bosqichda
  // ko'rsatiladi — "Tasdiqlangan"/"Bekor qilindi" allaqachon yakuniy holat
  // (web'dagi StepStatus.COMPLETED/APPROVED/CANCELLED bilan bir xil).
  static const _finishedStatuses = {'completed', 'approved', 'cancelled'};

  IconData get _icon {
    switch (step.status) {
      case 'completed':
        return Icons.check_circle;
      case 'approved':
        return Icons.verified;
      case 'cancelled':
        return Icons.cancel;
      case 'in_progress':
        return Icons.autorenew;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  Color get _color {
    switch (step.status) {
      case 'completed':
        return Colors.green;
      case 'approved':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // `isMine == false` — boshqa ustaning bosqichi, faqat holat ko'rsatiladi
    // (harakat tugmalari umuman chiqmaydi, backend ham baribir rad etardi,
    // lekin UI'da oldindan yashirilgani tushunarliroq).
    final canAct = isMine &&
        !_finishedStatuses.contains(step.status) &&
        (step.status == 'in_progress' || step.isAvailable);
    // Faqat qo'lda qo'shilgan (manual) va hali kutilayotgan vazifalarga
    // aniq "Boshlash" (pending -> in_progress) tugmasi ko'rsatiladi — web'dagi
    // TaskCard.advance() bilan bir xil naqsh (FirmaProduction.jsx).
    final canStart = isMine && step.isManual && step.status == 'pending' && step.isAvailable;
    return ListTile(
      dense: true,
      isThreeLine: step.description.isNotEmpty,
      leading: Icon(_icon, color: _color),
      title: Text(step.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (step.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(step.description, style: const TextStyle(fontSize: 12.5)),
            ),
          if (step.cuttingInstruction != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                step.cuttingInstruction!,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.teal),
              ),
            )
          else if (step.workTypeName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${step.quantity ?? ''} ${step.workTypeUnitDisplay ?? ''} × ${step.workTypeName}'.trim(),
                style: const TextStyle(fontSize: 12.5, color: Colors.teal),
              ),
            ),
          Text(
            [
              if (step.stageDisplay != null) step.stageDisplay!,
              if (step.roleDisplay != null) step.roleDisplay!,
              step.statusDisplay,
              if (step.deadline != null) 'muddat: ${step.deadline}',
            ].join(' · '),
            style: step.isOverdue ? const TextStyle(color: Colors.red, fontWeight: FontWeight.w600) : null,
          ),
        ],
      ),
      trailing: canStart
          ? OutlinedButton(
              onPressed: () => onStart(step),
              child: const Text('Boshlash'),
            )
          : canAct
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

/// Xodimi hali biriktirilmagan ("erkin") bosqich — usta "Zayavka yuborish"ni
/// bosadi, firma egasi tasdiqlaguncha "Kutilmoqda" holatida turadi (qarang
/// FirmaProduction.jsx OpenPoolView bilan bir xil g'oya).
class _OpenTaskTile extends StatelessWidget {
  final WorkflowStepInstance step;
  final bool applying;
  final VoidCallback onApply;
  const _OpenTaskTile({required this.step, required this.applying, required this.onApply});

  @override
  Widget build(BuildContext context) {
    final pending = step.myApplicationStatus == 'pending';
    return ListTile(
      dense: true,
      title: Text(step.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (step.cuttingInstruction != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                step.cuttingInstruction!,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.teal),
              ),
            ),
          Text(
            [
              if (step.orderDisplay != null) 'Buyurtma ${step.orderDisplay}',
              if (step.roleDisplay != null) step.roleDisplay!,
            ].join(' · '),
          ),
        ],
      ),
      trailing: pending
          ? const Chip(label: Text('Kutilmoqda', style: TextStyle(fontSize: 11)))
          : OutlinedButton(
              onPressed: applying ? null : onApply,
              child: applying
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Zayavka yuborish'),
            ),
    );
  }
}
