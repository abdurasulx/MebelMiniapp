import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api_client.dart';
import '../../locale_store.dart';
import '../../models.dart';
import '../../widgets/offline_view.dart';
import '../../theme.dart';

/// Faqat ko'rish uchun ombor ro'yxati — boshqaruv (kirim/chiqim, varaq
/// kirim qilish, material qo'shish) hozircha faqat veb-portalda.
class WarehousesScreen extends StatefulWidget {
  const WarehousesScreen({super.key});
  @override
  State<WarehousesScreen> createState() => _WarehousesScreenState();
}

class _WarehousesScreenState extends State<WarehousesScreen> {
  List<Warehouse> _warehouses = [];
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
      final page = await ApiClient.instance.get(
        '/warehouses/',
        (j) => Paginated<Warehouse>.fromJson(j, Warehouse.fromJson),
        auth: true,
      );
      setState(() => _warehouses = page.results);
    } catch (e) {
      setState(() => _error = e);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleStore>();
    if (!_loading && OfflineView.isNetworkError(_error) && _warehouses.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.t('warehouses_title'))),
        body: OfflineView(onRetry: _load),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('warehouses_title'))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && !OfflineView.isNetworkError(_error)
                ? Center(child: Text(_error.toString(), style: const TextStyle(color: AppColors.error)))
                : _warehouses.isEmpty
                    ? ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 60),
                            child: Center(child: Text(loc.t('warehouses_empty'), style: const TextStyle(color: AppColors.textSecondary))),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _warehouses.length,
                        itemBuilder: (context, i) {
                          final w = _warehouses[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: const Icon(Icons.warehouse_outlined),
                              title: Text(w.name),
                              subtitle: Text('${w.kindDisplay} · ${w.address}'),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => WarehouseDetailScreen(warehouse: w)),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class WarehouseDetailScreen extends StatefulWidget {
  final Warehouse warehouse;
  const WarehouseDetailScreen({super.key, required this.warehouse});
  @override
  State<WarehouseDetailScreen> createState() => _WarehouseDetailScreenState();
}

class _WarehouseDetailScreenState extends State<WarehouseDetailScreen> {
  List<MaterialStock> _stocks = [];
  List<MaterialRemnantItem> _remnants = [];
  bool _loading = true;
  Object? _error;

  bool get _isRawMaterial => widget.warehouse.kind == 'raw_material';

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
      if (_isRawMaterial) {
        final stocksPage = await ApiClient.instance.get(
          '/warehouses/${widget.warehouse.id}/material-stocks/',
          (j) => Paginated<MaterialStock>.fromJson(j, MaterialStock.fromJson),
          auth: true,
        );
        final remnantsPage = await ApiClient.instance.get(
          '/warehouses/${widget.warehouse.id}/material-remnants/',
          (j) => Paginated<MaterialRemnantItem>.fromJson(j, MaterialRemnantItem.fromJson),
          auth: true,
        );
        setState(() {
          _stocks = stocksPage.results;
          _remnants = remnantsPage.results;
        });
      }
    } catch (e) {
      setState(() => _error = e);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleStore>();
    if (!_loading && OfflineView.isNetworkError(_error)) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.warehouse.name)),
        body: OfflineView(onRetry: _load),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.warehouse.name)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && !OfflineView.isNetworkError(_error)
                ? Center(child: Text(_error.toString(), style: const TextStyle(color: AppColors.error)))
                : !_isRawMaterial
                    ? ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 60),
                            child: Center(
                              child: Text(
                                loc.t('warehouse_ready_goods_note'),
                                style: const TextStyle(color: AppColors.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          Text(loc.t('warehouse_stocks'), style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 6),
                          if (_stocks.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(loc.t('warehouse_no_stocks'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ),
                          ..._stocks.map(
                            (s) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                dense: true,
                                title: Text(s.materialName),
                                trailing: Text('${formatSom(s.quantity)} ${s.materialUnit}'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(loc.t('warehouse_offcuts_sheets'), style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 6),
                          if (_remnants.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(loc.t('warehouse_no_offcuts'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ),
                          ..._remnants.map(
                            (r) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                dense: true,
                                title: Text(r.materialName),
                                subtitle: Text(
                                  r.width != null
                                      ? '${formatSom(r.width!)} x ${formatSom(r.length)} ${r.materialUnit}'
                                      : '${formatSom(r.length)} ${r.materialUnit}',
                                ),
                                trailing: Text('x${r.quantity}'),
                              ),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}
