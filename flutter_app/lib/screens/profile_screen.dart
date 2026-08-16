import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api_client.dart';
import '../auth_store.dart';
import '../l10n/app_locale.dart';
import '../locale_store.dart';
import '../models.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final loc = context.watch<LocaleStore>();
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('profile_title'))),
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
            child: ListTile(
              leading: const Icon(Icons.language_rounded),
              title: Text(loc.t('profile_language')),
              trailing: Text(
                supportedLocales
                    .firstWhere((l) => l.code == loc.code)
                    .nativeName,
                style: const TextStyle(color: Color(0xFF8A7357)),
              ),
              onTap: () => _pickLanguage(context),
            ),
          ),
          const SizedBox(height: 20),

          // Faqat biror firmada ishlagan/ishlayotgan foydalanuvchida ko'rinadi.
          // Ikkinchi segment matni — hisobda hozir "usta" lavozimi bo'lsa aniq
          // "Usta bilan kirish" deb chiqadi, boshqa lavozim(lar)da esa umumiy
          // "Xodim" (ishchi rejimi hamon barcha lavozimlar uchun ishlaydi —
          // masalan sotuvchi/haydovchi ham shu orqali buyurtmalarni boshqaradi).
          if (user.company != null || _career.isNotEmpty) ...[
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
                  label: Text(user.positions.contains('usta') ? 'Usta bilan kirish' : 'Xodim'),
                ),
              ],
              selected: {auth.appMode},
              onSelectionChanged: (s) => auth.setAppMode(s.first),
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
                    child: Padding(
                      padding: const EdgeInsets.all(12),
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
