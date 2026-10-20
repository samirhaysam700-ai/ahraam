import 'package:flutter/material.dart';
import '../services/ahram_service.dart';
import '../models/issue.dart';
import 'download_screen.dart';

class IssuesScreen extends StatefulWidget {
  final AhramService service;
  const IssuesScreen({super.key, required this.service});

  @override
  State<IssuesScreen> createState() => _IssuesScreenState();
}

class _IssuesScreenState extends State<IssuesScreen> {
  static const codeBuys = ['2810'];
  List<Issue> _issues = [];
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
      final issues = await widget.service.fetchIssues(codeBuys);
      setState(() => _issues = issues);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إصداراتك'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red)),
                  ),
                )
              : _issues.isEmpty
                  ? const Center(child: Text('لا توجد إصدارات'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _issues.length,
                      itemBuilder: (_, i) {
                        final issue = _issues[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              child: Text('${i + 1}'),
                            ),
                            title: Text(issue.displayDate,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                'فلِب: ${issue.flipId} • ${issue.date}'),
                            trailing: const Icon(Icons.download),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DownloadScreen(
                                    service: widget.service,
                                    issue: issue,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
