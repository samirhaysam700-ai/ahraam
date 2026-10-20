import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/issue.dart';

class AhramService {
  static const baseUrl = 'https://store.ahram.org.eg';
  static const minSize = 500 * 1024;
  static const maxPages = 200;

  final Dio _dio;

  AhramService._(this._dio);

  static Future<AhramService> create() async {
    final jar = CookieJar();
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
    dio.interceptors.add(CookieManager(jar));
    return AhramService._(dio);
  }

  // ========== تسجيل الدخول ==========
  Future<void> login(String username, String password) async {
    final loginResp = await _dio.get('/ar/Login/Login');
    final html = loginResp.data.toString();
    final tokenMatch = RegExp(
      r'name="__RequestVerificationToken"[^>]*?value="([^"]+)"',
    ).firstMatch(html);
    if (tokenMatch == null) {
      throw Exception('لم يتم العثور على توكن الأمان');
    }

    final resp = await _dio.post(
      '/ar/Login/Login',
      data: {
        'UserName': username,
        'UserPw': password,
        '__RequestVerificationToken': tokenMatch.group(1),
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        followRedirects: true,
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    if (resp.realUri.path.toLowerCase().contains('login')) {
      throw Exception('فشل تسجيل الدخول - تحقق من البيانات');
    }
  }

  // ========== جلب الإصدارات ==========
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

  // ========== تفعيل الجلسة ==========
  Future<void> activateSession(String flipId, String date) async {
    final readerUrl = '$baseUrl/flip/$flipId/$date/mobile';
    try {
      await _dio.get(
        '/flip/$flipId/$date/mobile',
        options: Options(
          followRedirects: true,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
    } catch (_) {}

    try {
      await _dio.post(
        '/ar/MyLibrary/SetSessionValue',
        options: Options(
          headers: {
            'X-Requested-With': 'XMLHttpRequest',
            'Referer': readerUrl,
          },
          validateStatus: (s) => s != null && s < 500,
        ),
      );
    } catch (_) {}

    await Future.delayed(const Duration(seconds: 1));
  }

  // ========== تحميل الصفحات ==========
  Future<List<Uint8List>> downloadPages(
    String flipId,
    String date, {
    void Function(int page, String message)? onLog,
  }) async {
    final pages = <Uint8List>[];

    for (var i = 1; i <= maxPages; i++) {
      try {
        onLog?.call(i, 'تحميل صفحة $i...');

        final resp = await _dio.get<List<int>>(
          '/flip/$flipId/files/mobile/$i.jpg',
          options: Options(
            responseType: ResponseType.bytes,
            headers: {
              'Referer': '$baseUrl/flip/$flipId/$date/mobile',
              'Accept':
                  'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
              'sec-fetch-site': 'same-origin',
              'sec-fetch-mode': 'no-cors',
              'sec-fetch-dest': 'image',
            },
            validateStatus: (s) => s != null && s < 500,
          ),
        );

        if (resp.statusCode != 200) {
          onLog?.call(i, 'توقف (${resp.statusCode})');
          break;
        }

        final bytes = Uint8List.fromList(resp.data!);
        if (bytes.length < minSize) {
          onLog?.call(
            i,
            'توقف (${(bytes.length / 1024).toStringAsFixed(0)}KB فقط)',
          );
          break;
        }

        pages.add(bytes);
        onLog?.call(
          i,
          '✓ صفحة $i (${(bytes.length / 1024).toStringAsFixed(0)}KB)',
        );
      } catch (e) {
        onLog?.call(i, 'خطأ: $e');
        break;
      }
    }

    return pages;
  }

  // ========== بناء PDF ==========
  Future<Uint8List> buildPdf(List<Uint8List> images) async {
    if (images.isEmpty) throw Exception('لا توجد صور');

    final doc = pw.Document(compress: true);

    for (var i = 0; i < images.length; i++) {
      final image = pw.MemoryImage(images[i]);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            image.width!.toDouble(),
            image.height!.toDouble(),
            marginAll: 0,
          ),
          build: (ctx) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

    return await doc.save();
  }
}
