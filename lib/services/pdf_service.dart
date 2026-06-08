import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/audit_model.dart';
import 'storage_service.dart';
import 'audit_question_resolver.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:convert';

class PdfService {
  static String toTurkishUpper(String input) {
    final upper = input.split('').map((char) {
      switch (char) {
        case 'i':
          return 'İ';
        case 'ı':
          return 'I';
        case 'ş':
          return 'Ş';
        case 'ğ':
          return 'Ğ';
        case 'ü':
          return 'Ü';
        case 'ö':
          return 'Ö';
        case 'ç':
          return 'Ç';
        default:
          return char.toUpperCase();
      }
    }).join();
    if (RegExp(r'[ÖÜĞŞÇ]').hasMatch(upper)) {
      return upper.replaceAll('I', 'İ');
    }
    return upper;
  }

  static Future<void> exportAndShareAudit(AuditModel audit) async {
    try {
      final pdf = pw.Document();

      // Load local Turkish-supporting font for INSTANT generation (no network requests)
      final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final ttf = pw.Font.ttf(fontData);
      final ttfBold = ttf; // Using regular for bold as well to save size/time
      final brandBadge = pw.MemoryImage(
        (await rootBundle.load('assets/images/brand_badge.png')).buffer.asUint8List(),
      );

      // Preload images per answer - small and uniform size
      final Map<String, List<pw.Widget>> answerImages = {};
      for (var ans in audit.answers) {
        final widgets = <pw.Widget>[];
        final photoPaths = ans.allPhotoUrls;
        if (photoPaths.isEmpty) {
          debugPrint('PdfService: no photos for answer ${ans.questionId}');
          answerImages[ans.questionId] = widgets;
          continue;
        }
        debugPrint('PdfService: processing ${photoPaths.length} photos for answer ${ans.questionId}');
        for (var path in photoPaths) {
          debugPrint('PdfService: photo path=$path');
          try {
            if (path.startsWith('http')) {
              try {
                final imageUrl = StorageService.optimizedImageUrl(path);
                debugPrint('PdfService: downloading image $imageUrl');
                final resp = await http.get(Uri.parse(imageUrl));
                debugPrint('PdfService: image download status ${resp.statusCode}, bytes=${resp.bodyBytes.length}');
                if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
                  final imgBytes = Uint8List.fromList(resp.bodyBytes);
                  final image = pw.MemoryImage(imgBytes);
                  widgets.add(pw.Container(
                    width: PdfPageFormat.a4.availableWidth * 0.3,
                    height: 64,
                    margin: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Image(image, fit: pw.BoxFit.contain),
                  ));
                } else {
                  widgets.add(pw.Text('Resim indirilemedi: $path',
                      style: pw.TextStyle(font: ttf)));
                }
              } catch (e) {
                debugPrint('PdfService: image download failed: $e');
                widgets.add(pw.Text('Resim indirilemedi (CORS): $path',
                    style: pw.TextStyle(font: ttf)));
              }
            } else if (path.startsWith('assets/')) {
              try {
                debugPrint('PdfService: loading asset image: $path');
                final data = await rootBundle.load(path);
                final imgBytes = data.buffer.asUint8List();
                debugPrint('PdfService: asset image bytes=${imgBytes.length}');
                if (imgBytes.isNotEmpty) {
                  final image = pw.MemoryImage(imgBytes);
                  widgets.add(pw.Container(
                    width: PdfPageFormat.a4.availableWidth * 0.3,
                    height: 64,
                    margin: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Image(image, fit: pw.BoxFit.contain),
                  ));
                }
              } catch (e) {
                debugPrint('PdfService: asset image failed: $e');
                widgets.add(pw.Text('Asset resim yüklenemedi: $path',
                    style: pw.TextStyle(font: ttf)));
              }
            } else {
              try {
                final file = File(path);
                debugPrint('PdfService: checking local file: $path, exists=${file.existsSync()}');
                if (file.existsSync()) {
                  final bytes = file.readAsBytesSync();
                  debugPrint('PdfService: local image bytes=${bytes.length}');
                  if (bytes.isNotEmpty) {
                    final image = pw.MemoryImage(bytes);
                    widgets.add(pw.Container(
                      width: PdfPageFormat.a4.availableWidth * 0.3,
                      height: 64,
                      margin: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Image(image, fit: pw.BoxFit.contain),
                    ));
                  }
                } else {
                  widgets.add(pw.Text('Dosya bulunamadı: $path',
                      style: pw.TextStyle(font: ttf)));
                }
              } catch (e) {
                debugPrint('PdfService: local image failed: $e');
              }
            }
          } catch (e) {
            debugPrint('PdfService: error processing image $path: $e');
          }
        }
        answerImages[ans.questionId] = widgets;
      }

      // Build PDF - multi page for full content
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('METRO İSTANBUL DENETİM RAPORU',
                      style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          font: ttf)),
                  pw.Text(DateFormat('dd.MM.yyyy').format(audit.date),
                      style: pw.TextStyle(font: ttf, fontSize: 10)),
                ],
              ),
            ),
            pw.SizedBox(height: 15),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey900,
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 56,
                        height: 56,
                        decoration: const pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Image(brandBadge, fit: pw.BoxFit.contain),
                      ),
                      pw.SizedBox(width: 16),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(toTurkishUpper(audit.station), style: pw.TextStyle(font: ttf, fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          pw.SizedBox(height: 6),
                          pw.Text('Denetim ID: ${audit.id.replaceAll('AUD', 'DNT')}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.blueGrey200)),
                          pw.Text('Tarih: ${DateFormat('dd.MM.yyyy HH:mm').format(audit.date)}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.blueGrey200)),
                          pw.Text('Denetçi: ${audit.auditorName}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.blueGrey200)),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: audit.score >= 85 ? PdfColors.green700 : (audit.score >= 70 ? PdfColors.orange700 : PdfColors.red700),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('BAŞARI SKORU', style: pw.TextStyle(font: ttf, fontSize: 8, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                            pw.Text('%${audit.score.toStringAsFixed(1)}', style: pw.TextStyle(font: ttf, fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          ]
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('Tür: ${audit.auditType}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.blueGrey200)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 15),
            // Category chart at the top (horizontal bar chart) - 100 points scale
            pw.Text('KATEGORİ BAŞARI ANALİZİ (100 Puan Üzerinden)',
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    font: ttf)),
            pw.SizedBox(height: 8),
            _buildCategoryChart(audit, ttf),
            pw.SizedBox(height: 20),
            pw.Text('DENETİM SORULARI VE CEVAPLAR',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    font: ttf)),
            pw.Divider(),
            ...AuditQuestionResolver.groupByCategory(audit).expand((section) {
              return [
                pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.only(top: 8, bottom: 8),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  color: PdfColors.blueGrey100,
                  child: pw.Text(section.categoryName.toUpperCase(),
                      style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                ),
                ...section.items.map((item) {
              final ans = item.answer;
              final q = item.question;
              final index = audit.answers.indexWhere((a) => a.questionId == ans.questionId);
              final questionNumber = index + 1;
              final isNc = ans.isNonconformity;
              final statusColor = isNc ? PdfColors.red800 : PdfColors.green800;
              final headerBgColor = isNc ? PdfColors.red800 : PdfColors.green800;
              const headerTextColor = PdfColors.white;
              
              return pw.Column(
                  children: [
                  pw.Container(
                    width: double.infinity,
                    margin: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        // Soru Yazısı - Yatay Renkli Kısım
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: pw.BoxDecoration(
                            color: headerBgColor,
                            border: pw.Border.all(color: PdfColors.black, width: 1.0),
                          ),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Soru #$questionNumber:', style: pw.TextStyle(font: ttf, fontSize: 10, color: headerTextColor, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(width: 6),
                              pw.Expanded(
                                child: pw.Text('${q.categoryName}: ${q.questionText}',
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: ttf, fontSize: 10, color: headerTextColor)),
                              ),
                            ],
                          ),
                        ),
                        // Cevap ve Değerlendirme - Standart Alt Kutu
                        pw.Container(
                          padding: const pw.EdgeInsets.all(10),
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.white,
                            border: pw.Border(
                              left: pw.BorderSide(color: PdfColors.black, width: 1.0),
                              right: pw.BorderSide(color: PdfColors.black, width: 1.0),
                              bottom: pw.BorderSide(color: PdfColors.black, width: 1.0),
                            ),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('Değerlendirme: ${isNc ? 'UYGUNSUZ' : 'UYGUN'}', style: pw.TextStyle(color: statusColor, font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                  pw.Text('Puan: ${ans.score}/5', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                                ],
                              ),
                              pw.SizedBox(height: 8),
                              pw.Container(
                                padding: const pw.EdgeInsets.all(8),
                                decoration: pw.BoxDecoration(color: PdfColors.grey50, border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
                                child: pw.Row(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('Not: ', style: pw.TextStyle(font: ttf, fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                                    pw.Expanded(child: pw.Text(
                                      [
                                        if (ans.comment != null && ans.comment!.trim().isNotEmpty) ans.comment!.trim(),
                                        if (ans.additionalComments.isNotEmpty) ...ans.additionalComments.map((c) => '• $c')
                                      ].join('\n').trim().isEmpty 
                                          ? 'Belirtilmedi'
                                          : [
                                              if (ans.comment != null && ans.comment!.trim().isNotEmpty) ans.comment!.trim(),
                                              if (ans.additionalComments.isNotEmpty) ...ans.additionalComments.map((c) => '• $c')
                                            ].join('\n'), 
                                      style: pw.TextStyle(
                                        font: ttf, 
                                        fontSize: 9, 
                                        color: [
                                          if (ans.comment != null && ans.comment!.trim().isNotEmpty) ans.comment!.trim(),
                                          if (ans.additionalComments.isNotEmpty) ...ans.additionalComments
                                        ].join('').trim().isEmpty 
                                            ? PdfColors.grey600 
                                            : PdfColors.black
                                      )
                                    )),
                                  ]
                                )
                              ),
                              if (answerImages.containsKey(ans.questionId) && answerImages[ans.questionId]!.isNotEmpty) ...[
                                pw.SizedBox(height: 8),
                                pw.Text('Fotoğraflar:', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                                pw.SizedBox(height: 6),
                                pw.Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: answerImages[ans.questionId]!,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
                }),
              ];
            }),
            pw.SizedBox(height: 15),
          ],
        ),
      );

      debugPrint('PdfService: PDF built, saving...');
      final bytes = await pdf.save();
      debugPrint('PdfService: PDF saved, ${bytes.length} bytes');

      final safeFileName = '${audit.line}_${audit.station}_${DateFormat('dd_MM_yyyy').format(audit.date)}_Denetim_Raporu.pdf'.replaceAll(' ', '_');

      if (kIsWeb) {
        debugPrint('PdfService: sharing PDF on web...');
        await Printing.sharePdf(bytes: bytes, filename: safeFileName);
        debugPrint('PdfService: PDF shared successfully');
      } else {
        final output = await getTemporaryDirectory();
        final file = File("${output.path}/$safeFileName");
        await file.writeAsBytes(bytes);
        debugPrint('PdfService: PDF saved to ${file.path}');
        await Share.shareXFiles([XFile(file.path)],
            text: '${audit.line} ${audit.station} Metro İstanbul Denetim Raporu');
      }
    } catch (e, stack) {
      debugPrint('PdfService: ERROR: $e\n$stack');
      rethrow;
    }
  }

  // Build a simple bar chart for category scores (out of 100)
  static pw.Widget _buildCategoryChart(AuditModel audit, pw.Font ttf) {
    debugPrint('PdfService: building category chart...');
    // Group answers by category
    final categoryScores = <String, List<int>>{};
    final categoryNames = <String, String>{};
    for (var item in AuditQuestionResolver.resolveAnswers(audit)) {
      final ans = item.answer;
      final q = item.question;
      final cat = q.categoryName;
      categoryNames[cat] = q.categoryName;
      categoryScores.putIfAbsent(cat, () => <int>[]).add(ans.score);
    }

    final widgets = <pw.Widget>[];
    // Calculate maximum bar width based on available page width
    final maxBarWidth = PdfPageFormat.a4.availableWidth * 0.6;
    categoryScores.forEach((cat, scores) {
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      final avgPercent = (avg / 5 * 100); // Convert to 100-point scale
      final barWidth = (avgPercent / 100 * maxBarWidth).clamp(10.0, maxBarWidth);
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 100,
                child: pw.Text(categoryNames[cat]!, 
                    style: pw.TextStyle(font: ttf, fontSize: 9)),
              ),
              pw.SizedBox(width: 8),
              pw.Container(
                height: 12,
                width: barWidth,
                decoration: pw.BoxDecoration(
                  color: avgPercent >= 80 ? PdfColors.green : (avgPercent >= 60 ? PdfColors.orange : PdfColors.red),
                  borderRadius: pw.BorderRadius.circular(2),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text('${avgPercent.toStringAsFixed(0)}/100', 
                  style: pw.TextStyle(font: ttf, fontSize: 9)),
            ],
          ),
        ),
      );
    });

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: widgets,
    );
  }

  static Future<void> shareToWhatsApp(AuditModel audit) async {
    String text = "*METRO İSTANBUL DENETİM RAPORU*\n\n"
        "*ID:* ${audit.id}\n"
        "*Hat/İstasyon:* ${audit.line} / ${audit.station}\n"
        "*Denetçi:* ${audit.auditorName}\n"
        "*Skor:* %${audit.score.toStringAsFixed(1)}\n"
        "*Tarih:* ${DateFormat('dd.MM.yyyy HH:mm').format(audit.date)}\n\n"
        "*Uygunsuzluklar:*\n";

    final ncs = audit.answers.where((a) => a.isNonconformity).toList();
    if (ncs.isEmpty) {
      text += "Uygunsuzluk tespit edilmedi.";
    } else {
      for (var nc in ncs) {
        final q = AuditQuestionResolver.resolveAnswer(audit, nc).question;
        text += "- ${q.questionText}: ${nc.comment ?? 'Not yok'}\n";
      }
    }

    // Fotoğrafları paylaş
    List<XFile> files = [];
    for (var ans in audit.answers) {
      if (ans.allPhotoUrls.isNotEmpty) {
        for (var path in ans.allPhotoUrls) {
          if (path.startsWith('http')) {
            // Mock URL'ler için gerçek dosyaya ihtiyacımız var ama bu ortamda indiremeyiz.
          } else {
            files.add(XFile(path));
          }
        }
      }
    }

    if (files.isNotEmpty && !kIsWeb) {
      try {
        await Share.shareXFiles(files, text: text);
        return;
      } catch (e) {
        debugPrint('PdfService: Share.shareXFiles failed: $e');
      }
    }
    
    // WhatsApp'ı doğrudan açmaya çalış
    final encodedText = Uri.encodeComponent(text);
    final url = Uri.parse("https://api.whatsapp.com/send?text=$encodedText");
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to normal share
        await Share.share(text);
      }
    } catch (e) {
      debugPrint('PdfService: WhatsApp launch failed: $e');
      await Share.share(text);
    }
  }

  static pw.Widget _buildInfoRow(String label, String value, pw.Font ttf, {bool isRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: isRight ? [
          pw.Text(value, style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(width: 4),
          pw.Text(label, style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700)),
        ] : [
          pw.Text(label, style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(width: 4),
          pw.Text(value, style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
