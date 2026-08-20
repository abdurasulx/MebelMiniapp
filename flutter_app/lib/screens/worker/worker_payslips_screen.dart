import 'package:flutter/material.dart';
import '../../api_client.dart';
import '../../models.dart';
import '../../widgets/offline_view.dart';

const _monthNames = [
  'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
  'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr',
];

String _periodLabel(String period) {
  final parts = period.split('-');
  if (parts.length < 2) return period;
  final m = int.tryParse(parts[1]);
  if (m == null || m < 1 || m > 12) return period;
  return '${_monthNames[m - 1]} ${parts[0]}';
}

/// To'lov turiga mos asosiy summa tavsifi — web'dagi `payBreakdown()`
/// (FirmaPayroll.jsx) bilan bir xil.
String _payBreakdown(Payslip p) {
  final baseSalary = double.tryParse(p.baseSalary) ?? 0;
  final bonusPerTask = double.tryParse(p.bonusPerTask) ?? 0;
  final commissionSales = double.tryParse(p.commissionSales) ?? 0;
  final commissionAmount = double.tryParse(p.commissionAmount) ?? 0;
  final manualHours = double.tryParse(p.manualHours) ?? 0;
  final hourlyAmount = double.tryParse(p.hourlyAmount) ?? 0;
  switch (p.payType) {
    case 'fixed':
      return "${formatSom(baseSalary.toStringAsFixed(0))} so'm/oy";
    case 'fixed_bonus':
      return "${formatSom(baseSalary.toStringAsFixed(0))} so'm + ${p.tasksCompleted} ta × ${formatSom(bonusPerTask.toStringAsFixed(0))}";
    case 'commission':
      return "${formatSom(commissionSales.toStringAsFixed(0))} so'mdan ${formatSom(commissionAmount.toStringAsFixed(0))} so'm";
    case 'hourly':
      final perHour = manualHours > 0 ? hourlyAmount / manualHours : 0;
      return "${formatSom(manualHours.toStringAsFixed(0))} soat × ${formatSom(perHour.toStringAsFixed(0))}";
    default:
      return '—';
  }
}

class WorkerPayslipsScreen extends StatefulWidget {
  const WorkerPayslipsScreen({super.key});
  @override
  State<WorkerPayslipsScreen> createState() => _WorkerPayslipsScreenState();
}

class _WorkerPayslipsScreenState extends State<WorkerPayslipsScreen> {
  List<Payslip> _payslips = [];
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
        '/payslips/',
        (j) => Paginated<Payslip>.fromJson(j, Payslip.fromJson),
        auth: true,
      );
      setState(() => _payslips = page.results);
    } catch (e) {
      setState(() => _error = e);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && OfflineView.isNetworkError(_error) && _payslips.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ish haqim')),
        body: OfflineView(onRetry: _load),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Ish haqim')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && !OfflineView.isNetworkError(_error)
                ? Center(child: Text(_error.toString(), style: const TextStyle(color: Colors.red)))
                : _payslips.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.only(top: 60),
                            child: Center(
                              child: Text("Hali hisoblangan oylik yo'q.", style: TextStyle(color: Colors.black54)),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _payslips.length,
                        itemBuilder: (context, i) {
                          final p = _payslips[i];
                          final extras = StringBuffer('${p.payTypeDisplay} · ${_payBreakdown(p)}');
                          final workflowEarnings = double.tryParse(p.workflowEarnings) ?? 0;
                          final kpiBonus = double.tryParse(p.kpiBonusAmount) ?? 0;
                          if (workflowEarnings > 0) {
                            extras.write(' + ${formatSom(workflowEarnings.toStringAsFixed(0))} workflow');
                          }
                          if (kpiBonus > 0) {
                            extras.write(' + ${formatSom(kpiBonus.toStringAsFixed(0))} KPI bonus');
                          }
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_periodLabel(p.period), style: const TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(extras.toString(), style: Theme.of(context).textTheme.bodySmall),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "${formatSom(p.totalAmount)} so'm",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: p.isPaid ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          p.isPaid ? "To'landi" : 'Kutilmoqda',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: p.isPaid ? Colors.green.shade800 : Colors.orange.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
