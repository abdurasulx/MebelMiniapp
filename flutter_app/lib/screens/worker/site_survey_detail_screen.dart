import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../api_client.dart';
import '../../models.dart';

/// Bitta "joy o'rganish" tafsiloti — usta shu yerda rasm/video yuklaydi,
/// izoh/geolokatsiya kiritadi va tashrifdan so'ng CUSTOM_PROJECT
/// buyurtmasini yaratadi (qarang backend apps.custom_orders).
class SiteSurveyDetailScreen extends StatefulWidget {
  final String surveyId;
  const SiteSurveyDetailScreen({super.key, required this.surveyId});
  @override
  State<SiteSurveyDetailScreen> createState() => _SiteSurveyDetailScreenState();
}

class _SiteSurveyDetailScreenState extends State<SiteSurveyDetailScreen> {
  SiteSurvey? _survey;
  bool _loading = true;
  String? _error;
  final _notesController = TextEditingController();
  bool _busy = false;

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
      final survey = await ApiClient.instance.get(
        '/site-surveys/${widget.surveyId}/',
        (j) => SiteSurvey.fromJson(j as Map<String, dynamic>),
        auth: true,
      );
      _notesController.text = survey.notes;
      setState(() => _survey = survey);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveNotesAndLocation() async {
    setState(() => _busy = true);
    try {
      Position? position;
      try {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
          position = await Geolocator.getCurrentPosition();
        }
      } catch (_) {}
      await ApiClient.instance.patch(
        '/site-surveys/${widget.surveyId}/',
        (j) => j,
        body: {
          'notes': _notesController.text,
          if (position != null) 'latitude': position.latitude,
          if (position != null) 'longitude': position.longitude,
          'status': 'visited',
        },
        auth: true,
      );
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saqlandi')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _addMedia(bool isVideo) async {
    final picker = ImagePicker();
    final XFile? file = isVideo
        ? await picker.pickVideo(source: ImageSource.camera)
        : await picker.pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    setState(() => _busy = true);
    try {
      await ApiClient.instance.postMultipart(
        '/site-surveys/${widget.surveyId}/media/',
        (j) => j,
        fields: {'media_type': isVideo ? 'video' : 'photo'},
        imageFieldName: 'file',
        imagePath: file.path,
        auth: true,
      );
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Joy o\'rganish')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : _survey == null
          ? const SizedBox()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(_survey!.address.isEmpty ? 'Manzil ko\'rsatilmagan' : _survey!.address,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Mijoz: ${_survey!.customerName ?? '—'} · Holat: ${_survey!.statusDisplay}'),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Izoh (o\'lcham, material, joylashuv)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _saveNotesAndLocation,
                  icon: const Icon(Icons.save),
                  label: const Text('Izoh va joylashuvni saqlash'),
                ),
                const SizedBox(height: 24),
                const Text('Rasm/video', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _addMedia(false),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Rasm'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _addMedia(true),
                      icon: const Icon(Icons.videocam),
                      label: const Text('Video'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _survey!.media
                      .map((m) => Chip(
                            avatar: Icon(m.mediaType == 'video' ? Icons.videocam : Icons.image, size: 16),
                            label: Text(m.mediaType == 'video' ? 'Video' : 'Rasm'),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 24),
                if (_survey!.order == null)
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => CreateCustomOrderScreen(survey: _survey!)),
                      );
                      _load();
                    },
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Buyurtma yaratish'),
                  )
                else
                  const Text('Bu joy uchun buyurtma allaqachon yaratilgan.', style: TextStyle(color: Colors.green)),
              ],
            ),
    );
  }
}

class _OrderItemDraft {
  String? productId;
  final widthController = TextEditingController(text: '1');
  final heightController = TextEditingController(text: '1');
  final depthController = TextEditingController(text: '1');
  final qtyController = TextEditingController(text: '1');
  bool isCustomSize = true;
}

/// Usta site-survey asosida CUSTOM_PROJECT buyurtmasini yaratadi.
class CreateCustomOrderScreen extends StatefulWidget {
  final SiteSurvey survey;
  const CreateCustomOrderScreen({super.key, required this.survey});
  @override
  State<CreateCustomOrderScreen> createState() => _CreateCustomOrderScreenState();
}

class _CreateCustomOrderScreenState extends State<CreateCustomOrderScreen> {
  List<Product> _products = [];
  final List<_OrderItemDraft> _items = [_OrderItemDraft()];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ApiClient.instance
        .get('/products/?company=${widget.survey.companySlug}', (j) => Paginated<Product>.fromJson(j, Product.fromJson), auth: true)
        .then((page) => setState(() => _products = page.results))
        .catchError((_) {});
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiClient.instance.post(
        '/site-surveys/${widget.survey.id}/create-order/',
        (j) => j,
        body: {
          'items': _items
              .where((it) => it.productId != null)
              .map((it) => {
                    'product': it.productId,
                    'width': double.tryParse(it.widthController.text) ?? 1,
                    'height': double.tryParse(it.heightController.text) ?? 1,
                    'depth': double.tryParse(it.depthController.text) ?? 1,
                    'quantity': int.tryParse(it.qtyController.text) ?? 1,
                    'is_custom_size': it.isCustomSize,
                  })
              .toList(),
        },
        auth: true,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buyurtma yaratish')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final item in _items) ...[
            DropdownButtonFormField<String>(
              initialValue: item.productId,
              decoration: const InputDecoration(labelText: 'Mahsulot'),
              items: _products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.nameUz))).toList(),
              onChanged: (v) => setState(() => item.productId = v),
            ),
            Row(
              children: [
                Expanded(child: TextField(controller: item.widthController, decoration: const InputDecoration(labelText: 'Eni'), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: item.heightController, decoration: const InputDecoration(labelText: 'Bo\'yi'), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: item.depthController, decoration: const InputDecoration(labelText: 'Chuquri'), keyboardType: TextInputType.number)),
              ],
            ),
            Row(
              children: [
                Expanded(child: TextField(controller: item.qtyController, decoration: const InputDecoration(labelText: 'Soni'), keyboardType: TextInputType.number)),
                Checkbox(value: item.isCustomSize, onChanged: (v) => setState(() => item.isCustomSize = v ?? true)),
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
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
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
