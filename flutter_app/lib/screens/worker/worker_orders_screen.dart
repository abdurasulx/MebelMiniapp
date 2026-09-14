import 'dart:io';
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
  // Bildirishnoma (task_assigned/task_available) orqali kelinganda —
  // buyurtmalar ro'yxatida "faol" filtrga tushmasligi mumkin bo'lgan
  // ANIQ buyurtmani ochish uchun (qarang notifications_screen.dart::_open).
  final String? openOrderId;
  const WorkerOrdersScreen({super.key, this.openOrderId});
  @override
  State<WorkerOrdersScreen> createState() => _WorkerOrdersScreenState();
}

class _WorkerOrdersScreenState extends State<WorkerOrdersScreen> {
  List<Order> _orders = [];
  List<WorkflowStepInstance> _myTasks = [];
  List<WorkflowStepInstance> _openTasks = [];
  bool _loading = true;
  Object? _error;
  bool _openedInitial = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// `_isActiveForMe` filtri (pastda) bosqich allaqachon bajarilgan/
  /// tasdiqlangan bo'lsa buyurtmani ro'yxatdan yashiradi — bildirishnoma
  /// orqali kelgan ANIQ buyurtma aynan shu holatda bo'lishi mumkin, shuning
  /// uchun bu yerda filtrsiz, to'g'ridan-to'g'ri ochamiz.
  void _maybeOpenInitial() {
    if (_openedInitial || widget.openOrderId == null) return;
    final matches = _orders.where((o) => o.id == widget.openOrderId);
    if (matches.isEmpty) return;
    final order = matches.first;
    _openedInitial = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _OrderStepsScreen(
            order: order,
            mySteps: _myStepsFor(order),
            onProgress: _postProgress,
            onStart: _startTask,
            onRelease: _releaseTask,
            findOrder: _findOrder,
            findMySteps: _myStepsFor,
          ),
        ),
      );
    });
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
        (j) => Paginated<WorkflowStepInstance>.fromJson(
            j, WorkflowStepInstance.fromJson),
        auth: true,
      );
      final openPage = await ApiClient.instance.get(
        '/workflow-instances/open/',
        (j) => Paginated<WorkflowStepInstance>.fromJson(
            j, WorkflowStepInstance.fromJson),
        auth: true,
      );
      setState(() {
        _orders = ordersPage.results;
        _myTasks = tasksPage.results;
        _openTasks = openPage.results;
      });
      _maybeOpenInitial();
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

  /// `_OrderStepsScreen` alohida marshrut sifatida ochilgani uchun harakat
  /// (progress/complete) bajarilgandan keyin — bu yerdagi `_load()` ro'yxatni
  /// yangilasa ham — o'sha ekran o'zining ESKI (push qilinganda olingan)
  /// `order`/`mySteps` nusxasini ko'rsatishda davom etardi (chiqib-kirmasdan
  /// yangilanmasdi). Shu funksiya orqali harakatdan keyin ENG YANGI
  /// buyurtmani qidirib topib beradi.
  Order? _findOrder(String id) {
    for (final o in _orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// Buyurtma ro'yxatda ko'rsatilishi uchun — MENING bosqichlarimdan
  /// kamida bittasi HOZIR harakat qilinadigan bo'lishi kerak (navbatim
  /// kelgan yoki allaqachon boshlanган). Aks holda (bosqichim allaqachon
  /// bajarilgan/tasdiqlangan, yoki hali navbat boshqa ustaning bosqichida)
  /// buyurtma ro'yxatdan yashiriladi — aks holda tugagan yoki hali
  /// tegishli bo'lmagan buyurtmalar ham cheksiz ko'rinib turaverardi.
  bool _isActiveForMe(Order order) {
    return _myStepsFor(order).any(
      (s) =>
          s.status == 'in_progress' || (s.status == 'pending' && s.isAvailable),
    );
  }

  Future<void> _startTask(WorkflowStepInstance step) async {
    try {
      if (step.isManual) {
        await ApiClient.instance.patch(
          '/workflow-instances/${step.id}/',
          (j) => j,
          body: {'status': 'in_progress'},
          auth: true,
        );
      } else {
        // Retsept bosqichi to'g'ridan-to'g'ri PATCH orqali boshlanmaydi
        // (backend qasddan rad etadi) — `progress` amali ichida
        // `activate_if_ready()` chaqirib, xuddi shu pending->in_progress
        // o'tishni bajaradi; bo'sh so'rov "qabul qilish"ning to'g'ri usuli.
        await ApiClient.instance.post(
          '/workflow-instances/${step.id}/progress/',
          (j) => j,
          body: const {},
        );
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Bosqich qabul qilindi ✓'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Avval qabul qilingan ("erkin" hovuzdan) bosqichni yana ustasiz holatga
  /// qaytaradi — boshqa ustalar qayta ko'radi. Faqat hali tugallanmagan
  /// (pending/in_progress) bosqich uchun ishlaydi (backend tekshiradi).
  Future<void> _releaseTask(WorkflowStepInstance step) async {
    try {
      await ApiClient.instance.post(
        '/workflow-instances/${step.id}/release/',
        (j) => j,
        body: const {},
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bosqich o\'tkazib yuborildi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// `true` — muvaffaqiyatli yuborildi (chaqiruvchi endi buyurtma tafsiloti
  /// ekranini yopishi kerak). `false` — foydalanuvchi bekor qildi (bu holda
  /// ekran ochiq qolishi kerak).
  Future<bool> _postProgress(WorkflowStepInstance step,
      {required bool complete}) async {
    final commentController = TextEditingController();
    XFile? photo;
    // Izoh yozilganini kuzatish uchun — `commentController`ning o'zi
    // StatefulBuilder'ni qayta chizishga majburlamaydi, shuning uchun
    // holatni alohida o'zgaruvchida (setDialogState orqali) saqlaymiz.
    var hasComment = false;
    // "Yuborish" bosilgach avval oyna DARHOL yopilib, so'rov orqa fonda
    // ko'rinmas holda ketardi — natija ko'rinmagani uchun usta ikkinchi
    // marta bosib yuborishi mumkin edi. Endi oyna ochiq qoladi, shaklning
    // o'rniga dumaloq yuklanish belgisi ko'rsatiladi, so'ng — FAQAT
    // buyurtmalar ro'yxati qayta yuklanganidan KEYIN — oyna yopiladi.
    var submitting = false;
    String? submitError;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final photoMissing =
              complete && step.photoRequirement == 'required' && photo == null;
          final commentMissing =
              complete && step.commentRequirement == 'required' && !hasComment;
          final canSubmit = !photoMissing && !commentMissing;

          Future<void> submit() async {
            // Ikki marta ketma-ket bosilsa (tugma hali `submitting` holatiga
            // o'tib ulgurmagan bitta freym ichida) ikkita so'rov/ikkita
            // Navigator.pop chaqiruvi ketib, navigatsiya holati buzilishi
            // mumkin edi — shu yerda ham qo'shimcha himoya.
            if (submitting) return;
            // Klaviatura ochiq holda darhol yuklanish holatiga o'tsa,
            // klaviatura yopilishi bilan oynaning balandligi bir zumda
            // "sakrab" o'zgarardi — avval klaviaturani yopamiz.
            FocusScope.of(ctx).unfocus();
            setDialogState(() {
              submitting = true;
              submitError = null;
            });
            try {
              await ApiClient.instance.postMultipart(
                '/workflow-instances/${step.id}/${complete ? 'complete' : 'progress'}/',
                (j) => j,
                fields: {
                  if (commentController.text.isNotEmpty)
                    'comment': commentController.text,
                },
                imageFieldName: photo != null ? 'image' : null,
                imagePath: photo?.path,
                auth: true,
              );
              // Avval ro'yxatni yangilab, SO'NG oynani yopamiz — aks holda
              // oyna yopilgach ekran hali eski holatni ko'rsatib turgan
              // lahza (miltillash) bo'lardi.
              await _load();
              if (ctx.mounted) Navigator.pop(ctx, true);
            } catch (e) {
              setDialogState(() {
                submitting = false;
                submitError = e.toString();
              });
            }
          }

          return AlertDialog(
            title: Text(complete
                ? 'Bosqichni yakunlash'
                // Ustalar bir necha marta shu oynani "Yakunlash" deb
                // tushunib, bosqichni hech qachon tugatmagan holda izoh
                // qo'shib qo'yaverishgan — sarlavhada ham aniq eslatamiz.
                : 'Izoh/rasm qo\'shish (bosqich tugamaydi)'),
            content: submitting
                // `Center` cheklanmagan balandlikda BERILGAN JOYNING
                // HAMMASINI egallaydi (klaviatura ochilib-yopilishi bilan
                // bog'liq holatda bu ayniqsa butun ekranga cho'zilib
                // ketishga olib keldi) — `SizedBox` bilan aniq, kichik
                // balandlik berilsa, dialog shaklga mos qisqa bo'lib qoladi.
                ? const SizedBox(
                    height: 90,
                    child: Center(
                      child: Opacity(
                          opacity: 0.75, child: CircularProgressIndicator()),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: commentController,
                        decoration: InputDecoration(
                          labelText:
                              complete && step.commentRequirement == 'required'
                                  ? 'Izoh (majburiy)'
                                  : 'Izoh (ixtiyoriy)',
                        ),
                        maxLines: 3,
                        onChanged: (v) => setDialogState(
                            () => hasComment = v.trim().isNotEmpty),
                      ),
                      const SizedBox(height: 10),
                      // Ogohlantirish faqat talab HALI QONDIRILMAGAN bo'lsa
                      // ko'rsatiladi — avval izoh/rasm kiritilgandan keyin ham
                      // doimiy ko'rinib, foydalanuvchini chalg'itadigan xato bor edi.
                      if (commentMissing)
                        Text(
                          'Bu bosqichni yakunlash uchun izoh majburiy',
                          style: TextStyle(
                              color: Theme.of(ctx).colorScheme.error,
                              fontSize: 12),
                        ),
                      if (photoMissing)
                        Text(
                          'Bu bosqichni yakunlash uchun rasm majburiy',
                          style: TextStyle(
                              color: Theme.of(ctx).colorScheme.error,
                              fontSize: 12),
                        ),
                      if (submitError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            submitError!,
                            style: TextStyle(
                                color: Theme.of(ctx).colorScheme.error,
                                fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await ImagePicker().pickImage(
                                  source: ImageSource.camera,
                                  maxWidth: 1600,
                                  imageQuality: 85);
                              if (picked != null)
                                setDialogState(() => photo = picked);
                            },
                            icon:
                                const Icon(Icons.camera_alt_outlined, size: 16),
                            label: Text(
                                photo == null ? 'Rasm olish' : 'Qayta olish'),
                          ),
                          // Rasm olingach oldingi holatda faqat "✓" belgisi
                          // ko'rinardi — olingan rasmning o'zi ko'rinmagani uchun
                          // foydalanuvchi haqiqatan biriktirilganiga ishonchi
                          // komil bo'lmasdi. Endi kichik ko'rinish (thumbnail)
                          // aniq tasdiqlaydi.
                          if (photo != null) ...[
                            const SizedBox(width: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(photo!.path),
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
            actions: submitting
                ? const []
                : [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Bekor')),
                    // Talablar qondirilmaguncha tugma o'chirilgan — foydalanuvchi
                    // "Yuborish"ni bosib, keyin rad javobi olishi (reaktiv xato)
                    // o'rniga, oldindan aniq ko'radi nima yetishmayotganini.
                    ElevatedButton(
                      onPressed: canSubmit ? submit : null,
                      child: const Text('Yuborish'),
                    ),
                  ],
          );
        },
      ),
    );
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              complete ? 'Bosqich yakunlandi ✓' : 'Yangilanish yuborildi ✓'),
          backgroundColor: Colors.green,
        ),
      );
    }
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading &&
        OfflineView.isNetworkError(_error) &&
        _orders.isEmpty &&
        _myTasks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Buyurtmalar')),
        body: OfflineView(onRetry: _load),
      );
    }

    final manualTasks = _myTasks.where((t) => t.order == null).toList();
    final activeOrders = _orders.where(_isActiveForMe).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Buyurtmalar')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && !OfflineView.isNetworkError(_error)
                ? Center(
                    child: Text(_error.toString(),
                        style: const TextStyle(color: Colors.red)))
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (_openTasks.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8, left: 4),
                          child: Text('Erkin topshiriqlar',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const Padding(
                          padding:
                              EdgeInsets.only(bottom: 8, left: 4, right: 4),
                          child: Text(
                            'Bu bosqichlarga hali usta biriktirilmagan — qabul qilsangiz darhol sizga biriktiriladi (tasdiq shart emas).',
                            style:
                                TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ),
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            children: _openTasks
                                .map((step) =>
                                    _OpenTaskTile(step: step, onApplied: _load))
                                .toList(),
                          ),
                        ),
                      ],
                      if (manualTasks.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8, left: 4),
                          child: Text('Qo\'shimcha vazifalar',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            children: manualTasks
                                .map((step) => _StepTile(
                                    step: step,
                                    onProgress: _postProgress,
                                    onStart: _startTask,
                                    onRelease: _releaseTask))
                                .toList(),
                          ),
                        ),
                      ],
                      if (activeOrders.isEmpty &&
                          manualTasks.isEmpty &&
                          _openTasks.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(
                              child: Text('Hozircha vazifa yo\'q.',
                                  style: TextStyle(color: Colors.black54))),
                        ),
                      for (final order in activeOrders)
                        _OrderCard(
                          order: order,
                          mySteps: _myStepsFor(order),
                          onProgress: _postProgress,
                          onStart: _startTask,
                          onRelease: _releaseTask,
                          findOrder: _findOrder,
                          findMySteps: _myStepsFor,
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
  final Future<bool> Function(WorkflowStepInstance, {required bool complete})
      onProgress;
  final Future<void> Function(WorkflowStepInstance) onStart;
  final Future<void> Function(WorkflowStepInstance) onRelease;
  final Order? Function(String id) findOrder;
  final List<WorkflowStepInstance> Function(Order) findMySteps;
  const _OrderCard({
    required this.order,
    required this.mySteps,
    required this.onProgress,
    required this.onStart,
    required this.onRelease,
    required this.findOrder,
    required this.findMySteps,
  });

  /// Karta sarlavhasi — avval telefon raqami bo'lib, qaysi mahsulot
  /// haqida ekani umuman ko'rinmasdi (ayniqsa test ma'lumotlarida manzil
  /// ham "Erkin zayavka testi" kabi mazmunsiz bo'lganda). Endi buyurtma
  /// qatoridagi mahsulot nomlari asosiy sarlavha sifatida ko'rsatiladi.
  String get _title {
    final names = order.items
        .map((i) => i.productName)
        .where((n) => n.isNotEmpty)
        .toSet();
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
              onRelease: onRelease,
              findOrder: findOrder,
              findMySteps: findMySteps,
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
                    child: Text(_title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Text(o.statusDisplay, style: const TextStyle(fontSize: 12)),
                ],
              ),
              Text(
                o.phone,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(o.address, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${formatSom(o.totalPrice)} so\'m',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (mySteps.isNotEmpty)
                    Text(
                      'Mening bosqichlarim: ${mySteps.length}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
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
class _OrderStepsScreen extends StatefulWidget {
  final Order order;
  final List<WorkflowStepInstance> mySteps;
  final Future<bool> Function(WorkflowStepInstance, {required bool complete})
      onProgress;
  final Future<void> Function(WorkflowStepInstance) onStart;
  final Future<void> Function(WorkflowStepInstance) onRelease;
  // `_OrderStepsScreen` push qilingan alohida marshrut bo'lgani uchun
  // ro'yxat sahifasidagi `_load()` bu yerni AVTOMATIK qayta chizmaydi —
  // harakatdan keyin eng yangi order/bosqichlarni shular orqali qidirib
  // topib, mahalliy holatni qo'lda yangilaymiz (qarang `_refresh`).
  final Order? Function(String id) findOrder;
  final List<WorkflowStepInstance> Function(Order) findMySteps;
  const _OrderStepsScreen({
    required this.order,
    required this.mySteps,
    required this.onProgress,
    required this.onStart,
    required this.onRelease,
    required this.findOrder,
    required this.findMySteps,
  });

  @override
  State<_OrderStepsScreen> createState() => _OrderStepsScreenState();
}

class _OrderStepsScreenState extends State<_OrderStepsScreen> {
  late Order _order;
  late List<WorkflowStepInstance> _mySteps;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _mySteps = widget.mySteps;
  }

  void _refresh() {
    final fresh = widget.findOrder(_order.id);
    if (fresh == null || !mounted) return;
    setState(() {
      _order = fresh;
      _mySteps = widget.findMySteps(fresh);
    });
  }

  Future<void> _onProgress(WorkflowStepInstance step,
      {required bool complete}) async {
    final submitted = await widget.onProgress(step, complete: complete);
    if (!submitted) return; // foydalanuvchi "Bekor" bosdi — ekran ochiq qoladi
    // Hisobot ("Yangilash"/"Yakunlash") muvaffaqiyatli yuborilgach — avval
    // ro'yxat (yuqorida, `_load()` orqali) qayta tartiblanadi, so'ng shu
    // buyurtma tafsiloti ekrani AVTOMATIK yopiladi va usta ro'yxatga
    // qaytadi (qo'lda orqaga bosishi shart emas).
    _refresh();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _onStart(WorkflowStepInstance step) async {
    await widget.onStart(step);
    _refresh();
  }

  Future<void> _onRelease(WorkflowStepInstance step) async {
    await widget.onRelease(step);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final mySteps = _mySteps;
    final myStepIds = mySteps.map((s) => s.id).toSet();
    // Ko'p vazifa buyurtmaga bog'liq bo'lmasligi mumkin (qo'lda qo'shilgan) —
    // shunda `order.workflowSteps` bo'sh bo'ladi, faqat mySteps ko'rsatiladi.
    final allSteps =
        order.workflowSteps.isNotEmpty ? order.workflowSteps : mySteps;
    final productNames = order.items
        .map((i) => i.productName)
        .where((n) => n.isNotEmpty)
        .toSet();
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
                  Text(order.phone,
                      style: const TextStyle(
                          fontSize: 12.5, color: Colors.black54)),
                  const SizedBox(height: 2),
                  Text(
                    '${formatSom(order.totalPrice)} so\'m',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECC299).withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(order.statusDisplay,
                        style: const TextStyle(fontSize: 12)),
                  ),
                  if (order.progressPercent != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (order.progressPercent ?? 0) / 100,
                        minHeight: 8,
                        backgroundColor:
                            const Color(0xFFECC299).withOpacity(0.25),
                        valueColor:
                            const AlwaysStoppedAnimation(Color(0xFF8A5A2B)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ishlab chiqarish: ${order.progressPercent}%',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF8A7357)),
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
              onProgress: _onProgress,
              onStart: _onStart,
              onRelease: _onRelease,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatefulWidget {
  final WorkflowStepInstance step;
  // Boshqa ustaning bosqichi bo'lsa `false` — harakat tugmalari
  // (Boshlash/Yangilash/Yakunlash) yashiriladi, faqat holat ko'rsatiladi.
  final bool isMine;
  final Future<void> Function(WorkflowStepInstance, {required bool complete})
      onProgress;
  final Future<void> Function(WorkflowStepInstance) onStart;
  final Future<void> Function(WorkflowStepInstance) onRelease;
  const _StepTile({
    required this.step,
    this.isMine = true,
    required this.onProgress,
    required this.onStart,
    required this.onRelease,
  });

  @override
  State<_StepTile> createState() => _StepTileState();
}

class _StepTileState extends State<_StepTile> {
  // Tarmoq sekin bo'lganda so'rov hali ketayotganini bildiruvchi belgi
  // yo'q edi — foydalanuvchi natija ko'rinmagani uchun boshqa tugmani
  // (yoki xuddi shu tugmani qayta) bosib, ikkita ziddiyatli so'rov
  // yuborib yuborishi mumkin edi (masalan "Yakunlash" o'rniga oxiri
  // "Yangilash" ham ketib qolishi). Endi so'rov davomida ikkala tugma
  // o'chiriladi va aylanuvchi belgi ko'rsatiladi.
  bool _busy = false;

  WorkflowStepInstance get step => widget.step;
  bool get isMine => widget.isMine;

  Future<void> _handleStart() async {
    setState(() => _busy = true);
    try {
      await widget.onStart(step);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleProgress({required bool complete}) async {
    setState(() => _busy = true);
    try {
      await widget.onProgress(step, complete: complete);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleRelease() async {
    setState(() => _busy = true);
    try {
      await widget.onRelease(step);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
    //
    // Bosqich hali "erkin" (pending + isAvailable) bo'lsa — avval aniq
    // BOSHLASH (qabul qilish) kerak, undan keyingina yangilanish/yakunlash
    // tugmalari ko'rinadi. Avval bu faqat qo'lda qo'shilgan (manual)
    // vazifalarga tegishli edi — retsept bosqichlari esa to'g'ridan-to'g'ri
    // yangilanish/yakunlash tugmalarini ko'rsatib, hech kim aniq
    // boshlamasdan turib "bajardim" deb belgilanishi mumkin edi (web'da ham
    // xuddi shu naqsh qo'llanadi, qarang WorkflowPanel.jsx).
    final canStart = isMine && step.status == 'pending' && step.isAvailable;
    final canAct = isMine && step.status == 'in_progress';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
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
                  child: Text(step.description,
                      style: const TextStyle(fontSize: 12.5)),
                ),
              if (step.cuttingInstruction != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    step.cuttingInstruction!,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal),
                  ),
                )
              else if (step.workTypeName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${step.quantity ?? ''} ${step.workTypeUnitDisplay ?? ''} × ${step.workTypeName}'
                        .trim(),
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
                style: step.isOverdue
                    ? const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.w600)
                    : null,
              ),
            ],
          ),
        ),
        // Ikkita tugma avval `ListTile.trailing`ga (balandligi cheklangan)
        // siqib qo'yilgan edi — kichik ekranlarda "BOTTOM OVERFLOWED" xatosi
        // chiqarardi. Endi to'liq kenglikdagi alohida qator, kartaning
        // o'zi bo'yiga cho'zilib ketadi (overflow bo'lishi mumkin emas).
        // Bosqich qabul qilingan ("erkin" hovuzdan olingan) bo'lsa — usta
        // hali boshlamasdan ham uni yana o'tkazib yuborishi (bo'shatishi)
        // mumkin bo'lishi kerak.
        if (canStart)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _handleStart,
                    child: _busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Boshlash'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: _busy ? null : _handleRelease,
                    child: const Text('O\'tkazib yuborish'),
                  ),
                ),
              ],
            ),
          ),
        // Avval "Yangilash" (oraliq izoh) va "Yakunlash" (bosqichni
        // tugatish) bir xil ko'rinishdagi ikkita tugma edi — ustalar
        // ko'p marta "Yangilash"ni bosib, bosqich hech qachon
        // tugallanmasligiga olib kelgan (izoh+rasm kiritilgan bo'lsa
        // ham). Endi "Bosqichni yakunlash" yagona katta/asosiy tugma —
        // oraliq izoh qo'shish esa aniq "tugatmaydi" deb belgilangan
        // kichik matnli havola.
        if (canAct) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : () => _handleProgress(complete: true),
                icon: _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check, size: 16),
                label: const Text('Bosqichni yakunlash'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed:
                      _busy ? null : () => _handleProgress(complete: false),
                  icon: const Icon(Icons.add_comment_outlined, size: 15),
                  label: const Text(
                    'Izoh/rasm qo\'shish (tugatmaydi)',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _handleRelease,
                  child: const Text('O\'tkazib yuborish'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Xodimi hali biriktirilmagan ("erkin") bosqich — qatorga bosilganda
/// alohida sahifa ochiladi, u yerda "Qabul qilish" (zayavka) yoki
/// "O'tkazib yuborish" tanlanadi (qarang `_OpenTaskDetailScreen`) — avval
/// bu yerning o'zida to'g'ridan-to'g'ri tugma bo'lardi, endi ochiq
/// tanlov aniqroq bo'lishi uchun alohida ekranga ko'chirildi.
class _OpenTaskTile extends StatelessWidget {
  final WorkflowStepInstance step;
  final Future<void> Function() onApplied;
  const _OpenTaskTile({required this.step, required this.onApplied});

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
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal),
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
          // `Chip`ning theme'dagi `labelStyle`sida rang ko'rsatilmagani uchun
          // matn ba'zi qurilmalarda ko'rinmay (oq fonda oq/shaffof rang bilan)
          // qolib ketardi — rangni aniq belgilaymiz.
          ? const Chip(
              label: Text('Kutilmoqda',
                  style: TextStyle(fontSize: 11, color: Colors.black87)),
              backgroundColor: Colors.white,
            )
          : const Icon(Icons.chevron_right_rounded,
              size: 20, color: Colors.black38),
      // `pending` bo'lganda ham qatorga kirish mumkin — faqat tafsilot
      // ekranida "Qabul qilish" tugmasi o'rniga "Kutilmoqda" holati
      // ko'rsatiladi (avval bu holatda umuman kirib bo'lmasdi).
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              _OpenTaskDetailScreen(step: step, onApplied: onApplied),
        ),
      ),
    );
  }
}

/// Erkin topshiriq tafsiloti — "Qabul qilish" (zayavka yuborish, firma
/// egasi tasdiqlashini kutadi) yoki "O'tkazib yuborish" (hech narsa
/// qilmasdan ro'yxatga qaytish) shu yerda tanlanadi.
class _OpenTaskDetailScreen extends StatefulWidget {
  final WorkflowStepInstance step;
  final Future<void> Function() onApplied;
  const _OpenTaskDetailScreen({required this.step, required this.onApplied});

  @override
  State<_OpenTaskDetailScreen> createState() => _OpenTaskDetailScreenState();
}

class _OpenTaskDetailScreenState extends State<_OpenTaskDetailScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _apply() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiClient.instance.post(
        '/workflow-instances/${widget.step.id}/apply/',
        (j) => j,
        body: {},
        auth: true,
      );
      await widget.onApplied();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    return Scaffold(
      appBar: AppBar(title: Text(step.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (step.cuttingInstruction != null) ...[
              Text(
                step.cuttingInstruction!,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              [
                if (step.orderDisplay != null) 'Buyurtma ${step.orderDisplay}',
                if (step.roleDisplay != null) step.roleDisplay!,
                if (step.workTypeName != null)
                  '${step.quantity ?? ''} ${step.workTypeUnitDisplay ?? ''} × ${step.workTypeName}'
                      .trim(),
              ].join(' · '),
              style: const TextStyle(color: Colors.black54),
            ),
            const Spacer(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            // "Qabul qilish" endi tasdiq kutmasdan DARHOL biriktiradi —
            // shuning uchun bu yerda "kutish" holati umuman yo'q, faqat
            // ikkita tanlov: qabul qilish yoki o'tkazib yuborish.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('O\'tkazib yuborish'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : _apply,
                    child: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Qabul qilish'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
