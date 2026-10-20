import 'package:flutter/material.dart';
import 'dart:io';
import '../services/ahram_service.dart';
import '../models/issue.dart';
import 'download_screen.dart';
import 'pdf_viewer_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final AhramService service;
  const HomeScreen({super.key, required this.service});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  List<Issue> _issues = [];
  List<File> _savedPdfs = [];
  bool _loadingLibrary = true;
  bool _loadingDownloads = true;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
    _loadDownloads();
  }

  Future<void> _loadLibrary() async {
    setState(() => _loadingLibrary = true);
    try {
      final issues = await widget.service.fetchIssues(['2810']);
      setState(() => _issues = issues);
    } catch (e) {} finally {
      if (mounted) setState(() => _loadingLibrary = false);
    }
  }

  Future<void> _loadDownloads() async {
    setState(() => _loadingDownloads = true);
    try {
      final files = await widget.service.getSavedPdfs();
      setState(() => _savedPdfs = files);
    } catch (e) {} finally {
      if (mounted) setState(() => _loadingDownloads = false);
    }
  }

  Future<void> _logout() async {
    await widget.service.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => LoginScreen(service: widget.service)), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'مكتبتك' : 'تحميلاتك'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout, tooltip: 'تسجيل الخروج'),
        ],
      ),
      body: _currentIndex == 0 ? _buildLibrary() : _buildDownloads(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.library_books), label: 'المكتبة'),
          NavigationDestination(icon: Icon(Icons.download_done), label: 'التحميلات'),
        ],
      ),
    );
  }

  Widget _buildLibrary() {
    if (_loadingLibrary) return const Center(child: CircularProgressIndicator());
    if (_issues.isEmpty) return const Center(child: Text('لا توجد إصدارات'));
    return RefreshIndicator(
      onRefresh: _loadLibrary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _issues.length,
        itemBuilder: (_, i) {
          final issue = _issues[i];
          return Card(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, child: Text('${i + 1}')),
              title: Text(issue.displayDate, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('فلِب: ${issue.flipId} • ${issue.date}'),
              trailing: const Icon(Icons.download),
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => DownloadScreen(service: widget.service, issue: issue)));
                _loadDownloads(); // تحديث قائمة التحميلات بعد الرجوع
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDownloads() {
    if (_loadingDownloads) return const Center(child: CircularProgressIndicator());
    if (_savedPdfs.isEmpty) return const Center(child: Text('لم تقم بتحميل أي ملفات بعد'));
    return RefreshIndicator(
      onRefresh: _loadDownloads,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _savedPdfs.length,
        itemBuilder: (_, i) {
          final file = _savedPdfs[i];
          final fileName = file.path.split('/').last.replaceAll('.pdf', '');
          return Card(
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text(fileName),
              subtitle: Text('${(file.lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => PdfViewerScreen(filePath: file.path, title: fileName)));
              },
            ),
          );
        },
      ),
    );
  }
}
