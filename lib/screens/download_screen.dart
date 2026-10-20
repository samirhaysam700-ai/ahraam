import 'package:flutter/material.dart';
import '../services/ahram_service.dart';
import '../models/issue.dart';
import 'pdf_viewer_screen.dart';

class DownloadScreen extends StatefulWidget {
  final AhramService service;
  final Issue issue;
  const DownloadScreen({super.key, required this.service, required this.issue});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  double _progress = 0;
  String _status = 'جاري التجهيز...';
  bool _isDone = false;
  String? _error;
  String? _savedPath;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    try {
      final path = await widget.service.downloadAndSavePdf(
        widget.issue.flipId,
        widget.issue.date,
        onProgress: (progress, msg) {
          if (mounted) setState(() { _progress = progress; _status = msg; });
        },
      );
      
      if (mounted) {
        setState(() { _savedPath = path; _isDone = true; });
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PdfViewerScreen(filePath: path, title: widget.issue.displayDate)));
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.issue.displayDate), backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _error != null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 64),
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('رجوع')),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 140, height: 140,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: _progress == 0 ? null : _progress,
                            strokeWidth: 10,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(_isDone ? Colors.green : Colors.red.shade700),
                          ),
                          Center(
                            child: _isDone
                                ? const Icon(Icons.check, color: Colors.green, size: 56)
                                : Text('${(_progress * 100).toInt()}%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(_status, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                    if (_isDone) ...[
                      const SizedBox(height: 40),
                      ElevatedButton.icon(
                        onPressed: () {
                          if (_savedPath != null) {
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PdfViewerScreen(filePath: _savedPath!, title: widget.issue.displayDate)));
                          }
                        },
                        icon: const Icon(Icons.menu_book),
                        label: const Text('قراءة الآن', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
