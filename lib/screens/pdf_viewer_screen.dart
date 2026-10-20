import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String title;

  const PdfViewerScreen({super.key, required this.filePath, required this.title});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  int? pages = 0;
  int currentPage = 0;
  bool isReady = false;
  String errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (isReady)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('${currentPage + 1} / $pages', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          PDFView(
            filePath: widget.filePath,
            enableSwipe: true,
            swipeHorizontal: true,
            autoSpacing: false,
            pageFling: false,
            onRender: (p) {
              setState(() { pages = p; isReady = true; });
            },
            onError: (error) => setState(() => errorMessage = error.toString()),
            onPageChanged: (int? page, int? total) => setState(() => currentPage = page ?? 0),
          ),
          if (errorMessage.isNotEmpty)
            Center(child: Text(errorMessage, style: const TextStyle(color: Colors.red))),
          if (!isReady && errorMessage.isEmpty)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
