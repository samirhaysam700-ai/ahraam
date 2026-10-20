import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../services/ahram_service.dart';
import '../models/issue.dart';

class DownloadScreen extends StatefulWidget {
  final AhramService service;
  final Issue issue;
  const DownloadScreen({
    super.key,
    required this.service,
    required this.issue,
  });

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final List<String> _log = [];
  int _currentPage = 0;
  bool _running = true;
  bool _done = false;
  String? _error;
  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      _addLog('فتح صفحة القارئ...');
      await widget.service
          .activateSession(widget.issue.flipId, widget.issue.date);
      _addLog('✓ تفعيل الجلسة');

      _addLog('بدء تحميل الصفحات...');
      final images = await widget.service.downloadPages(
        widget.issue.flipId,
        widget.issue.date,
        onLog: (page, msg) {
          _currentPage = page;
          _addLog(msg);
        },
      );

      if (images.isEmpty) {
        throw Exception('لم يتم تحميل أي صفحة');
      }

      _addLog('بناء PDF من ${images.length} صفحة...');
      final pdf = await widget.service.buildPdf(images);

      setState(() {
        _pdfBytes = pdf;
        _done = true;
        _running = false;
      });
      _addLog('✓ تم إنشاء PDF '
          '(${(pdf.length / 1024 / 1024).toStringAsFixed(1)} MB)');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _running = false;
      });
      _addLog('❌ $e');
    }
  }

  void _addLog(String msg) {
    if (!mounted) return;
    setState(() => _log.add(msg));
  }

  Future<void> _share() async {
    if (_pdfBytes == null) return;
    await Printing.sharePdf(
      bytes: _pdfBytes!,
      filename: widget.issue.fileName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.issue.displayDate),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (_running)
            LinearProgressIndicator(
              backgroundColor: Colors.red.shade100,
              valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.red.shade700),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Icon(
                  _done
                      ? Icons.check_circle
                      : _error != null
                          ? Icons.error
                          : Icons.downloading,
                  color: _done
                      ? Colors.green
                      : _error != null
                          ? Colors.red
                          : Colors.red.shade700,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _done
                        ? 'اكتمل التحميل (${_currentPage} صفحة)'
                        : _error != null
                            ? 'حدث خطأ'
                            : 'جاري التحميل... صفحة $_currentPage',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.black87,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _log.length,
                itemBuilder: (_, i) => Text(
                  _log[i],
                  style: const TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'monospace',
                      fontSize: 12),
                ),
              ),
            ),
          ),
          if (_done)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.share),
                  label: const Text('حفظ / مشاركة PDF',
                      style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
