import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/issue.dart';

class AhramService {
  static const baseUrl = 'https://store.ahram.org.eg';
  static const minSize = 500 * 1024;
  static const maxPages = 200;

  final Dio _dio;
  final PersistCookieJar _cookieJar;

  AhramService._(this._dio, this._cookieJar);

  static Future<AhramService> create() async {
    final dir = await getApplicationDocumentsDirectory();
    final cookiePath = '${dir.path}/cookies/';
    final cookieJar = PersistCookieJar(
      ignoreExpires: true,
      storage: FileStorage(cookiePath),
    );
    
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 90),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13; M2101K9AG) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/155.0.8059.43 Mobile Safari/537.36',
        'Accept-Language': 'ar-EG,ar;q=0.9,en;q=0.8',
        'x-requested-with': 'mark.via.gp',
      },
    ));
    dio.interceptors.add(CookieManager(cookieJar));
    return AhramService._(dio, cookieJar);
  }

  Future<bool> hasSavedSession() async {
    final cookies = await _cookieJar.loadForRequest(Uri.parse(baseUrl));
    return cookies.any((c) => c.name == '.AspNetCore.Session');
  }

  Future<void> logout() async {
    await _cookieJar.deleteAll();
  }

  Future<void> login(String username, String password) async {
    final loginResp = await _dio.get(
      '/ar/Login/Login',
      options: Options(
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Upgrade-Insecure-Requests': '1',
        },
      ),
    );

    final html = loginResp.data.toString();
    final tokenMatch = RegExp(
      r'name="__RequestVerificationToken"[^>]*?value="([^"]+)"',
    ).firstMatch(html);
    
    if (tokenMatch == null) {
      throw Exception('لم يتم العثور على توكن الأمان في صفحة الدخول');
    }
    final token = tokenMatch.group(1)!;

    final body = {
      'UserName': username,
      'UserPw': password,
      '__RequestVerificationToken': token,
    };

    final resp = await _dio.post(
      '/ar/Login/Login',
      data: body,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        followRedirects: false, 
        validateStatus: (s) => s != null && s < 400, 
        headers: {
          'Origin': 'https://store.ahram.org.eg',
          'Referer': 'https://store.ahram.org.eg/ar/Login/Login',
          'Upgrade-Insecure-Requests': '1',
        },
      ),
    );

    if (resp.statusCode == 200) {
      final respBody = resp.data?.toString() ?? '';
      final errMatch = RegExp(
        r'class="[^"]*(?:error|danger|validation|alert)[^"]*"[^>]*>\s*([^<]+)',
      ).firstMatch(respBody);
      
      final errMsg = errMatch?.group(1)?.trim();
      if (errMsg != null && errMsg.isNotEmpty) {
        throw Exception('فشل تسجيل الدخول: $errMsg');
      }
      throw Exception('فشل تسجيل الدخول - تأكد من صحة البيانات');
    }

    await _dio.get('/', options: Options(followRedirects: true, validateStatus: (s) => s != null && s < 500));
  }

  Future<List<Issue>> fetchIssues(List<String> codeBuys) async {
    final all = <Issue>[];
    final seen = <String>{};

    for (final code in codeBuys) {
      try {
        final resp = await _dio.get(
          '/ar/MyLibrary/FillBuyEsdarat',
          queryParameters: {'CodeBuy': code},
          options: Options(
            headers: {
              'X-Requested-With': 'XMLHttpRequest',
              'Referer': '$baseUrl/ar/Mylibrary',
            },
            validateStatus: (s) => s != null && s < 500,
          ),
        );

        if (resp.statusCode != 200) continue;

        final html = resp.data.toString();
        final regex = RegExp(r"/flip/(\d+)/(\d{4}-\d{2}-\d{2})");
        for (final m in regex.allMatches(html)) {
          final key = '${m.group(1)}_${m.group(2)}';
          if (seen.contains(key)) continue;
          seen.add(key);
          all.add(Issue(
            flipId: m.group(1)!,
            date: m.group(2)!,
            codeBuy: code,
          ));
        }
      } catch (_) {}
    }

    all.sort((a, b) => b.date.compareTo(a.date));
    return all;
  }

  Future<void> activateSession(String flipId, String date) async {
    final readerUrl = '$baseUrl/flip/$flipId/$date/mobile';
    try {
      await _dio.get('/flip/$flipId/$date/mobile', options: Options(followRedirects: true, validateStatus: (s) => s != null && s < 500));
    } catch (_) {}
    try {
      await _dio.post('/ar/MyLibrary/SetSessionValue', options: Options(headers: {'X-Requested-With': 'XMLHttpRequest', 'Referer': readerUrl}, validateStatus: (s) => s != null && s < 500));
    } catch (_) {}
    await Future.delayed(const Duration(seconds: 1));
  }

  // دالة جديدة: بتحمل وتعمل PDF وتحفظه في ذاكرة التطبيق
  Future<String> downloadAndSavePdf(
    String flipId,
    String date, {
    void Function(double progress, String message)? onProgress,
  }) async {
    await activateSession(flipId, date);

    final pages = <Uint8List>[];
    int page = 1;
    const expectedPages = 16;

    while (page <= maxPages) {
      final progress = ((page - 1) / expectedPages).clamp(0.0, 0.95);
      onProgress?.call(progress, 'جاري تحميل صفحة $page...');
      
      try {
        final resp = await _dio.get<List<int>>(
          '/flip/$flipId/files/mobile/$page.jpg',
          options: Options(
            responseType: ResponseType.bytes,
            headers: {
              'Referer': '$baseUrl/flip/$flipId/$date/mobile',
              'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
              'sec-fetch-site': 'same-origin',
              'sec-fetch-mode': 'no-cors',
              'sec-fetch-dest': 'image',
            },
            validateStatus: (s) => s != null && s < 500,
          ),
        );

        if (resp.statusCode != 200) break;
        final bytes = Uint8List.fromList(resp.data!);
        if (bytes.length < minSize) break;

        pages.add(bytes);
        page++;
      } catch (e) {
        break;
      }
    }

    if (pages.isEmpty) throw Exception('لم يتم تحميل أي صفحة');

    onProgress?.call(0.95, 'جاري بناء ملف PDF...');
    final pdfBytes = await _buildPdf(pages);

    onProgress?.call(0.98, 'جاري الحفظ...');
    final dir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${dir.path}/pdfs');
    if (!await pdfDir.exists()) await pdfDir.create(recursive: true);

    final fileName = 'ahram_${flipId}_$date.pdf';
    final file = File('${pdfDir.path}/$fileName');
    await file.writeAsBytes(pdfBytes);

    onProgress?.call(1.0, 'اكتمل التحميل');
    return file.path;
  }

  Future<List<File>> getSavedPdfs() async {
    final dir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${dir.path}/pdfs');
    if (!await pdfDir.exists()) return [];
    
    final files = pdfDir.listSync().whereType<File>().where((f) => f.path.endsWith('.pdf')).toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<Uint8List> _buildPdf(List<Uint8List> images) async {
    final doc = pw.Document(compress: true);
    for (final bytes in images) {
      final image = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(image.width!.toDouble(), image.height!.toDouble(), marginAll: 0),
          build: (ctx) => pw.FullPage(ignoreMargins: true, child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );
    }
    return await doc.save();
  }
}
