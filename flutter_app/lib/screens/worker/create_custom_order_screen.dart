import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../api_client.dart';
import '../../auth_store.dart';
import '../../models.dart';

/// Joylashuvni olishda muvaffaqiyatsizlik — backend hali chaqirilmagan
/// holat, backend javobidan farqli (qarang attendance_store.dart'dagi
/// xuddi shu naqsh).
class _LocationException implements Exception {
  final String message;
  _LocationException(this.message);
  @override
  String toString() => message;
}

class _OrderItemDraft {
  String? productId;
  final widthController = TextEditingController(text: '1');
  final heightController = TextEditingController(text: '1');
  final depthController = TextEditingController(text: '1');
  final qtyController = TextEditingController(text: '1');
  bool isCustomSize = true;
}

/// Usta mijoz uyida turib to'g'ridan-to'g'ri individual (CUSTOM_PROJECT)
/// buyurtma yaratadi — alohida "joy o'rganish" bosqichi endi yo'q.
/// Qurilma geolokatsiyasi (shu jumladan mock-location bayrog'i) olinib
/// buyurtma bilan birga yuboriladi; soxta joylashuv aniqlansa ham
/// buyurtma baribir yaratiladi, lekin firma egasiga xabar boradi
/// (qarang backend apps.custom_orders.serializers.CreateCustomOrderOnSiteSerializer).
class CreateCustomOrderScreen extends StatefulWidget {
  const CreateCustomOrderScreen({super.key});
  @override
  State<CreateCustomOrderScreen> createState() =>
      _CreateCustomOrderScreenState();
}

class _CreateCustomOrderScreenState extends State<CreateCustomOrderScreen> {
  List<Product> _products = [];
  final List<_OrderItemDraft> _items = [_OrderItemDraft()];
  final _customerWorkerIdController = TextEditingController();
  final _addressController = TextEditingController();
  bool _busy = false;
  String? _error;
  // Bazis (mebel CAD) eksport fayli — biriktirilsa, buyurtma yaratilgach
  // darhol yuklanadi va dizaynga bog'lanadi (qarang backend
  // apps.custom_orders.views.DesignBazisImportView). Ixtiyoriy — usta
  // hali CAD faylisiz ham (masalan keyinroq biriktiradigan) buyurtma
  // yaratishi kerak bo'lishi mumkin.
  String? _bazisFilePath;
  String? _bazisFileName;

  Future<void> _pickBazisFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['project'],
    );
    if (files.isEmpty || files.first.path == null) return;
    setState(() {
      _bazisFilePath = files.first.path;
      _bazisFileName = files.first.name;
    });
  }

  @override
  void initState() {
    super.initState();
    final slug = context.read<AuthStore>().user?.company?.slug;
    if (slug != null) {
      ApiClient.instance
          .get('/products/?company=$slug',
              (j) => Paginated<Product>.fromJson(j, Product.fromJson),
              auth: true)
          .then((page) => setState(() => _products = page.results))
          .catchError((_) {});
    }
  }

  Future<Position?> _currentPosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw _LocationException(
          'Joylashuvga ruxsat berilmagan. Sozlamalardan ruxsat bering.');
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw _LocationException('Joylashuv xizmati o\'chirilgan.');
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      throw _LocationException('Joylashuv aniqlanmadi. Qayta urining.');
    }
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      Position? position;
      try {
        position = await _currentPosition();
      } catch (_) {
        position = null;
      }
      final created = await ApiClient.instance.post(
        '/custom-orders/create/',
        (j) => j as Map<String, dynamic>,
        body: {
          'items': _items
              .where((it) => it.productId != null)
              .map((it) => {
                    'product': it.productId,
                    'variant': null,
                    'width': double.tryParse(it.widthController.text) ?? 1,
                    'height': double.tryParse(it.heightController.text) ?? 1,
                    'depth': double.tryParse(it.depthController.text) ?? 1,
                    'quantity': int.tryParse(it.qtyController.text) ?? 1,
                    'is_custom_size': it.isCustomSize,
                  })
              .toList(),
          'customer_worker_id': _customerWorkerIdController.text,
          'address': _addressController.text,
          if (position != null) 'latitude': position.latitude,
          if (position != null) 'longitude': position.longitude,
          if (position != null) 'accuracy': position.accuracy,
          if (position != null) 'is_mock': position.isMocked,
          if (position != null)
            'device_timestamp': position.timestamp.toIso8601String(),
          'platform': 'android',
        },
        auth: true,
      );

      // Bazis fayli biriktirilgan bo'lsa, buyurtma yaratilgan zahoti
      // yuklaymiz — dizayn "Ishlab chiqarishga" o'tkazilganda backend shu
      // fayldagi detal/teshik ma'lumotidan haqiqiy topshiriqlarni avtomatik
      // yaratadi (qarang create_workflow_instances_from_design). Bu
      // muvaffaqiyatsiz bo'lsa ham buyurtmaning o'zi yaratilgan bo'ladi —
      // shuning uchun xatoni butun oqimni to'xtatmasdan, alohida ko'rsatamiz.
      String? bazisWarning;
      final orderId = created['id'] as String?;
      if (_bazisFilePath != null && orderId != null) {
        try {
          await ApiClient.instance.postMultipart(
            '/custom-orders/$orderId/import-bazis/',
            (j) => j,
            imageFieldName: 'file',
            imagePath: _bazisFilePath!,
            auth: true,
          );
        } catch (e) {
          bazisWarning = 'Buyurtma yaratildi, lekin Bazis fayli yuklanmadi: $e';
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(bazisWarning ?? 'Buyurtma yaratildi')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Individual loyiha')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _customerWorkerIdController,
            decoration: const InputDecoration(
              labelText: 'Mijoz qidiruvchi ID',
              helperText:
                  'Mijoz shu ID orqali o\'z ilovasida buyurtmani kuzatib borishi mumkin bo\'ladi.',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(labelText: 'Manzil (ixtiyoriy)'),
          ),
          const SizedBox(height: 12),
          for (final item in _items) ...[
            DropdownButtonFormField<String>(
              initialValue: item.productId,
              decoration: const InputDecoration(labelText: 'Mahsulot'),
              items: _products
                  .map((p) =>
                      DropdownMenuItem(value: p.id, child: Text(p.nameUz)))
                  .toList(),
              onChanged: (v) => setState(() => item.productId = v),
            ),
            Row(
              children: [
                Expanded(
                    child: TextField(
                        controller: item.widthController,
                        decoration: const InputDecoration(labelText: 'Eni'),
                        keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: item.heightController,
                        decoration: const InputDecoration(labelText: 'Bo\'yi'),
                        keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: item.depthController,
                        decoration: const InputDecoration(labelText: 'Chuquri'),
                        keyboardType: TextInputType.number)),
              ],
            ),
            Row(
              children: [
                Expanded(
                    child: TextField(
                        controller: item.qtyController,
                        decoration: const InputDecoration(labelText: 'Soni'),
                        keyboardType: TextInputType.number)),
                Checkbox(
                    value: item.isCustomSize,
                    onChanged: (v) =>
                        setState(() => item.isCustomSize = v ?? true)),
                const Text('Narx keyinroq'),
              ],
            ),
            const Divider(),
          ],
          TextButton.icon(
            onPressed: () => setState(() => _items.add(_OrderItemDraft())),
            icon: const Icon(Icons.add),
            label: const Text('Band qo\'shish'),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.upload_file),
            title: Text(_bazisFileName ?? 'Bazis fayl biriktirish (ixtiyoriy)'),
            subtitle: _bazisFileName == null
                ? const Text(
                    'CAD dasturidan eksport qilingan .project fayli — detal/teshik'
                    ' ma\'lumotidan ishlab chiqarish topshiriqlari avtomatik tuziladi.')
                : null,
            trailing: _bazisFileName != null
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _bazisFilePath = null;
                      _bazisFileName = null;
                    }),
                  )
                : null,
            onTap: _pickBazisFile,
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Yaratilmoqda…' : 'Buyurtma yaratish'),
          ),
        ],
      ),
    );
  }
}
