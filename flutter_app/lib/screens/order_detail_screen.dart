import 'package:flutter/material.dart';
import '../models.dart';

/// Mijoz tomonidagi buyurtma tafsiloti — ishlab chiqarish bosqichlarini
/// (workflow_steps) FAQAT O'QISH uchun ko'rsatadi (rasm/izoh bilan birga),
/// web'dagi read-only WorkflowPanel bilan bir xil g'oyada. Bosqichni
/// boshlash/yakunlash faqat ustaning o'z ekranida (worker_orders_screen.dart).
class OrderDetailScreen extends StatelessWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF2E7D32);
      case 'approved':
        return const Color(0xFF2563EB);
      case 'cancelled':
        return const Color(0xFFE74C3C);
      case 'in_progress':
        return const Color(0xFFB8860B);
      default:
        return const Color(0xFF8A7357);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = order.workflowSteps;
    return Scaffold(
      appBar: AppBar(title: Text(order.companyName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
          if (steps.isNotEmpty) ...[
            const Text(
              'Ishlab chiqarish jarayoni',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ...steps.map((step) => _StepTile(step: step, color: _statusColor(step.status))),
          ],
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final WorkflowStepInstance step;
  final Color color;
  const _StepTile({required this.step, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(step.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    step.statusDisplay,
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (step.cuttingInstruction != null) ...[
              const SizedBox(height: 6),
              Text(
                step.cuttingInstruction!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF00695C)),
              ),
            ],
            if (step.employeeName != null && step.employeeName!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Ijrochi: ${step.employeeName}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF8A7357)),
              ),
            ],
            if (step.updates.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${step.updates.length} ta yangilanish',
                style: const TextStyle(fontSize: 11, color: Color(0xFF8A7357)),
              ),
              const SizedBox(height: 8),
              // Web'dagi WorkflowPanel bilan bir xil — faqat oxirgisi emas,
              // bosqichning BARCHA yangilanishlari (rasm+izoh+ijrochi+vaqt)
              // ko'rsatiladi, chunki mijoz to'liq jarayonni kuzatishi kerak.
              ...step.updates.map((u) => _UpdateTile(update: u)),
            ],
          ],
        ),
      ),
    );
  }
}

class _UpdateTile extends StatelessWidget {
  final WorkflowProgressUpdate update;
  const _UpdateTile({required this.update});

  String _formatTime(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return '';
    final local = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (update.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                update.imageUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (update.isCompletion)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.check_circle, size: 14, color: Color(0xFF2E7D32)),
                ),
              if (update.employeeName != null && update.employeeName!.isNotEmpty)
                Text(
                  update.employeeName!,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              const SizedBox(width: 6),
              Text(
                _formatTime(update.createdAt),
                style: const TextStyle(fontSize: 11, color: Color(0xFF8A7357)),
              ),
            ],
          ),
          if (update.comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(update.comment, style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
