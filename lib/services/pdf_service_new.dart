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

class PdfService {
  static Future<void> exportAndShareAudit(AuditModel audit) async {
    try {
      final pdf = pw.Document();

      // Load Turkish-supporting font
      pw.Font ttf;
      try {
        final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
        if (fontData.lengthInBytes > 1000) {
          ttf = pw.Font.ttf(fontData);
          debugPrint('PdfService: Noto Sans font loaded from assets');
        } else {
          throw Exception('Font file too small');
        }
      } catch (e) {
        debugPrint('PdfService: font load failed: $e');
        ttf = pw.Font.helvetica();
      }
      final brandBadge = pw.MemoryImage(
        (await rootBundle.load('assets/images/brand_badge.png')).buffer.asUint8List(),
      );

      // Preload images per answer
      final Map<String, List<pw.Widget>> answerImages = {};
      for (var ans in audit.answers) {
        final widgets = <pw.Widget>[];
        final photoPaths = ans.allPhotoUrls;
        if (photoPaths.isEmpty) {
          answerImages[ans.questionId] = widgets;
          continue;
        }
        for (var path in photoPaths) {
          try {
            if (path.startsWith('http')) {
              // Try to download image (may fail on web due to CORS)
              try {
                final imageUrl = StorageService.optimizedImageUrl(path);
                debugPrint('PdfService: downloading image $imageUrl');
                final resp = await http.get(Uri.parse(imageUrl));
                debugPrint('PdfService: image download status ${resp.statusCode}, bytes=${resp.bodyBytes.length}');
                if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
                  final imgBytes = Uint8List.fromList(resp.bodyBytes);
                  final image = pw.MemoryImage(imgBytes);
                  widgets.add(pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 12),
                      child: pw.Center(child: pw.Image(image,
                          width: PdfPageFormat.a4.availableWidth * 0.9))));
                } else {
                  widgets.add(pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6),
                      child: pw.Text('Resim indirilemedi: $path',
                          style: pw.TextStyle(font: ttf))));
                }
              } catch (e) {
                debugPrint('PdfService: image download failed: $e');
                widgets.add(pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 6),
                    child: pw.Text('Resim indirilemedi (CORS): $path',
                        style: pw.TextStyle(font: ttf))));
              }
            } else {
              // Local file
              try {
                final file = File(path);
                if (file.existsSync()) {
                  final bytes = file.readAsBytesSync();
                  if (bytes.isNotEmpty) {
                    final image = pw.MemoryImage(bytes);
                    widgets.add(pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 12),
                        child: pw.Center(child: pw.Image(image,
                            width: PdfPageFormat.a4.availableWidth * 0.9))));
                  }
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

      // Build PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: ttf, bold: ttf),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(brandBadge, width: 42, height: 42),
                  pw.Text((!kIsWeb && Platform.isIOS) ? 'DENETİM SİSTEMİ RAPORU' : 'METRO İSTANBUL DENETİM RAPORU',
                      style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          font: ttf)),
                  pw.Text(DateFormat('dd.MM.yyyy').format(audit.date),
                      style: pw.TextStyle(font: ttf)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              context: context,
              data: [
                ['Denetim ID', audit.id],
                ['Tarih', DateFormat('dd.MM.yyyy HH:mm').format(audit.date)],
                ['Hat', audit.line],
                ['İstasyon', audit.station],
                ['Denetçi', audit.auditorName],
                ['Denetim Türü', audit.auditType],
                ['Başarı Skoru', '%${audit.score.toStringAsFixed(1)}'],
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Text('DENETİM SORULARI VE CEVAPLAR',
                style: pw.TextStyle(
                    fontSize: 18,
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
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(q.questionText,
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, font: ttf)),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Puan: ${ans.score}',
                                style: pw.TextStyle(font: ttf)),
                            pw.Text(
                                ans.isNonconformity ? 'UYGUNSUZ' : 'UYGUN',
                                style: pw.TextStyle(
                                    color: ans.isNonconformity
                                        ? PdfColors.red
                                        : PdfColors.green,
                                    font: ttf)),
                          ],
                        ),
                        if (ans.comment != null)
                          pw.Text('Not: ${ans.comment}',
                              style: pw.TextStyle(font: ttf)),
                        if (answerImages.containsKey(ans.questionId))
                          ...answerImages[ans.questionId]!,
                      ],
                    ),
                  );
                }),
              ];
            }),
            pw.SizedBox(height: 20),
          ],
        ),
      );

      debugPrint('PdfService: PDF built, saving...');
      final bytes = await pdf.save();
      debugPrint('PdfService: PDF saved, ${bytes.length} bytes');

      if (kIsWeb) {
        debugPrint('PdfService: sharing PDF on web...');
        await Printing.sharePdf(
            bytes: bytes, filename: 'denetim_${audit.id}.pdf');
        debugPrint('PdfService: PDF shared successfully');
      } else {
        final output = await getTemporaryDirectory();
        final file = File("${output.path}/denetim_${audit.id}.pdf");
        await file.writeAsBytes(bytes);
        debugPrint('PdfService: PDF saved to ${file.path}');
        await Share.shareXFiles([XFile(file.path)],
            text: '${audit.id} numaralı Metro İstanbul Denetim Raporu');
      }
    } catch (e, stack) {
      debugPrint('PdfService: ERROR: $e\n$stack');
      rethrow;
    }
  }

  static Future<void> shareToWhatsApp(AuditModel audit) async {
    String reportTitle = (!kIsWeb && Platform.isIOS) ? '*DENETİM SİSTEMİ RAPORU*' : '*METRO İSTANBUL DENETİM RAPORU*';
    String text = "$reportTitle\n\n"
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
            // Gerçek uygulamada buradan dosya indirilir veya yerel yol kullanılır.
          } else {
            files.add(XFile(path));
          }
        }
      }
    }

    if (files.isNotEmpty) {
      await Share.shareXFiles(files, text: text);
    } else {
      await Share.share(text);
    }
  }
}
