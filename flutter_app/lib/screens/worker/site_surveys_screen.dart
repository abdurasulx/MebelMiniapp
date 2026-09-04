import 'package:flutter/material.dart';
import '../../api_client.dart';
import '../../models.dart';
import 'site_survey_detail_screen.dart';

const _statusColor = {
  'assigned': Colors.blueGrey,
  'visited': Colors.orange,
  'order_created': Colors.green,
  'cancelled': Colors.red,
};

/// Ustaga tayinlangan "joy o'rganish" (site survey) topshiriqlari ro'yxati —
/// admin tayinlagach shu yerda ko'rinadi (qarang backend apps.custom_orders.SiteSurvey).
class SiteSurveysScreen extends StatefulWidget {
  const SiteSurveysScreen({super.key});
  @override
  State<SiteSurveysScreen> createState() => _SiteSurveysScreenState();
}

class _SiteSurveysScreenState extends State<SiteSurveysScreen> {
  List<SiteSurvey> _surveys = [];
  bool _loading = true;
  String? _error;

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
        '/site-surveys/',
        (j) => Paginated<SiteSurvey>.fromJson(j, SiteSurvey.fromJson),
        auth: true,
      );
      setState(() => _surveys = page.results);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Joy o\'rganish')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
            : _surveys.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Hali tayinlangan joy yo\'q')),
                ],
              )
            : ListView.builder(
                itemCount: _surveys.length,
                itemBuilder: (context, i) {
                  final s = _surveys[i];
                  return ListTile(
                    leading: Icon(Icons.location_on, color: _statusColor[s.status] ?? Colors.grey),
                    title: Text(s.address.isEmpty ? 'Manzil ko\'rsatilmagan' : s.address),
                    subtitle: Text('${s.customerName ?? 'Mijoz'} · ${s.statusDisplay}'),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => SiteSurveyDetailScreen(surveyId: s.id)),
                      );
                      _load();
                    },
                  );
                },
              ),
      ),
    );
  }
}
