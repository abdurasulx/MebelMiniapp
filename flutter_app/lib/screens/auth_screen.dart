import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_store.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kirish'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Telefon (SMS)'),
            Tab(text: 'Email'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [_PhoneLoginTab(), _EmailLoginTab()],
      ),
    );
  }
}

class _PhoneLoginTab extends StatefulWidget {
  const _PhoneLoginTab();
  @override
  State<_PhoneLoginTab> createState() => _PhoneLoginTabState();
}

class _PhoneLoginTabState extends State<_PhoneLoginTab> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  String? _debugCode;
  bool _codeStep = false;
  bool _busy = false;

  Future<void> _sendCode() async {
    setState(() => _busy = true);
    final auth = context.read<AuthStore>();
    final code = await auth.requestOTP(_phoneController.text.trim());
    setState(() {
      _busy = false;
      if (auth.errorMessage == null) {
        _debugCode = code;
        _codeStep = true;
      }
    });
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    final auth = context.read<AuthStore>();
    await auth.verifyOTP(
      _phoneController.text.trim(),
      _codeController.text.trim(),
    );
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_codeStep) ...[
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon (+998…)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _busy || _phoneController.text.isEmpty
                  ? null
                  : _sendCode,
              child: _busy
                  ? const CircularProgressIndicator()
                  : const Text('Kod yuborish'),
            ),
          ] else ...[
            // SMS provayder hali ulanmagan — dev rejimda kod shu yerda ko'rsatiladi.
            Text(
              _debugCode != null
                  ? 'SMS yuborildi ($_debugCode)'
                  : 'SMS yuborildi',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Kod (6 raqam)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _busy || _codeController.text.isEmpty ? null : _verify,
              child: _busy
                  ? const CircularProgressIndicator()
                  : const Text('Kirish'),
            ),
            TextButton(
              onPressed: () => setState(() => _codeStep = false),
              child: const Text('Raqamni o\'zgartirish'),
            ),
          ],
          if (auth.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(auth.errorMessage!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }
}

class _EmailLoginTab extends StatefulWidget {
  const _EmailLoginTab();
  @override
  State<_EmailLoginTab> createState() => _EmailLoginTabState();
}

class _EmailLoginTabState extends State<_EmailLoginTab> {
  bool _register = false;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    final auth = context.read<AuthStore>();
    if (_register) {
      await auth.register(
        _email.text.trim(),
        _password.text,
        _firstName.text.trim(),
        _phone.text.trim(),
      );
    } else {
      await auth.login(_email.text.trim(), _password.text);
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Kirish')),
              ButtonSegment(value: true, label: Text('Ro\'yxatdan o\'tish')),
            ],
            selected: {_register},
            onSelectionChanged: (s) => setState(() => _register = s.first),
          ),
          const SizedBox(height: 16),
          if (_register) ...[
            TextField(
              controller: _firstName,
              decoration: const InputDecoration(
                labelText: 'Ism',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon (+998…)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Parol',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _busy || _email.text.isEmpty || _password.text.isEmpty
                ? null
                : _submit,
            child: _busy
                ? const CircularProgressIndicator()
                : Text(_register ? 'Ro\'yxatdan o\'tish' : 'Kirish'),
          ),
          if (auth.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(auth.errorMessage!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }
}
