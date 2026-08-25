import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api_client.dart';
import '../auth_store.dart';
import '../l10n/app_locale.dart';
import '../locale_store.dart';
import '../models.dart';
import '../positions.dart';
import '../widgets/phone_verify_dialog.dart';
import 'auth_screen.dart';
import 'notifications_screen.dart';
import 'order_detail_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final loc = context.watch<LocaleStore>();
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('profile_title')),
        actions: [if (auth.user != null) const NotificationBellButton()],
      ),
      body: auth.user == null
          ? const AuthScreen()
          : _ProfileBody(user: auth.user!),
    );
  }
}

Future<void> _pickLanguage(BuildContext context) async {
  final loc = context.read<LocaleStore>();
  final selected = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: supportedLocales
            .map(
              (l) => ListTile(
                leading: Text(l.flag, style: const TextStyle(fontSize: 22)),
                title: Text(l.nativeName),
                trailing: loc.code == l.code
                    ? const Icon(Icons.check, color: Color(0xFF4C2C24))
                    : null,
                onTap: () => Navigator.pop(ctx, l.code),
              ),
            )
            .toList(),
      ),
    ),
  );
  if (selected != null) await loc.setLocale(selected);
}

class _ProfileBody extends StatefulWidget {
  final AppUser user;
  const _ProfileBody({required this.user});

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  List<EmployeeInvitation> _invitations = [];
  List<CareerEntry> _career = [];
  List<Order> _orders = [];
  bool _loading = true;
  String? _busyInvitationId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final invPage = await ApiClient.instance.get(
        '/employee-invitations/',
        (j) => Paginated<EmployeeInvitation>.fromJson(
          j,
          EmployeeInvitation.fromJson,
        ),
        auth: true,
      );
      final careerPage = await ApiClient.instance.get(
        '/users/me/career/',
        (j) => Paginated<CareerEntry>.fromJson(j, CareerEntry.fromJson),
        auth: true,
      );
      final ordersPage = await ApiClient.instance.get(
        '/orders/',
        (j) => Paginated<Order>.fromJson(j, Order.fromJson),
        auth: true,
      );
      setState(() {
        _invitations = invPage.results;
        _career = careerPage.results;
        _orders = ordersPage.results;
      });
    } catch (_) {
      // jim turamiz — profil baribir ko'rinadi
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _respond(EmployeeInvitation inv, bool accept) async {
    setState(() => _busyInvitationId = inv.id);
    try {
      await ApiClient.instance.post(
        '/employee-invitations/${inv.id}/${accept ? 'accept' : 'decline'}/',
        (j) => j,
        auth: true,
      );
      if (mounted) {
        await context.read<AuthStore>().refreshUser();
        await _load();
      }
    } catch (_) {
      // jim turamiz
    } finally {
      if (mounted) setState(() => _busyInvitationId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final auth = context.watch<AuthStore>();
    final loc = context.watch<LocaleStore>();
    final pendingInvitations = _invitations
        .where((i) => i.status == 'pending')
        .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFECC299),
                child: Text(
                  (user.firstName?.isNotEmpty == true
                          ? user.firstName![0]
                          : user.email[0])
                      .toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF4C2C24),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.firstName?.isNotEmpty == true
                          ? user.firstName!
                          : user.email,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (user.workerId != null)
                      Row(
                        children: [
                          Text(
                            'ID: ${user.workerId}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 14),
                            onPressed: () => Clipboard.setData(
                              ClipboardData(text: user.workerId!),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        user.phoneVerified ? Icons.verified : Icons.error_outline,
                        color: user.phoneVerified ? Colors.green : Colors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          user.phoneVerified ? 'Tasdiqlangan profil' : 'Tasdiqlanmagan profil',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (!user.phoneVerified)
                        TextButton(
                          onPressed: () async {
                            final ok = await showPhoneVerifyDialog(context, initialPhone: user.phone);
                            if (ok == true && context.mounted) auth.refreshUser();
                          },
                          child: const Text('Tasdiqlash'),
                        ),
                    ],
                  ),
                  if (!user.phoneVerified)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        'Tasdiqlanmagan profil bilan buyurtma bera olmaysiz.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF8A7357)),
                      ),
                    ),
                  const Divider(height: 24),
                  const Text("Bog'langan hisoblar", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _LinkedAccountRow(
                    iconAsset: 'assets/icons/google_logo.png',
                    label: 'Google',
                    linked: user.hasGoogle,
                    onLink: () async {
                      final ok = await auth.linkGoogle();
                      if (!ok && auth.errorMessage != null && context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(auth.errorMessage!)));
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  _LinkedAccountRow(
                    iconAsset: 'assets/icons/telegram_logo.png',
                    label: 'Telegram',
                    linked: user.hasTelegram,
                    onLink: () async {
                      final ok = await auth.linkTelegram();
                      if (!ok && auth.errorMessage != null && context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(auth.errorMessage!)));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Card(
            child: ListTile(
              leading: const Icon(Icons.language_rounded),
              title: Text(loc.t('profile_language')),
              trailing: Builder(
                builder: (_) {
                  final current = supportedLocales.firstWhere((l) => l.code == loc.code);
                  return Text(
                    '${current.flag} ${current.nativeName}',
                    style: const TextStyle(color: Color(0xFF8A7357)),
                  );
                },
              ),
              onTap: () => _pickLanguage(context),
            ),
          ),
          const SizedBox(height: 20),

          // Faqat biror firmada ishlagan/ishlayotgan foydalanuvchida ko'rinadi.
          // Ikkinchi tugma matni — bitta kasbi bo'lsa aniq "{Kasb} bilan
          // kirish" (masalan "Usta bilan kirish"), bosilganda to'g'ridan-
          // to'g'ri o'sha rolga o'tadi. Bir nechta kasbi bo'lsa "Xodim
          // sifatida kirish" — bosilganda qaysi rolda ishlashini so'raydi.
          if (user.positions.isNotEmpty) ...[
            const Text(
              'Ko\'rinish rejimi',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<AppMode>(
              segments: [
                const ButtonSegment(value: AppMode.customer, label: Text('Xaridor')),
                ButtonSegment(
                  value: AppMode.worker,
                  label: Text(
                    user.positions.length == 1
                        ? '${positionInfo(user.positions.first).label} bilan kirish'
                        : 'Xodim sifatida kirish',
                  ),
                ),
              ],
              selected: {auth.appMode},
              onSelectionChanged: (s) async {
                if (s.first == AppMode.customer) {
                  auth.setAppMode(AppMode.customer);
                } else if (user.positions.length == 1) {
                  auth.enterWorkerMode(user.positions.first);
                } else {
                  final chosen = await showModalBottomSheet<String>(
                    context: context,
                    showDragHandle: true,
                    builder: (ctx) => _RolePickerSheet(positions: user.positions),
                  );
                  if (chosen != null) auth.enterWorkerMode(chosen);
                }
              },
            ),
            if (auth.appMode == AppMode.worker && auth.activePosition != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Hozir: ${positionInfo(auth.activePosition!).label}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8A7357)),
                ),
              ),
            const SizedBox(height: 20),
          ],

          if (_loading) const Center(child: CircularProgressIndicator()),

          if (pendingInvitations.isNotEmpty) ...[
            const Text(
              'Ish takliflari',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...pendingInvitations.map(
              (inv) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv.companyName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        inv.positions.join(', '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _busyInvitationId == inv.id
                                ? null
                                : () => _respond(inv, true),
                            child: const Text('Qabul qilish'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _busyInvitationId == inv.id
                                ? null
                                : () => _respond(inv, false),
                            child: const Text('Rad etish'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (_career.isNotEmpty) ...[
            const Text(
              'Ish tarixi (karyera)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._career.map(
              (c) => ListTile(
                dense: true,
                leading: Icon(c.isActive ? Icons.work : Icons.work_outline),
                title: Text(c.companyName),
                subtitle: Text(c.positions.join(', ')),
                trailing: c.isActive
                    ? const Text(
                        'hozir',
                        style: TextStyle(color: Colors.green, fontSize: 12),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),
          ],

          OutlinedButton(
            onPressed: () => context.read<AuthStore>().logout(),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: Text(loc.t('common_logout')),
          ),
          const SizedBox(height: 20),

          const Text(
            'So\'nggi buyurtmalar',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_orders.isEmpty)
            const Text(
              'Hali buyurtma yo\'q',
              style: TextStyle(color: Color(0xFF8A7357)),
            )
          else ...[
            // Ro'yxat cheklanadi: firma egasi uchun barcha buyurtmalar ko'p
            // bo'lishi mumkin — bu yerda faqat so'nggilari ko'rsatiladi.
            ..._orders
                .take(5)
                .map(
                  (o) => Card(
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    o.companyName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${formatSom(o.totalPrice)} so\'m',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECC299).withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      o.statusDisplay,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Color(0xFF8A7357)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            if (_orders.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'va yana ${_orders.length - 5} ta buyurtma',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A7357),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// "Bog'langan hisoblar" ro'yxatidagi bitta qator (Google/Telegram) —
/// bog'langan bo'lsa belgi, aks holda "Bog'lash" tugmasi (o'zining
/// alohida `_busy` holati bilan, boshqa qatorga ta'sir qilmasligi uchun).
class _LinkedAccountRow extends StatefulWidget {
  final String iconAsset;
  final String label;
  final bool linked;
  final Future<void> Function() onLink;
  const _LinkedAccountRow({
    required this.iconAsset,
    required this.label,
    required this.linked,
    required this.onLink,
  });

  @override
  State<_LinkedAccountRow> createState() => _LinkedAccountRowState();
}

class _LinkedAccountRowState extends State<_LinkedAccountRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(widget.iconAsset, width: 20, height: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(widget.label)),
        if (widget.linked)
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 16),
              SizedBox(width: 4),
              Text("Bog'langan", style: TextStyle(color: Colors.green, fontSize: 12)),
            ],
          )
        else
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await widget.onLink();
                    if (mounted) setState(() => _busy = false);
                  },
            child: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Bog'lash"),
          ),
      ],
    );
  }
}

/// Bir nechta kasbi bor xodim uchun — bugun qaysi rolda ishlashini tanlaydi
/// (web'dagi RolePicker bilan bir xil vazifa).
class _RolePickerSheet extends StatelessWidget {
  final List<String> positions;
  const _RolePickerSheet({required this.positions});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bugun qaysi rolda ishlaysiz?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            for (final p in positions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFECC299),
                  child: Icon(positionInfo(p).icon, color: const Color(0xFF4C2C24), size: 20),
                ),
                title: Text(positionInfo(p).label, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(positionInfo(p).desc),
                onTap: () => Navigator.pop(context, p),
              ),
          ],
        ),
      ),
    );
  }
}
